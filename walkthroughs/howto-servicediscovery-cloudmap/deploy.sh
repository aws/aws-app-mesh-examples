#!/usr/bin/env bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

deploy_vpc() {
    aws --region "${AWS_DEFAULT_REGION}" \
        cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${RESOURCE_PREFIX}-vpc" \
        --template-file "${DIR}/vpc.yaml" \
        --capabilities CAPABILITY_IAM
}

deploy_mesh() {
    aws --region "${AWS_DEFAULT_REGION}" \
        cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${RESOURCE_PREFIX}-mesh" \
        --template-file "${DIR}/mesh.yaml" \
        --capabilities CAPABILITY_IAM
}

deploy_app() {
    aws --region "${AWS_DEFAULT_REGION}" \
        cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${RESOURCE_PREFIX}" \
        --template-file "${DIR}/app.yaml" \
        --capabilities CAPABILITY_IAM
}

confirm_service_linked_role() {
    aws iam get-role --role-name AWSServiceRoleForAppMesh >/dev/null
    [[ $? -eq 0 ]] \
        || ( echo "Error: no service linked role for App Mesh" && exit 1 )
}

print_endpoint() {
    echo "Public endpoint:"
    aws cloudformation describe-stacks \
      --stack-name="${RESOURCE_PREFIX}" \
      --query="Stacks[0].Outputs[?OutputKey=='ColorGatewayEndpoint'].OutputValue" \
      --output=text
}

main() {
    echo "deploy vpc..."
    deploy_vpc

    echo "deploy mesh..."
    deploy_mesh

    echo "deploy app..."
    deploy_app

    confirm_service_linked_role
    print_endpoint
}

main $@
