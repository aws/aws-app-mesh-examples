#!/bin/bash

set -ex

export AWS_DEFAULT_REGION=eu-west-2
export AWS_PROFILE={aws-profile}
export AWS_ACCOUNT_ID={aws-accountid}

export ENVIRONMENT_NAME=CIPMeshSample
export SERVICES_DOMAIN=cip.svc.cluster.local          
export MESH_NAME=cip-mesh

export ENVOY_IMAGE=840364872350.dkr.ecr.eu-west-2.amazonaws.com/aws-appmesh-envoy:v1.20.0.1-prod   
export COLOR_GATEWAY_IMAGE=${AWS_ACCOUNT_ID}.dkr.ecr.eu-west-2.amazonaws.com/gateway:latest
export COLOR_TELLER_IMAGE=${AWS_ACCOUNT_ID}.dkr.ecr.eu-west-2.amazonaws.com/colorteller:latest

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

apps/colorapp/ecs/ecs-colorapp.sh