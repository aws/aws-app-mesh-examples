import boto3
ssm = boto3.client('ssm')


def lambda_handler(event, context):
    try:
        parameter = ssm.get_parameter(Name='eks-canary-%s-version' % event.get('microservice_name'))
        return {"new_version": parameter['Parameter']['Version'] + 1, "current_percentage": 0}
    except ssm.exceptions.ParameterNotFound:
        return {"new_version": 1, "current_percentage": 0, "is_healthy": True}
