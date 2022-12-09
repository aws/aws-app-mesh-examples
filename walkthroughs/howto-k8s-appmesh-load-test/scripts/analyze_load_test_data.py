import csv
import json
import os
import subprocess
from pathlib import Path
from pprint import pprint

import matplotlib.pyplot as plt
import numpy as np

from constants import S3_BUCKET

DIR_PATH = os.path.dirname(os.path.realpath(__file__))
DATA_PATH = os.path.join(DIR_PATH, 'data')


def get_s3_data():
    res = subprocess.run(["aws sts get-caller-identity"], shell=True, stdout=subprocess.PIPE,
                         universal_newlines=True)
    out = res.stdout
    print("Caller identity: {}".format(out))

    command = "aws s3 sync s3://{} {}".format(S3_BUCKET, DATA_PATH)
    print("Running the following command to download S3 load test results:  \n{}".format(command))
    res = subprocess.run([command], shell=True, stdout=subprocess.PIPE, universal_newlines=True)
    out = res.stdout
    print(out)


def plot_graph(actual_QPS_list, node_0_mem_list):
    node_0_mem_list = [float(x) for x in node_0_mem_list]
    Y = [x for _, x in sorted(zip(actual_QPS_list, node_0_mem_list))]
    X = sorted(actual_QPS_list)
    xpoints = np.array(X)
    ypoints = np.array(Y)

    plt.figure(figsize=(10, 5))
    plt.bar(xpoints, ypoints, width=20)
    plt.ylabel('Node-0 (MiB)')
    plt.xlabel('Actual QPS')
    print("Plotting graph...")
    plt.show()


def read_load_test_data():
    all_files_list = [x for x in os.listdir(DATA_PATH) if os.path.isdir(os.path.join(DATA_PATH, x))]
    qps_mem_files_list = []
    for exp_f in all_files_list:
        result = [os.path.join(dp, f) for dp, dn, filenames in os.walk(os.path.join(DATA_PATH, exp_f)) for f in
                  filenames
                  if "fortio.json" in f or "envoy_memory_MB_by_replica_set.csv" in f]
        qps_mem_files_list.append(result)

    actual_qps_list = []
    node_0_mem_list = []
    experiment_results = {}
    for qps_or_mem_f in qps_mem_files_list:
        attrb = {}
        for f in qps_or_mem_f:
            if "fortio.json" in f:
                with open(f) as json_f:
                    j = json.load(json_f)
                    actual_qps = j["ActualQPS"]
                    actual_qps_list.append(actual_qps)
                    attrb["ActualQPS"] = actual_qps
            else:
                with open(f) as csv_f:
                    c = csv.reader(csv_f, delimiter=',', skipinitialspace=True)
                    node_0_mem = []
                    for line in c:
                        if "node-0" in line[0]:
                            node_0_mem.append(line[2])
                    max_mem = max(node_0_mem)
                    node_0_mem_list.append(max_mem)
                    attrb["max_mem"] = max_mem
            key = Path(f)
            experiment_results[os.path.join(key.parts[-3], key.parts[-2])] = attrb

    # for research purpose
    print("Experiment results:")
    pprint(experiment_results)

    return actual_qps_list, node_0_mem_list


def plot_qps_vs_container_mem():
    actual_qps_list, node_0_mem_list = read_load_test_data()

    plot_graph(actual_qps_list, node_0_mem_list)


if __name__ == '__main__':
    get_s3_data()
    plot_qps_vs_container_mem()
