#!/usr/bin/env bash

# Load environment variables
source ~/.bash_profile

kubectl delete ns yelb

images=(nginx node postgres redis redis-server yelb-appserver yelb-db yelb-ui)
echo "Cleaning up image, will delete images:\n"
printf '%s\n' "${images[@]}"
read -r -p "Are you sure you want to delete images? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
    then
        for image in "${images[@]}"; do
            aws ecr delete-repository --repository-name $image --region $AWS_REGION --force || true
        done
    else
        echo "OK, moving on!"
    fi


stacks=(eks-pipeline-yelb-ui eks-pipeline-yelb-appserver eks-pipeline-yelb-redis eks-pipeline-yelb-db)
echo "Cleaning up stacks"
for stack in "${stacks[@]}"; do
    aws cloudformation delete-stack --stack-name $stack --region $AWS_REGION|| true
done

echo "Waiting on stack delete"
seconds=45; date1=$((`date +%s` + $seconds)); 
while [ "$date1" -ge `date +%s` ]; do 
  echo -ne "$(date -u --date @$(($date1 - `date +%s` )) +%H:%M:%S)\r"; 
done

echo "Getting s3 buckets in stack eks-deployment-stepfunctions to remove."
bucket=$(aws cloudformation describe-stack-resources --stack-name eks-deployment-stepfunctions --region $AWS_REGION --output json | jq -c -r '.StackResources[] | select( .ResourceType == "AWS::S3::Bucket" ) | .PhysicalResourceId')
echo "Deleting bucket : $bucket"
aws s3 rb s3://$bucket --force || true
echo "Deleting stack eks-deployment-stepfunctions"
aws cloudformation delete-stack --stack-name eks-deployment-stepfunctions --region $AWS_REGION|| true
echo "Deleting stack kubectl-lambda-layer"
aws cloudformation delete-stack --stack-name kubectl-lambda-layer --region $AWS_REGION|| true

echo "Waiting on stack delete"
seconds=45; date1=$((`date +%s` + $seconds)); 
while [ "$date1" -ge `date +%s` ]; do 
  echo -ne "$(date -u --date @$(($date1 - `date +%s` )) +%H:%M:%S)\r"; 
done

eksctl delete iamserviceaccount --region $AWS_REGION --cluster $EKS_CLUSTER_NAME --namespace appmesh-system --name appmesh-controller

roles=$(aws iam list-roles --output json | jq -c -r '.Roles[] | select(.RoleName | contains("eksctl-blogpost"))| .RoleName')
for role in $roles; do
    inlinepolicies=$(aws iam list-role-policies --role-name $role --output json | jq -r -c .PolicyNames[])
    for policy in $inlinepolicies; do
        aws iam delete-role-policy --role-name $role --policy-name $policy
    done
    attachedpoliciesarn=$(aws iam list-attached-role-policies --role-name $role --output json | jq -r -c .AttachedPolicies[].PolicyArn)
        for policyarn in $attachedpoliciesarn; do
            aws iam detach-role-policy --role-name $role --policy-arn $policyarn
        done
    aws iam delete-role --role-name $role
done

echo "Removing parameters from parameter store."
parameters=(eks-canary-redis-server-version eks-canary-yelb-appserver-version eks-canary-yelb-db-version eks-canary-yelb-ui-version)
for parameter in "${parameters[@]}"; do
    aws ssm delete-parameter --name $parameter --region $AWS_REGION || true
done


echo "Deleting EKS cluster : blogpost"
eksctl delete cluster --region $AWS_REGION --name $EKS_CLUSTER_NAME

aws appmesh delete-mesh --mesh-name yelb --region $AWS_REGION

