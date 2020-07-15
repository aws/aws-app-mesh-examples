#!/bin/bash

echo "Deleting the App Mesh virtual services"
kubectl delete virtualservice redis-server -n yelb
kubectl delete virtualservice yelb-db -n yelb
kubectl delete virtualservice yelb-ui -n yelb
kubectl delete virtualservice yelb-appserver -n yelb

echo "Deleting the App Mesh virtual router"
kubectl delete virtualrouter yelb-appserver -n yelb

echo "Deleting the App Mesh virtual nodes"
kubectl delete virtualnode redis-server -n yelb
kubectl delete virtualnode yelb-appserver -n yelb
kubectl delete virtualnode yelb-appserver-v2 -n yelb
kubectl delete virtualnode yelb-db -n yelb
kubectl delete virtualnode yelb-ui -n yelb

echo "Deleting the App Mesh mesh"
kubectl delete mesh yelb

echo "Deleting the Yelb deployment"
kubectl delete -f infrastructure/yelb_initial_deployment.yaml

echo "Deleting EKS cluster"
eksctl delete cluster -f /tmp/eks-configuration.yml

echo "Cleaning up ECR repository"
APPSERVER_ECR_REPO=$(jq < cfn-output.json -r '.AppServerEcrRepo' | cut -d '/' -f 2 );
aws ecr list-images \
  --repository-name $APPSERVER_ECR_REPO | \
jq -r ' .imageIds[] | [ .imageDigest ] | @tsv ' | \
  while IFS=$'\t' read -r imageDigest; do 
    aws ecr batch-delete-image \
      --repository-name $APPSERVER_ECR_REPO \
      --image-ids imageDigest=$imageDigest
  done

echo "Deleting the baseline CloudFormation template"
STACK_NAME=$(jq < cfn-output.json -r '.StackName');
aws cloudformation delete-stack \
  --stack-name $STACK_NAME
aws cloudformation wait stack-delete-complete \
  --stack-name $STACK_NAME

echo "Cleanup finished"