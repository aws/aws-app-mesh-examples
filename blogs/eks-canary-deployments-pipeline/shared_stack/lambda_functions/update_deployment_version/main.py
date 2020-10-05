import boto3
ssm = boto3.client('ssm')


def lambda_handler(event, context):
    return ssm.put_parameter(Name='eks-canary-%s-version' % event.get('microservice_name'),
                             Value=event.get('container_image'),
                             Type="SecureString",
                             Overwrite=True)
