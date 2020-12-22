#!/bin/bash

# Create a ClusterConfig file
AWS_REGION=$(jq < cfn-output.json -r '.StackRegion');
PRIVSUB1_ID=$(jq < cfn-output.json -r '.PrivateSubnet1');
PRIVSUB2_ID=$(jq < cfn-output.json -r '.PrivateSubnet2');
PUBSUB1_ID=$(jq < cfn-output.json -r '.PublicSubnet1');
PUBSUB2_ID=$(jq < cfn-output.json -r '.PublicSubnet2');
PRIVSUB1_AZ=$(aws ec2 describe-subnets --subnet-ids $PRIVSUB1_ID | jq -r .Subnets[].AvailabilityZone);
PRIVSUB2_AZ=$(aws ec2 describe-subnets --subnet-ids $PRIVSUB2_ID | jq -r .Subnets[].AvailabilityZone);
PUBSUB1_AZ=$(aws ec2 describe-subnets --subnet-ids $PUBSUB1_ID | jq -r .Subnets[].AvailabilityZone);
PUBSUB2_AZ=$(aws ec2 describe-subnets --subnet-ids $PUBSUB2_ID | jq -r .Subnets[].AvailabilityZone);
NODES_IAM_POLICY=$(jq < cfn-output.json -r '.NodesSDPolicy');

cat > /tmp/eks-configuration.yml <<-EKS_CONF
  apiVersion: eksctl.io/v1alpha5
  kind: ClusterConfig  
  metadata:
    name: appmesh-getting-started-eks
    region: $AWS_REGION
  vpc:
    subnets:
      private:
        $PRIVSUB1_AZ: { id: $PRIVSUB1_ID }
        $PRIVSUB2_AZ: { id: $PRIVSUB2_ID }
      public:
        $PUBSUB1_AZ: { id: $PUBSUB1_ID }
        $PUBSUB2_AZ: { id: $PUBSUB2_ID }
  nodeGroups:
    - name: appmesh-cloudmap-ng
      labels: { role: workers }
      instanceType: t3.large
      desiredCapacity: 3
      ssh: 
        allow: false
      privateNetworking: true
      iam:
        attachPolicyARNs: 
          - $NODES_IAM_POLICY
          - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
          - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
          - arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
        withAddonPolicies:
          appMesh: true
          xRay: true
          cloudWatch: true
          externalDNS: true
EKS_CONF

# Create the EKS cluster
eksctl create cluster -f /tmp/eks-configuration.yml