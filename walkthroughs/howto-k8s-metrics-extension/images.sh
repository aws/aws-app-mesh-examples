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

if [ -z "$NAMESPACE_NAME" ]; then
    echo "NAMESPACE_NAME environment variable is not set."
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
AWS_CLI_VERSION="$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)"
ECR_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
ECR_IMAGE_PREFIX="$ECR_URL/$NAMESPACE_NAME"
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
    for f in djapp dashboard-v1; do
        aws ecr describe-repositories --repository-name "$NAMESPACE_NAME/$f" >/dev/null 2>&1 || \
            aws ecr create-repository --repository-name "$NAMESPACE_NAME/$f" >/dev/null
    done
}


deploy_images() {
    create_repositories
    ecr_login

    docker build -t "$DASHBOARD_V1_IMAGE" "$DIR/../howto-metrics-extension-ecs/src/dashboard-v1" && \
        docker push "$DASHBOARD_V1_IMAGE"
    docker build -t "$DJAPP_IMAGE" --build-arg GO_PROXY="$GO_PROXY" "$DIR/../howto-metrics-extension-ecs/src/djapp" && \
        docker push "$DJAPP_IMAGE"
}


delete_repositories() {
    for f in djapp dashboard-v1; do
        aws ecr delete-repository --force --repository-name "$NAMESPACE_NAME/$f" >/dev/null
    done
}

usage() {
    echo "usage: $(basename "$0") [upload | delete]"
    exit 1
}

action="$1"

case "$action" in
    upload)
      echo "Building and uploading images..."
      deploy_images
      echo "Done"
      ;;
    delete)
      echo "Deleting images..."
      delete_repositories
      echo "Done"
      ;;
    *)
      usage
      ;;
esac
