#!/bin/bash

set -eo pipefail

if [ -z $AWS_ACCOUNT_ID ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z $AWS_REGION ]; then
    echo "AWS_REGION environment variable is not set."
    exit 1
fi

if [ -z $CLUSTER_NAME ]; then
    echo "CLUSTER_NAME environment variable is not set."
    exit 1
fi

if [ -z $ENVOY_IMAGE_REPO ]; then
    echo "ENVOY_IMAGE_REPO environment variable is not set."
    exit 1
fi

if [ -z $ENVOY_IMAGE_TAG ]; then
    echo "ENVOY_IMAGE_TAG environment variable is not set."
    exit 1
fi

echo "Creating EKS cluster $CLUSTER_NAME in region $AWS_REGION"

eksctl create cluster --name=$CLUSTER_NAME --nodes=2 \
--region=$AWS_REGION --auto-kubeconfig
