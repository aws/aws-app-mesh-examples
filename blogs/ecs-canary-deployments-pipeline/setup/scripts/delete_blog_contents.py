""" Cleanup script for the ECS-BlogPost. """
#!/usr/bin/env python
import os
import time
import boto3
from botocore.exceptions import ClientError, WaiterError

#Find the EnvironmentName parameter
AWS_REGION = os.environ.get('AWS_REGION', 'us-west-2')
ENVIRONMENT_NAME = str(os.environ.get('EnvironmentName', 'ecs-blogpost'))

#Client connections
APPMESH_CLIENT = boto3.client('appmesh', region_name=AWS_REGION)
CFN_CLIENT = boto3.client('cloudformation', region_name=AWS_REGION)
ECR_CLIENT = boto3.client('ecr', region_name=AWS_REGION)
SSM_CLIENT = boto3.client('ssm', region_name=AWS_REGION)
S3_RESOURCE = boto3.resource('s3')
S3_CLIENT = boto3.client('s3')


def _list_stacks():
    """ List CFN Stacks by the desired prefix """

    stacks_tobe_deleted = []

    response = CFN_CLIENT.list_stacks(
        StackStatusFilter=['CREATE_COMPLETE', 'DELETE_FAILED']
    )
    for stack in response['StackSummaries']:
        if stack['StackName'].startswith(ENVIRONMENT_NAME):
            stacks_tobe_deleted.append(stack['StackName'])
    print("The list of stacks being deleted are: {}".format(stacks_tobe_deleted))
    return stacks_tobe_deleted

def _delete_cfn_stack(stack):
    """ Deletes CFN stack """

    retries = 3
    while True:
        try:
            CFN_CLIENT.delete_stack(
                StackName=stack
            )
            waiter = CFN_CLIENT.get_waiter('stack_delete_complete')
            waiter.wait(StackName=stack)
            print("Deleted the CloudFormation stack: {} successfully.".format(stack))
            return True
        except WaiterError as _ex:
            retries-=1
            if retries<1:
                print("CloudFormation Stack: {} deletion failed during the cleanup workflow.".format(stack))
                return False
            print("Sleeping for 60seconds during the cleanup workflow before second attempt of cleanup.")
            time.sleep(60)

def _delete_route(apps):
    """ Delete Routes in AppMesh Virtual Router """

    for app in apps:
        try:
            APPMESH_CLIENT.delete_route(
                meshName=ENVIRONMENT_NAME,
                routeName=app+'-route',
                virtualRouterName=app+'-vr'
            )
        except ClientError as ex:
            if ex.response['Error']['Code'] == 'NotFoundException':
                print("Could not find the route: {} on the VR: {}, no action needed".format(app+'-route', app+'-vr'))
                continue
            else:
                raise ex

def _delete_ecr_images(apps):
    """ Delete the ECR Images built by individual apps. """

    for app in apps:
        try:
            ECR_CLIENT.delete_repository(
                repositoryName=app,
                force=True
            )
            print("Deleted the ECR Repository: {} successfully.".format(app))
        except ClientError as ex:
            if ex.response['Error']['Code'] == 'RepositoryNotFoundException':
                print("Repository: {} is not found, no action needed".format(app))
                continue
            else:
                raise ex
    return True

def _delete_ssm_params(apps):
    """ Delete the app specific SSM Param store. """
    for app in apps:
        try:
            SSM_CLIENT.delete_parameter(
                Name=ENVIRONMENT_NAME+'-canary-'+app+'-version'
            )
        except ClientError as ex:
            if ex.response['Error']['Code'] == 'ParameterNotFound':
                print("SSM Parameter for the app: {} is not found, no action needed".format(app))
                continue
            else:
                raise ex
    print("Deleted the App Specific Parameter store successfully.")

def main():
    """ Main function. """
    apps = [
        'yelb-ui',
        'yelb-appserver',
        'yelb-redisserver',
        'yelb-db'
    ]

    #1. List the CFN Stacks and filter by the prefix 'ecs-blogpost'(which was the default EnvironmentName)
    stacks_tobe_deleted = _list_stacks()

    #2.1 Update the VR to set the routes to empty
    _delete_route(apps)

    #2.2 Delete the SSM Parameters created by Canary Stack.
    _delete_ssm_params(apps)

    #2.3 Iterate through the stacks_tobe_deleted, filter the canary stacks and delete them.
    for app in apps:
        for stack in stacks_tobe_deleted:
            pattern = '{}-{}-'.format(ENVIRONMENT_NAME, app)
            if stack.startswith(pattern):
                _delete_cfn_stack(stack)
                stacks_tobe_deleted.remove(stack)
            else:
                continue

    #3. Iterate through the stacks_tobe_deleted, filter the app specific pipeline stack.
    if _delete_ecr_images(apps):
        for app in apps:
            for stack in stacks_tobe_deleted:
                pattern = '{}-pipeline-{}'.format(ENVIRONMENT_NAME, app)
                if stack.startswith(pattern):
                    _delete_cfn_stack(stack)
                    stacks_tobe_deleted.remove(stack)

    #4. Find the S3 bucket which hosted Pipeline artifacts.
    for stack in stacks_tobe_deleted:
        pattern = '{}-deployment-stepfunctions'.format(ENVIRONMENT_NAME)
        if stack.startswith(pattern):
            response = CFN_CLIENT.describe_stacks(
                StackName=stack
            )['Stacks'][0]['Outputs']

            for output in response:
                pattern = '{}-deployment-'.format(ENVIRONMENT_NAME)
                if (output['OutputValue']).startswith(pattern):
                    if S3_RESOURCE.Bucket(output['OutputValue']) in S3_RESOURCE.buckets.all():
                        bucket = S3_RESOURCE.Bucket(output['OutputValue'])
                        bucket.objects.all().delete()
                    else:
                        break
            _delete_cfn_stack(stack)
            stacks_tobe_deleted.remove(stack)

    #4.1 Find the S3 bucket which we created externally to support artifacts attachment into Lambda functions.
    pattern = 'ecs-canary-blogpost-cloudformation-files-'
    buckets_list = S3_CLIENT.list_buckets()

    for bucket in buckets_list['Buckets']:
        if bucket["Name"].startswith(pattern):
            print(f'{bucket["Name"]} is about to be deleted')
            bucket = S3_RESOURCE.Bucket(bucket["Name"])
            bucket.objects.all().delete()
            bucket.delete()

    #5. Delete the Monitoring Stack.
    for stack in stacks_tobe_deleted:
        pattern = '{}-monitoring-resources'.format(ENVIRONMENT_NAME)
        if stack.startswith(pattern):
            _delete_cfn_stack(stack)
            stacks_tobe_deleted.remove(stack)

    #6. Delete the clusterresources Stack.
    for stack in stacks_tobe_deleted:
        pattern = '{}-clusterresources'.format(ENVIRONMENT_NAME)
        if stack.startswith(pattern):
            _delete_cfn_stack(stack)
            stacks_tobe_deleted.remove(stack)

    #7. Delete the VPC Stack.
    for stack in stacks_tobe_deleted:
        pattern = '{}-vpc'.format(ENVIRONMENT_NAME)
        if stack.startswith(pattern):
            _delete_cfn_stack(stack)
            stacks_tobe_deleted.remove(stack)
    print("Cleanup Done Successfully...Have a good day!")

if __name__=='__main__':
    main()
