import io
import json
import logging
import os
import sys
import time
from datetime import datetime

import boto3
import pandas as pd
import requests
from botocore.exceptions import ClientError

from constants import *


def check_valid_request_data(request_data):
    logging.info("Validating Fortio request parameters")
    if "url" not in request_data:
        logging.warning("URL not provided. Defaulting to {}".format(URL_DEFAULT))
        request_data["url"] = URL_DEFAULT
    if "t" not in request_data:
        logging.warning("Duration (t) not provided. Defaulting to {}".format(DURATION_DEFAULT))
        request_data["t"] = DURATION_DEFAULT
    if "qps" not in request_data:
        logging.warning("qps not provided. Defaulting to {}".format(QPS_DEFAULT))
        request_data["qps"] = QPS_DEFAULT
    if "c" not in request_data:
        logging.warning("# Connections (c) not provided. Defaulting to {}".format(CONNECTIONS_DEFAULT))
        request_data["c"] = CONNECTIONS_DEFAULT

    logging.info("Updated request data -: {}".format(request_data))
    return request_data


def run_fortio_test(test_data):
    fortio_request_data = test_data.copy()
    test_name = fortio_request_data.pop("test_name")
    logging.info("Running test -: {}".format(test_name))
    fortio_request_data = check_valid_request_data(fortio_request_data)
    fortio_response = requests.post(url=FORTIO_RUN_ENDPOINT, json=fortio_request_data)

    if fortio_response.ok:
        fortio_json = fortio_response.json()
        logging.info("Successful Fortio run -: {}".format(test_name))
        return fortio_json
    else:
        logging.error("Fortio response code = {}".format(fortio_response.status_code))
        fortio_response.raise_for_status()


def query_prometheus_server(metric_name, metric_logic, start_ts, end_ts, step="10s"):
    logging.info("Querying prometheus server for metric = {} using logic = {}".format(metric_name, metric_logic))
    prometheus_response = requests.post(url=PROMETHEUS_QUERY_ENDPOINT,
                                        data={"query": metric_logic, "start": start_ts, "end": end_ts, "step": step})
    if prometheus_response.ok:
        logging.info("Successfully queried Prometheus for metric -: {}".format(metric_name))
    else:
        logging.error("Error while querying Prometheus for metric -: {}".format(metric_name))
        prometheus_response.raise_for_status()

    return prometheus_response.json()


def prometheus_json_to_df(prometheus_json, metric_name):
    data = pd.json_normalize(prometheus_json, record_path=['data', 'result'])
    try:
        # Split values into separate rows
        df = data.explode('values')
        # Split [ts, val] into separate columns
        split_df = pd.DataFrame(df['values'].to_list(), columns=['timestamp', metric_name], index=df.index)
        metrics_df = pd.concat([df, split_df], axis=1)
        metrics_df.drop(columns='values', inplace=True)
        metrics_df['timestamp'] = pd.to_numeric(metrics_df['timestamp'])

        # Normalize timestamps
        groupby_column = [col for col in metrics_df.columns if col.startswith("metric")][0]
        metrics_df['normalized_ts'] = metrics_df['timestamp'] - metrics_df.groupby(groupby_column).timestamp.transform(
            'min')
        logging.info("Normalized DataFrame -: {}".format(metrics_df.head(30)))
    except KeyError:
        logging.warning("Metrics response is empty. Returning empty DataFrame")
        metrics_df = pd.DataFrame(columns=["metric.<rollup_column>", "timestamp", metric_name, "normalized_ts"])

    return metrics_df


def write_to_s3(s3_client, data, folder_path, file_name):
    response = s3_client.put_object(Bucket=S3_BUCKET, Key="{}/{}".format(folder_path, file_name), Body=data)
    status = response.get("ResponseMetadata", {}).get("HTTPStatusCode")

    if status == 200:
        logging.info("Successful write of ({}/{}) to S3. Status - {}".format(folder_path, file_name, status))
    else:
        logging.error("Error writing ({}/{}) to S3. Response Metadata -: {}".format(folder_path, file_name,
                                                                                    response['ResponseMetadata']))
        raise IOError("S3 Write Failed. ResponseMetadata -: {}".format(response['ResponseMetadata']))


