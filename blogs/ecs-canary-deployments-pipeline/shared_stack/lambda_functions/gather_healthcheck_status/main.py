""" Gather HealthCheck status. """
import datetime
import logging
import boto3

# Logging
LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)

#Client Connection
CLOUDWATCH_CLIENT = boto3.client('cloudwatch')

def lambda_handler(event, _context):
    """ Main Handler. """

    microservice_name = event.get('MicroserviceName')
    environment_name = event.get('EnvironmentName')
    new_vn_sha = event.get('Sha')
    failure_threshold_value = event.get('FailureThresholdValue')
    if not failure_threshold_value:
        failure_threshold_value = 0
    failure_threshold_time = event.get('FailureThresholdTime')
    if not failure_threshold_time:
        failure_threshold_time = 600
    return get_healthcheck_status(
        microservice_name,
        environment_name,
        new_vn_sha,
        failure_threshold_value,
        failure_threshold_time
    )

def get_healthcheck_status(microservice_name, environment_name, new_vn_sha, failure_threshold_value, failure_threshold_time):
    """ Gather HealthCheck """

    now = datetime.datetime.now()
    ts_now = now.timestamp()
    ts_start = (now - datetime.timedelta(seconds=failure_threshold_time)).timestamp()

    response = CLOUDWATCH_CLIENT.get_metric_data(
        MetricDataQueries=[
            {
                'Id': 'id1',
                'MetricStat': {
                    'Metric': {
                        'Namespace': 'ECS/ContainerInsights/Prometheus',
                        'MetricName': 'envoy_http_downstream_rq_xx',
                        'Dimensions': [
                          {
                            'Name': 'TaskDefinitionFamily',
                            'Value': '%s' % microservice_name
                          },
                          {
                            'Name': 'envoy_http_conn_manager_prefix',
                            'Value': 'ingress'
                          },
                          {
                            'Name': 'envoy_response_code_class',
                            'Value': '5'
                          },
                          {
                            'Name': 'ClusterName',
                            'Value': '%s' % environment_name
                          },
                          {
                            'Name': 'appmesh_virtual_node',
                            'Value': '%s-%s' % (microservice_name, new_vn_sha)
                          }
                        ]
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
    LOGGER.info("GetMetricData yielded: %s", response)
    values = response.get('MetricDataResults')[0].get('Values')
    if values and sum(values) > failure_threshold_value:
        LOGGER.info('Found [%s] 5XX HTTP response code', sum(values))
        return False
    LOGGER.info('Did not find [%s] 5XX HTTP response code', sum(values))
    return True
