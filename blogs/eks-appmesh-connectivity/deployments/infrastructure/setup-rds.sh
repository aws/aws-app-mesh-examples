#!/bin/bash

export AWS_DEFAULT_OUTPUT="json"

VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true | jq -r '.Vpcs[0].VpcId')

aws ec2 create-security-group --group-name yelb-db-security-group --description "Security Group for Yelb-db" --vpc-id ${VPC_ID}

SECURITY_GROUP_ID=$(echo $(aws ec2 describe-security-groups \
        --filters Name=group-name,Values=yelb-db-security-group;Name=vpc-id,Values=${VPC_ID}) | jq -r '.SecurityGroups[0].GroupId')

echo "Security Group Id: ${SECURITY_GROUP_ID}"

aws ec2 authorize-security-group-ingress \
        --group-id ${SECURITY_GROUP_ID} \
        --protocol tcp \
        --port 5432 \
        --cidr 0.0.0.0/0

aws rds create-db-cluster \
        --db-cluster-identifier yelb-db-cluster \
        --engine aurora-postgresql \
        --master-username postgres \
        --master-user-password postgres_password \
        --vpc-security-group-ids ${SECURITY_GROUP_ID}

aws rds create-db-instance \
        --db-cluster-identifier yelb-db-cluster \
        --db-instance-identifier yelb-db-instance \
        --db-instance-class db.t3.micro \
        --engine aurora-postgresql

echo "Creating database..."
sleep 30s

CLUSTER_END_POINT=$(aws rds describe-db-clusters \
        --db-cluster-identifier yelb-db-cluster | jq -r '.DBClusters[0].Endpoint')

echo "RDS endpoint: ${CLUSTER_END_POINT}"
