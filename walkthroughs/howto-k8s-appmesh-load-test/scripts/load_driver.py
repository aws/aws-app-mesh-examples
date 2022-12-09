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
    if ("url" not in request_data):
        logging.warning(f"url not provided. Defaulting to {URL_DEFAULT}")
        request_data["url"] = URL_DEFAULT
    if ("t" not in request_data):
        logging.warning(f"Duration (t) not provided. Defaulting to {DURATION_DEFAULT}")
        request_data["t"] = DURATION_DEFAULT
    if ("qps" not in request_data):
        logging.warning(f"qps not provided. Defaulting to {QPS_DEFAULT}")
        request_data["qps"] = QPS_DEFAULT
    if ("c" not in request_data):
        logging.warning(f"# Connections (c) not provided. Defaulting to {CONNECTIONS_DEFAULT}")
        request_data["c"] = CONNECTIONS_DEFAULT

    logging.info(f"Updated request data -: {request_data}")
    return request_data


def run_fortio_test(test_data):
    fortio_request_data = test_data.copy()
    test_name = fortio_request_data.pop("test_name")
    logging.info(f"Running test -: {test_name}")
    fortio_request_data = check_valid_request_data(fortio_request_data)
    fortio_response = requests.post(url=FORTIO_RUN_ENDPOINT, json=fortio_request_data)

    if (fortio_response.ok):
        fortio_json = fortio_response.json()
        logging.info(f"Successful Fortio run -: {test_name}")
        return fortio_json
    else:
        logging.error(f"Fortio response code = {fortio_response.status_code}")
        fortio_response.raise_for_status()


def query_prometheus_server(metric_name, metric_logic, start_ts, end_ts, step="10s"):
    logging.info(f"Querying prometheus server for metric = {metric_name} using logic = {metric_logic}")
    prometheus_response = requests.post(url=PROMETHEUS_QUERY_ENDPOINT,
                                        data={"query": metric_logic, "start": start_ts, "end": end_ts, "step": step})
    if prometheus_response.ok:
        logging.info(f"Successfully queried Prometheus for metric -: {metric_name}")
    else:
        logging.error(f"Error while querying Prometheus for metric -: {metric_name}")
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
        logging.info("Normalized DataFrame -: ")
        logging.info(metrics_df.head(30))
    except KeyError:
        logging.warning("Metrics response is empty. Returning empty DataFrame")
        metrics_df = pd.DataFrame(columns=["metric.<rollup_column>", "timestamp", metric_name, "normalized_ts"])

    return metrics_df


def write_to_s3(s3_client, data, folder_path, file_name):
    response = s3_client.put_object(
        Bucket=S3_BUCKET, Key=f"{folder_path}/{file_name}", Body=data
    )
    status = response.get("ResponseMetadata", {}).get("HTTPStatusCode")

    if status == 200:
        logging.info(f"Successful write of ({folder_path}/{file_name}) to S3. Status - {status}")
    else:
        logging.error(
            f"Error writing ({folder_path}/{file_name}) to S3. Response Metadata -: {response['ResponseMetadata']}")
        raise IOError(f"S3 Write Failed. ResponseMetadata -: {response['ResponseMetadata']}")


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


def list_bucket(region=None):
    # Retrieve the list of existing buckets
    s3 = boto3.client('s3', region_name=region)
    response = s3.list_buckets()

    # Output the bucket names
    print('Existing buckets:')
    for bucket in response['Buckets']:
        print(f'  {bucket["Name"]}')


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
    driver_ts = datetime.today().strftime('%Y%m%d%H%M%S')
    print(f"driver_ts = {driver_ts}")

    config_file = sys.argv[1]
    BASE_PATH = sys.argv[2]
    LOGS_FOLDER = os.path.join(BASE_PATH, "logs")
    os.makedirs(LOGS_FOLDER, exist_ok=True)

    log_file = os.path.join(LOGS_FOLDER, f"load_driver_{driver_ts}.log")
    logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', level=logging.INFO)
    with open(config_file, "r") as f:
        config = json.load(f)
    logging.info("Loaded config file")

    region = os.environ['AWS_REGION']
    s3_client = get_s3_client()
    create_bucket_if_not_exists(s3_client=s3_client, bucket_name=S3_BUCKET, region=region)

    for test in config["load_tests"]:
        logging.info("Writing config to S3")
        write_to_s3(s3_client, json.dumps(config, indent=4), f"{test['test_name']}/{driver_ts}", "config.json")
        start_ts = int(time.time())
        fortio_json = run_fortio_test(test)
        # Write Fortio response to S3
        logging.info("Writing Fortio response to S3")
        write_to_s3(s3_client, json.dumps(fortio_json, indent=4), f"{test['test_name']}/{driver_ts}", "fortio.json")
        end_ts = int(time.time())

        logging.info(f"start_ts -: {start_ts}, end_ts -: {end_ts}")

        for metric_name, metric_logic in config['metrics'].items():
            metrics_json = query_prometheus_server(metric_name, metric_logic, start_ts, end_ts)
            metrics_df = prometheus_json_to_df(metrics_json, metric_name)
            # Write to S3
            logging.info("Writing Metrics dataframe to S3")
            s3_folder_path = f"{test['test_name']}/{driver_ts}"
            file_name = f"{metric_name}.csv"
            csv_buffer = io.StringIO()
            metrics_df.to_csv(csv_buffer, index=False)
            write_to_s3(s3_client, csv_buffer.getvalue(), s3_folder_path, file_name)
            csv_buffer.close()

        logging.info(
            f"Finished exporting all metrics for {test['test_name']}. Sleeping for 10s before starting next test")
        # Sleep 10s between tests
        time.sleep(10)
