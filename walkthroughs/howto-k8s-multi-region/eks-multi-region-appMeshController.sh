#!/bin/bash

set -eo pipefail

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

echo "Enabling IAM OIDC Provider"
eksctl utils associate-iam-oidc-provider --region=$AWS_REGION \
    --cluster=$CLUSTER_NAME \
    --approve

echo "Creating namespace appmesh-system"
kubectl create ns appmesh-system

echo "Creating namespace howto-k8s-multi-region"
kubectl create ns howto-k8s-multi-region

echo "Creating AppMesh Controller IAM service account"
eksctl create iamserviceaccount --cluster $CLUSTER_NAME \
    --namespace appmesh-system \
    --name appmesh-controller \
    --attach-policy-arn arn:aws:iam::aws:policy/AWSCloudMapFullAccess,arn:aws:iam::aws:policy/AWSAppMeshFullAccess \
    --override-existing-serviceaccounts \
    --approve

echo "Creating Envoy IAM Service Account"
# The output is assigned to a variable just so that the script does not stop for a user input
PolicyARN=$(aws iam create-policy \
    --policy-name ${CLUSTER_NAME}-${AWS_REGION}-AWSAppMeshK8sEnvoyIAMPolicy \
    --policy-document file://envoy-iam-policy.json \
    --output json --query 'Policy.Arn')

eksctl create iamserviceaccount --cluster $CLUSTER_NAME \
    --namespace howto-k8s-multi-region \
    --name appmesh-controller \
    --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${CLUSTER_NAME}-${AWS_REGION}-AWSAppMeshK8sEnvoyIAMPolicy \
    --approve

echo "Adding eks helm repo"
helm repo add eks https://aws.github.io/eks-charts

helm repo update

echo "Install appmesh-controller helm chart"
helm upgrade -i appmesh-controller eks/appmesh-controller \
    --namespace appmesh-system \
    --set region=$AWS_REGION \
    --set serviceAccount.create=false \
    --set serviceAccount.name=appmesh-controller \
    --set sidecar.image.repository=$ENVOY_IMAGE_REPO \
    --set sidecar.image.tag=$ENVOY_IMAGE_TAG
