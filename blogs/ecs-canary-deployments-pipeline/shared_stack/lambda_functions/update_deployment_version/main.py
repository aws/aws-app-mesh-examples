""" Update the Version in SSM. """
import boto3

#Client connections
SSM_CLIENT = boto3.client('ssm')

def lambda_handler(event, _context):
    """ Update the Version in SSM. """
    return SSM_CLIENT.put_parameter(
        Name='{}-canary-{}-version'.format(
            event.get('EnvironmentName'),
            event.get('MicroserviceName')
        ),
        Value=event.get('ContainerImage'),
        Type="SecureString",
        Overwrite=True
    )
