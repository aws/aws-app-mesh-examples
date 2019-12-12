#!/usr/bin/env bash

set -e

if [ -z $PROJECT_NAME ]; then
    echo "PROJECT_NAME environment variable is not set."
    exit 1
fi

if [ -z $AWS_MASTER_ACCOUNT_ID ]; then
    echo "AWS_MASTER_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z $AWS_SECOND_ACCOUNT_ID ]; then
    echo "AWS_SECOND_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z $AWS_MASTER_PROFILE ]; then
    echo "AWS_MASTER_PROFILE environment variable is not set."
    exit 1
fi

if [ -z $AWS_SECOND_PROFILE ]; then
    echo "AWS_SECOND_PROFILE environment variable is not set."
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

if [ -z $BACKEND_1_IMAGE ]; then
    echo "BACKEND_1_IMAGE environment variable is not set."
    exit 1
fi

if [ -z $BACKEND_2_IMAGE ]; then
    echo "BACKEND_2_IMAGE environment variable is not set."
    exit 1
fi

if [ -z $KEY_PAIR ]; then
    echo "KEY_PAIR environment variable is not set. This must be the name of an SSH key pair, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html"
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
MASTER_ACCOUNT_DIR="${DIR}/master-account"
SECOND_ACCOUNT_DIR="${DIR}/second-account"

action=${1:-"deploy"}
if [ "$action" == "delete" ]; then
    ${SECOND_ACCOUNT_DIR}/deploy.sh delete
    ${MASTER_ACCOUNT_DIR}/deploy.sh delete
    exit 0
fi

source ${MASTER_ACCOUNT_DIR}/deploy.sh deploy
${SECOND_ACCOUNT_DIR}/deploy.sh deploy

echo "Bastion Address:"
echo "${BASTION_IP}"

+echo "DNS Endpoint:"
echo "${DNS_ENDPOINT}"
