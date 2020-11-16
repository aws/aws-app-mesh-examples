#!/bin/bash

set -e

echo "Creating a ClusterConfig file for the Frontend cluster..."

FRONTEND_AWS_REGION=$(aws --profile frontend configure get region);
FRONTEND_PRIVSUB1_ID=$(aws --profile frontend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PrivateSubnet1") | .Value');
FRONTEND_PRIVSUB2_ID=$(aws --profile frontend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PrivateSubnet2") | .Value');
FRONTEND_PUBSUB1_ID=$(aws --profile frontend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PublicSubnet1") | .Value');
FRONTEND_PUBSUB2_ID=$(aws --profile frontend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PublicSubnet2") | .Value');
FRONTEND_PRIVSUB1_AZ=$(aws --profile frontend ec2 describe-subnets --subnet-ids $FRONTEND_PRIVSUB1_ID | jq -r .Subnets[].AvailabilityZone);
FRONTEND_PRIVSUB2_AZ=$(aws --profile frontend ec2 describe-subnets --subnet-ids $FRONTEND_PRIVSUB2_ID | jq -r .Subnets[].AvailabilityZone);
FRONTEND_PUBSUB1_AZ=$(aws --profile frontend ec2 describe-subnets --subnet-ids $FRONTEND_PUBSUB1_ID | jq -r .Subnets[].AvailabilityZone);
FRONTEND_PUBSUB2_AZ=$(aws --profile frontend ec2 describe-subnets --subnet-ids $FRONTEND_PUBSUB2_ID | jq -r .Subnets[].AvailabilityZone);
FRONTEND_NODES_IAM_POLICY=$(aws --profile frontend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:NodesSDPolicy") | .Value');

cat > /tmp/eks-frontend-configuration.yml <<-EKS_FRONTEND_CONF
  apiVersion: eksctl.io/v1alpha5
  kind: ClusterConfig  
  metadata:
    name: am-multi-account-1
    region: $FRONTEND_AWS_REGION
    version: "1.18"
  vpc:
    subnets:
      private:
        $FRONTEND_PRIVSUB1_AZ: { id: $FRONTEND_PRIVSUB1_ID }
        $FRONTEND_PRIVSUB2_AZ: { id: $FRONTEND_PRIVSUB2_ID }
      public:
        $FRONTEND_PUBSUB1_AZ: { id: $FRONTEND_PUBSUB1_ID }
        $FRONTEND_PUBSUB2_AZ: { id: $FRONTEND_PUBSUB2_ID }
  nodeGroups:
    - name: am-multi-account-1-ng
      labels: { role: workers }
      instanceType: t3.large
      desiredCapacity: 3
      ssh: 
        allow: false
      privateNetworking: true
      iam:
        attachPolicyARNs: 
          - $FRONTEND_NODES_IAM_POLICY
          - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
          - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
          - arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
          - arn:aws:iam::aws:policy/AWSAppMeshFullAccess
        withAddonPolicies:
          xRay: true
          cloudWatch: true
          externalDNS: true
EKS_FRONTEND_CONF

echo "Creating the Frontend EKS cluster..."
eksctl create -p frontend cluster -f /tmp/eks-frontend-configuration.yml

echo "Creating a ClusterConfig file for the Backend cluster..."

BACKEND_AWS_REGION=$(aws --profile backend configure get region);
BACKEND_PRIVSUB1_ID=$(aws --profile backend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PrivateSubnet1") | .Value');
BACKEND_PRIVSUB2_ID=$(aws --profile backend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PrivateSubnet2") | .Value');
BACKEND_PUBSUB1_ID=$(aws --profile backend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PublicSubnet1") | .Value');
BACKEND_PUBSUB2_ID=$(aws --profile backend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PublicSubnet2") | .Value');
BACKEND_PRIVSUB1_AZ=$(aws --profile backend ec2 describe-subnets --subnet-ids $BACKEND_PRIVSUB1_ID | jq -r .Subnets[].AvailabilityZone);
BACKEND_PRIVSUB2_AZ=$(aws --profile backend ec2 describe-subnets --subnet-ids $BACKEND_PRIVSUB2_ID | jq -r .Subnets[].AvailabilityZone);
BACKEND_PUBSUB1_AZ=$(aws --profile backend ec2 describe-subnets --subnet-ids $BACKEND_PUBSUB1_ID | jq -r .Subnets[].AvailabilityZone);
BACKEND_PUBSUB2_AZ=$(aws --profile backend ec2 describe-subnets --subnet-ids $BACKEND_PUBSUB2_ID | jq -r .Subnets[].AvailabilityZone);
BACKEND_NODES_IAM_POLICY=$(aws --profile backend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:NodesSDPolicy") | .Value');
BACKEND_NODES_SECURITY_GROUP=$(aws --profile backend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:NodesSecurityGroup") | .Value');

cat > /tmp/eks-backend-configuration.yml <<-EKS_BACKEND_CONF
  apiVersion: eksctl.io/v1alpha5
  kind: ClusterConfig  
  metadata:
    name: am-multi-account-2
    region: $BACKEND_AWS_REGION
    version: "1.18"
  vpc:
    subnets:
      private:
        $BACKEND_PRIVSUB1_AZ: { id: $BACKEND_PRIVSUB1_ID }
        $BACKEND_PRIVSUB2_AZ: { id: $BACKEND_PRIVSUB2_ID }
      public:
        $BACKEND_PUBSUB1_AZ: { id: $BACKEND_PUBSUB1_ID }
        $BACKEND_PUBSUB2_AZ: { id: $BACKEND_PUBSUB2_ID }
  nodeGroups:
    - name: am-multi-account-2-ng
      labels: { role: workers }
      instanceType: t3.large
      desiredCapacity: 3
      ssh: 
        allow: false
      privateNetworking: true
      securityGroups:
        withShared: true
        withLocal: true
        attachIDs: ['$BACKEND_NODES_SECURITY_GROUP']
      iam:
        attachPolicyARNs: 
          - $BACKEND_NODES_IAM_POLICY
          - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
          - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
          - arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
          - arn:aws:iam::aws:policy/AWSAppMeshFullAccess
        withAddonPolicies:
          xRay: true
          cloudWatch: true
          externalDNS: true
EKS_BACKEND_CONF

echo "Creating the Backend EKS cluster..."
eksctl create -p backend cluster -f /tmp/eks-backend-configuration.yml