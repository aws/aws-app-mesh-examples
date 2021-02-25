""" Function to check the deployment version from SSM. """
import logging
import boto3
from botocore.exceptions import ClientError

# Logging
LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)

SSM_CLIENT = boto3.client('ssm')

def lambda_handler(event, _context):
    """ Main handler. """

    try:
        parameter = SSM_CLIENT.get_parameter(
            Name='{}-canary-{}-version'.format(
                event.get('EnvironmentName'),
                event.get('MicroserviceName')
            )
        )
        return {
            "new_version": parameter['Parameter']['Version'] + 1, "current_percentage": 0
        }
    except ClientError as ex:
        if ex.response['Error']['Code'] == 'ParameterNotFound':
            LOGGER.exception('Unable to find the SSM Parameter as its a first time deployment')
            return {
                "new_version": 1, "current_percentage": 0, "is_healthy": True
            }
        else:
            raise ex
