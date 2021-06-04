""" Function to remove the resources from the previous canary version. """
import logging
import sys
import time
import boto3
from botocore.exceptions import WaiterError, ClientError

# Logging
LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)

#Client connections
CFN_CLIENT = boto3.client('cloudformation')
APPMESH_CLIENT = boto3.client('appmesh')

def _delete_stack(stack_name):
    """ Delete the old version of CloudFormation stack """

    retries = 3
    while True:
        try:
            CFN_CLIENT.delete_stack(
                StackName=stack_name
            )
            LOGGER.info("Waiting for stack to be deleted...")
            waiter = CFN_CLIENT.get_waiter('stack_delete_complete')
            waiter.wait(StackName=stack_name)
            LOGGER.info("Deleted the Canary stack: %s successfully.", stack_name)
            return True
        except WaiterError as _ex:
            retries-=1
            if retries<1:
                LOGGER.error("CloudFormation Stack deletion failed during the cleanup workflow.")
                return False
            LOGGER.info("Sleeping for 60seconds during the cleanup workflow before second attempt of cleanup.")
            time.sleep(60)

def _update_routes(event, healthy_deployment):
    """ Update routes in AppMesh VirtualRouter """

    try:
        entries = APPMESH_CLIENT.describe_route(
            meshName=event['EnvironmentName'],
            routeName=event['MicroserviceName']+'-'+'route',
            virtualRouterName=event['MicroserviceName']+'-'+'vr'
        )['route']['spec']['httpRoute']['action']['weightedTargets']

        if len(entries) > 1:
            if event['Protocol'].lower() == 'http':
                spec={
                    'httpRoute': {
                        'action': {
                            'weightedTargets': [
                                {
                                    'virtualNode':event['MicroserviceName']+'-'+healthy_deployment,
                                    'weight':100
                                }
                            ]
                        },
                        "match": {
                                    "prefix": "/"
                                },
                        'retryPolicy': {
                            'httpRetryEvents': [
                                'server-error',
                                'client-error',
                                'gateway-error'
                            ],
                            'maxRetries': 2,
                            'perRetryTimeout': {
                                'unit': 'ms',
                                'value': 2000
                            }
                        }
                    }
                }
            else:
                spec={
                    'tcpRoute': {
                        'action': {
                            'weightedTargets': [
                                {
                                    'virtualNode':event['MicroserviceName']+'-'+event['Sha'],
                                    'weight':100
                                }
                            ]
                        },
                        'timeout': {
                            'idle': {
                                'unit': 'ms',
                                'value': 2000
                            }
                        }
                    }
                }
            APPMESH_CLIENT.update_route(
                meshName=event['EnvironmentName'],
                routeName=event['MicroserviceName']+'-'+'route',
                spec=spec,
                virtualRouterName=event['MicroserviceName']+'-'+'vr'
            )
            return True
    except ClientError as ex:
        LOGGER.error("Update route failed with error: %s", ex)
        return False

def lambda_handler(event, _context):
    """ Main handler. """

    unhealthy_deployment = event['Sha']
    healthy_deployment = event['canary_results'].get('current_vn_sha')
    stack_name = event['EnvironmentName'] + '-' + event['MicroserviceName'] + '-' + unhealthy_deployment

    #If its a first time deployment, there is no `current_vn_sha` available.
    if healthy_deployment:
        if _update_routes(event, healthy_deployment):
            LOGGER.info("Mesh contents were successfully deleted which belongs to canary version.")
    _delete_stack(stack_name)
    LOGGER.info("CloudFormation stack is deleted which held the resources of previous canary rollout.")