def get_s3_client(region=None, is_creds=False):
    try:
        if region is None:
            s3_client = boto3.client('s3')
        elif is_creds:
            cred = {
                "credentials": {
                    "accessKeyId": os.environ['AWS_ACCESS_KEY_ID'],
                    "secretAccessKey": os.environ['AWS_SECRET_ACCESS_KEY'],
                    "sessionToken": os.environ['AWS_SESSION_TOKEN'],
                }
            }
            s3_client = boto3.client('s3',
                                     aws_access_key_id=cred['credentials']['accessKeyId'],
                                     aws_secret_access_key=cred['credentials']['secretAccessKey'],
                                     aws_session_token=cred['credentials']['sessionToken'],
                                     region_name=region)
        else:
            s3_client = boto3.client('s3', region_name=region)
    except ClientError as e:
        logging.error(e)
        return
    return s3_client


def create_bucket_if_not_exists(s3_client, bucket_name, region=None):
    """Create an S3 bucket in a specified region

    If a region is not specified, the bucket is created in the S3 default
    region (us-west-2).

    :param bucket_name: Bucket to create
    :param region: String region to create bucket in, e.g., 'us-west-2'
    :return: True if bucket created, else False
    """
    try:
        s3 = boto3.resource('s3')
        s3.meta.client.head_bucket(Bucket=bucket_name)
        logging.info("No need to create as bucket: {} already exists,".format(bucket_name))
    except ClientError:
        # Create bucket
        try:
            if region is None:
                s3_client.create_bucket(Bucket=bucket_name)
            else:
                location = {'LocationConstraint': region}
                s3_client.create_bucket(Bucket=bucket_name, CreateBucketConfiguration=location)
        except ClientError as e:
            logging.error(e)
            return False
        return True


if __name__ == '__main__':
    config_file = sys.argv[1]
    BASE_PATH = sys.argv[2]
    LOGS_FOLDER = os.path.join(BASE_PATH, "logs")
    os.makedirs(LOGS_FOLDER, exist_ok=True)
    driver_ts = datetime.today().strftime('%Y%m%d%H%M%S')
    log_file = os.path.join(LOGS_FOLDER, "load_driver_{}.log".format(driver_ts))
    logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', level=logging.INFO)

    logging.info("driver_ts = {}".format(driver_ts))
    with open(config_file, "r") as f:
        config = json.load(f)
    logging.info("Loaded config file")

    region = os.environ['AWS_REGION']
    s3_client = get_s3_client()
    create_bucket_if_not_exists(s3_client=s3_client, bucket_name=S3_BUCKET, region=region)

    for test in config["load_tests"]:
        logging.info("Writing config to S3")
        write_to_s3(s3_client, json.dumps(config, indent=4), "{}/{}".format(test['test_name'], driver_ts),
                    "config.json")
        start_ts = int(time.time())
        fortio_json = run_fortio_test(test)
        # Write Fortio response to S3
        logging.info("Writing Fortio response to S3")
        write_to_s3(s3_client, json.dumps(fortio_json, indent=4), "{}/{}".format(test['test_name'], driver_ts),
                    "fortio.json")
        end_ts = int(time.time())

        logging.info("start_ts -: {}, end_ts -: {}".format(start_ts, end_ts))

        for metric_name, metric_logic in config['metrics'].items():
            metrics_json = query_prometheus_server(metric_name, metric_logic, start_ts, end_ts)
            metrics_df = prometheus_json_to_df(metrics_json, metric_name)
            # Write to S3
            logging.info("Writing Metrics dataframe to S3")
            s3_folder_path = "{}/{}".format(test['test_name'], driver_ts)
            file_name = "{}.csv".format(metric_name)
            csv_buffer = io.StringIO()
            metrics_df.to_csv(csv_buffer, index=False)
            write_to_s3(s3_client, csv_buffer.getvalue(), s3_folder_path, file_name)
            csv_buffer.close()

        logging.info("Finished exporting all metrics for {}. Sleeping for 10s before starting next test".format(
            test['test_name']))
        # Sleep 10s between tests
        time.sleep(10)
