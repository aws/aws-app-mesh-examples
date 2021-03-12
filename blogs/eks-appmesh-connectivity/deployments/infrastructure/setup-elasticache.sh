#!/bin/bash

export AWS_DEFAULT_OUTPUT="json"

VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true | jq -r '.Vpcs[0].VpcId')

aws ec2 create-security-group --group-name yelb-es-security-group --description "Security Group for Yelb-Cache" --vpc-id ${VPC_ID}

SECURITY_GROUP_ID=$(echo $(aws ec2 describe-security-groups --filters Name=group-name,Values=yelb-es-security-group;Name=vpc-id,Values=${VPC_ID}) | jq -r '.SecurityGroups[0].GroupId')

echo "Security Group Id: ${SECURITY_GROUP_ID}"

aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_ID} \
    --protocol tcp \
    --port 6379 \
    --cidr 0.0.0.0/0

aws elasticache create-cache-cluster \
    --cache-cluster-id "yelb-cache-cluster" \
    --engine redis \
    --cache-node-type cache.t2.medium \
    --security-group-ids ${SECURITY_GROUP_ID} \
    --num-cache-nodes 1

echo "Creating cluster..."
sleep 30s

CLUSTER_END_POINT=$(aws elasticache describe-cache-clusters \
    --cache-cluster-id yelb-cache-cluster \
    --show-cache-node-info | jq -r '.CacheClusters[0].CacheNodes[0].Endpoint.Address')

echo "ElastiCache endpoint: ${CLUSTER_END_POINT}"
