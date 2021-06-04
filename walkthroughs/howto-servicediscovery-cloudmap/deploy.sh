#!/usr/bin/env bash

set -e

if [ -z $AWS_ACCOUNT_ID ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z $AWS_DEFAULT_REGION ]; then
    echo "AWS_DEFAULT_REGION environment variable is not set."
    exit 1
fi

if [ -z $ENVOY_IMAGE ]; then
    echo "ENVOY_IMAGE environment variable is not set to App Mesh Envoy, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html"
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
APP_DIR="${DIR}/../../examples/apps/colorapp"
COLOR_TELLER_IMAGE=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/colorteller

deploy_vpc() {
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${RESOURCE_PREFIX}-vpc" \
        --template-file "${DIR}/vpc.yaml" \
        --capabilities CAPABILITY_IAM
}

deploy_mesh() {
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${RESOURCE_PREFIX}-mesh" \
        --template-file "${DIR}/mesh.yaml" \
        --capabilities CAPABILITY_IAM
}

deploy_app() {
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${RESOURCE_PREFIX}" \
        --template-file "${DIR}/app.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "EnvoyImage=${ENVOY_IMAGE}" "ColorTellerImage=${COLOR_TELLER_IMAGE}"
}

confirm_service_linked_role() {
    aws iam get-role --role-name AWSServiceRoleForAppMesh >/dev/null
    [[ $? -eq 0 ]] \
        || ( echo "Error: no service linked role for App Mesh" && exit 1 )
}

print_endpoint() {
    echo "Public endpoint:"
    prefix=$( aws cloudformation describe-stacks \
        --stack-name="${RESOURCE_PREFIX}" \
        --query="Stacks[0].Outputs[?OutputKey=='ColorGatewayEndpoint'].OutputValue" \
        --output=text )
    echo "${prefix}/color"
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
