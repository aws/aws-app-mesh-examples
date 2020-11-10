#!/usr/bin/env bash

# Load environment variables
source ~/.bash_profile

# Add the eks-charts repository to Helm
helm repo add eks https://aws.github.io/eks-charts

# Install the App Mesh Kubernetes custom resource definitions (CRD)
kubectl apply -k "https://github.com/aws/eks-charts/stable/appmesh-controller/crds?ref=master"

# Create a Kubernetes namespace for the controller
kubectl create ns appmesh-system

# Create an OpenID Connect (OIDC) identity provider for your cluster
eksctl utils associate-iam-oidc-provider --region=$AWS_REGION --cluster $EKS_CLUSTER_NAME --approve

# Create an IAM role and attach the AWSAppMeshFullAccess (https://console.aws.amazon.com/iam/home?#policies/arn:aws:iam::aws:policy/AWSAppMeshFullAccess$jsonEditor) and AWSCloudMapFullAccess (https://console.aws.amazon.com/iam/home?#policies/arn:aws:iam::aws:policy/AWSCloudMapFullAccess$jsonEditor) AWS managed policies
eksctl create iamserviceaccount --region $AWS_REGION --cluster $EKS_CLUSTER_NAME --namespace appmesh-system --name appmesh-controller --attach-policy-arn  arn:aws:iam::aws:policy/AWSCloudMapFullAccess,arn:aws:iam::aws:policy/AWSAppMeshFullAccess --override-existing-serviceaccounts --approve

# Deploy the App Mesh controller
helm upgrade -i appmesh-controller eks/appmesh-controller --namespace appmesh-system --set region=$AWS_REGION --set serviceAccount.create=false --set serviceAccount.name=appmesh-controller

# Confirm that the controller version is v1.0.0 or later
kubectl get deployment appmesh-controller -n appmesh-system -o json  | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'