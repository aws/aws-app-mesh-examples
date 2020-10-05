import boto3
import datetime
cw = boto3.client('cloudwatch')


def lambda_handler(event, context):
    microservice_name = event.get('microservice_name')
    failure_threshold_value = event.get('failure_threshold_value')
    if not failure_threshold_value:
        failure_threshold_value = 0
    failure_threshold_time = event.get('failure_threshold_time')
    if not failure_threshold_time:
        failure_threshold_time = 600

    return get_healthcheck_status(microservice_name, failure_threshold_value, failure_threshold_time)


def get_healthcheck_status(microservice_name, failure_threshold_value, failure_threshold_time):
    now = datetime.datetime.now()
    ts_now = now.timestamp()
    ts_start = (now - datetime.timedelta(seconds=failure_threshold_time)).timestamp()

    response = cw.get_metric_data(
        MetricDataQueries=[
            {
                'Id': 'id1',
                'MetricStat': {
                    'Metric': {
                        'Namespace': 'EnvoyPrometheus/ResponseCode',
                        'MetricName': '5xx-%s' % microservice_name
                    },
                    'Period': 60,
                    'Stat': 'Sum'
                },
                'ReturnData': True
            },
        ],
        StartTime=ts_start,
        EndTime=ts_now,
        ScanBy='TimestampDescending'
    )

    values = response.get('MetricDataResults')[0].get('Values')
    if values and sum(values) > failure_threshold_value:
        print('Found [%s] 5XX HTTP response code' % sum(values))
        return False
    return True
