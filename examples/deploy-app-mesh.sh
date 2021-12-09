#!/usr/bin/env bash

export AWS_PROFILE={aws-profile}
export AWS_ACCOUNT_ID={aws-accountid}
# friendlyname-for-stack e.g. AppMeshSample
export ENVIRONMENT_NAME=CIPMeshSample

export AWS_DEFAULT_REGION=eu-west-2

# your-choice-of-mesh-name, e.g. default
export MESH_NAME=cip-mesh

# create AWS keypair for instances
ssh-keygen -t rsa -C "$MESH_NAME" -f $MESH_NAME
chmod 400 $MESH_NAME
chmod 400 $MESH_NAME.pub

# upload keypair to aws
aws ec2 import-key-pair --key-name "$MESH_NAME" --public-key-material fileb://./$MESH_NAME.pub

# get keypair details
aws ec2 describe-key-pairs --key-name cip-mesh 

# key-pair to access ec2 instances where apps are running
export KEY_PAIR_NAME=$MESH_NAME            

# the latest recommended envoy image
# see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html
export ENVOY_IMAGE=840364872350.dkr.ecr.eu-west-2.amazonaws.com/aws-appmesh-envoy:v1.20.0.1-prod    

# number of ec2 instances to spin up to join cluster, default is 5
export CLUSTER_SIZE=3               

# domain under which services will be discovered, e.g. "default.svc.cluster.local"
export SERVICES_DOMAIN=cip.svc.cluster.local          

# image location for colorapp's gateway, e.g. "<youraccountnumber>.dkr.ecr.amazonaws.com/gateway:latest" 
# - you need to build this image and use your own ECR repository, see below
export COLOR_GATEWAY_IMAGE=${AWS_ACCOUNT_ID}.dkr.ecr.amazonaws.com/gateway:latest
                                    
# image location for colorapp's teller, e.g. "<youraccountnumber>.dkr.ecr.amazonaws.com/colorteller:latest"
#- you need to build this image and use your own ECR repository, see below>
export COLOR_TELLER_IMAGE=${AWS_ACCOUNT_ID}.dkr.ecr.amazonaws.com/colorteller:latest

env | sort

#=================================================
# Build the docker images for example
#=================================================
#./build-docker-images.sh

#=================================================
# Following steps will setup a VPC, Mesh, and ECS.
#=================================================

# Setup VPC
#./infrastructure/vpc.sh

# Setup Mesh
#./infrastructure/appmesh-mesh.sh

# Setup ECS Cluster (Optional if using EKS)
#./infrastructure/ecs-cluster.sh

# Configure App Mesh resources
# apps/colorapp/servicemesh/appmesh-colorapp.sh

# deploy services to ECS
# apps/colorapp/ecs/ecs-colorapp.sh

#=================================================
# Test the application
#=================================================

# colorapp=$(aws cloudformation describe-stacks --stack-name=$ENVIRONMENT_NAME-ecs-colorapp --query="Stacks[0].Outputs[?OutputKey=='ColorAppEndpoint'].OutputValue" --output=text); echo $colorapp
# curl $colorapp/color

