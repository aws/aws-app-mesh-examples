""" Function to deploy the canary version. """
import base64
import logging
import boto3
from botocore.exceptions import ClientError

# Logging
LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)

#Client connections
CFN_CLIENT = boto3.client('cloudformation')
APPMESH_CLIENT = boto3.client('appmesh')

def _deserialize_template(canary_cfn_template):
    """ Decode the base64 encoded Canary CFN template. """

    template = base64.b64decode(canary_cfn_template).decode("utf-8")
    LOGGER.info("Decoded CloudFormation template.")
    return template

def _validate_template(template):
    """ Check if the CFN template is valid or not. """

    try:
        CFN_CLIENT.validate_template(TemplateBody=template)
        return True
    except ClientError as ex:
        LOGGER.error("CloudFormation template validation failed with error %s", ex)
        return False

def _generate_params(template_params):
    """ Generate CFN params. """

    template_params_list = []
    for key, value in template_params.items():
        template_params_list.append(
            {
                "ParameterKey": key,
                "ParameterValue": value
            }
        )
    return template_params_list

def lambda_handler(event, _context):
    """ Main handler. """

    canary_cfn_template = event['CanaryTemplate']

    template_params = {
        'EnvironmentName': event['EnvironmentName'],
        'MicroserviceName': event['MicroserviceName'],
        'Namespace': event['Namespace'],
        'Sha': event['Sha'],
        'ContainerImage': event['ContainerImage'],
        'Port': str(event['Port']),
        'Protocol': event['Protocol']
    }

    stack_name = event['EnvironmentName'] + '-' + event['MicroserviceName'] + '-' +event['Sha']

    template = _deserialize_template(canary_cfn_template)
    if not _validate_template(template):
        return None

    cfn_template_params = _generate_params(template_params)

    kwargs = {
        'StackName': stack_name,
        'TemplateBody': template,
        'Parameters': cfn_template_params,
    }

    CFN_CLIENT.create_stack(**kwargs)

    LOGGER.info("Waiting for stack to be ready.")
    waiter = CFN_CLIENT.get_waiter('stack_create_complete')
    waiter.wait(StackName=stack_name)
    LOGGER.info("Created Canary stack successfully.")
