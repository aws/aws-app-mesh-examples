#!/usr/bin/env bash

set -e

check_command() {
  if ! [ -x "$(command -v "$1")" ]; then
    echo "$1 is required to run this script"
    exit
  fi
}

check_command aws
check_command docker

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z "$AWS_DEFAULT_REGION" ]; then
    echo "AWS_DEFAULT_REGION environment variable is not set."
    exit 1
fi

if [ -z "$ENVOY_IMAGE" ]; then
    echo "ENVOY_IMAGE environtment variable is not set, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html"
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
AWS_CLI_VERSION="$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)"

PROJECT_NAME="${PROJECT_NAME:-"howto-metrics-extension"}"
STACK_NAME="appmesh-$PROJECT_NAME"
ECR_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
ECR_IMAGE_PREFIX="$ECR_URL/$PROJECT_NAME"
CW_AGENT_IMAGE="$ECR_IMAGE_PREFIX/cwagent"
DJAPP_IMAGE="$ECR_IMAGE_PREFIX/djapp"
DASHBOARD_V1_IMAGE="$ECR_IMAGE_PREFIX/dashboard-v1"
GO_PROXY="${GO_PROXY:-"https://proxy.golang.org"}"

ecr_login() {
    if [ "$AWS_CLI_VERSION" -gt 1 ]; then
        aws ecr get-login-password --region "$AWS_DEFAULT_REGION" | \
            docker login --username AWS --password-stdin "$ECR_URL"
    else
        # Note: we want to execute the output
        $(aws ecr get-login --no-include-email)
    fi
}

create_repositories() {
    for f in cwagent djapp dashboard-v1; do
        aws ecr describe-repositories --repository-name "$PROJECT_NAME/$f" >/dev/null 2>&1 || \
            aws ecr create-repository --repository-name "$PROJECT_NAME/$f" >/dev/null
    done
}

deploy_images() {
    create_repositories
    ecr_login

    docker build -t "$CW_AGENT_IMAGE" "$DIR/src/cwagent" && \
        docker push "$CW_AGENT_IMAGE"
    docker build -t "$DASHBOARD_V1_IMAGE" "$DIR/src/dashboard-v1" && \
        docker push "$DASHBOARD_V1_IMAGE"
    docker build -t "$DJAPP_IMAGE" --build-arg GO_PROXY="$GO_PROXY" "$DIR/src/djapp" && \
        docker push "$DJAPP_IMAGE"
}

delete_repositories() {
    for f in cwagent djapp dashboard-v1; do
        aws ecr delete-repository --force --repository-name "$PROJECT_NAME/$f" >/dev/null
    done
}

deploy() {
    stage="$1"
    
    echo "Deploying stack $STACK_NAME, this may take a few minutes..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "$STACK_NAME" \
        --template-file "$DIR/deploy/$stage.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides \
        "ProjectName=$PROJECT_NAME" \
        "EnvoyImage=$ENVOY_IMAGE" \
        "CloudWatchAgentImage=$CW_AGENT_IMAGE" \
        "DJAppImage=$DJAPP_IMAGE"
}

delete_cfn_stack() {
    stack_name="$1"
    aws cloudformation delete-stack --stack-name "$stack_name"
    echo "Waiting for the stack $stack_name to be deleted, this may take a few minutes..."
    aws cloudformation wait stack-delete-complete --stack-name "$stack_name"
    echo "Done"
}

confirm_service_linked_role() {
    if ! (aws iam get-role --role-name AWSServiceRoleForAppMesh >/dev/null); then
        echo "Error: no service linked role for App Mesh exists"
        echo "see https://docs.aws.amazon.com/app-mesh/latest/userguide/using-service-linked-roles.html"
        exit 1
    fi
}

print_endpoint() {
    echo "Public endpoint is now available. Export it for later use:"
    prefix="$(aws cloudformation describe-stacks \
        --stack-name="$STACK_NAME" \
        --query="Stacks[0].Outputs[?OutputKey=='PublicEndpoint'].OutputValue" \
        --output=text)"
    echo "export PUBLIC_ENDPOINT=\"${prefix}\""
}

deploy_stacks() {
    if [ -z "$SKIP_IMAGES" ]; then
        echo "deploy images..."
        deploy_images
    fi

    echo "deploy app using stage $stage"
    deploy "$stage"

    if [ "$stage" == "djapp-v1" ]; then
    	confirm_service_linked_role
    fi
    print_endpoint
}

action="${1:-"deploy"}"
stage="${2:-"djapp-v1"}"

if [ "$action" == "delete" ]; then
    delete_cfn_stack "$STACK_NAME"
    delete_repositories
    exit 0
fi

deploy_stacks
