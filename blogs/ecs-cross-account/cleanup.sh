#!/bin/bash
set -e

export AWS_PAGER=""

delete_cfn_stack() {
    profile=$1
    stack_name=$2
    echo "Deleting Cloud Formation stack: \"${stack_name}\" in profile \"${profile}\"..."
    aws --profile $profile cloudformation delete-stack --stack-name $stack_name
    echo 'Waiting for the stack to be deleted, this may take a few minutes...'
    aws --profile $profile cloudformation wait stack-delete-complete --stack-name $stack_name
    echo -e "Done\n"
}

PROJECT_NAME=am-ecs-multi-account

delete_cfn_stack "frontend" "${PROJECT_NAME}-frontend-and-appserver"
delete_cfn_stack "frontend" "${PROJECT_NAME}-appmesh-resources"
delete_cfn_stack "frontend" "${PROJECT_NAME}-infra"
delete_cfn_stack "backend" "${PROJECT_NAME}-resource-share"
delete_cfn_stack "backend" "${PROJECT_NAME}-redis-and-database"
delete_cfn_stack "backend" "${PROJECT_NAME}-appmesh-resources"
delete_cfn_stack "backend" "${PROJECT_NAME}-infra"

aws --profile backend appmesh delete-mesh --mesh-name yelb

echo -e "Cleanup complete."
