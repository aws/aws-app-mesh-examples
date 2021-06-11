#!/bin/bash

set -e

echo "Creating the Frontend Account VPC..."

aws --profile frontend cloudformation deploy \
--template-file infrastructure/infrastructure_frontend.yaml \
--parameter-overrides \
"BackendAccountId=$(aws --profile backend sts get-caller-identity | jq -r .Account)" \
--stack-name am-multi-account-infra \
--capabilities CAPABILITY_IAM

echo "Creating the Backend Account VPC..."

aws --profile backend cloudformation deploy \
--template-file infrastructure/infrastructure_backend.yaml \
--parameter-overrides \
"FrontendAccountId=$(aws --profile frontend sts get-caller-identity | jq -r .Account)" \
"PeerVPCId=$(aws --profile frontend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:VPC") | .Value')" \
"PeerRoleArn=$(aws --profile frontend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:VPCPeerRole") | .Value')" \
--stack-name am-multi-account-infra \
--capabilities CAPABILITY_IAM

echo "Creating the VPC peering routes..."

aws --profile frontend cloudformation deploy \
--template-file infrastructure/frontend_vpc_peering_routes.yaml \
--parameter-overrides \
"VPCPeeringConnectionId=$(aws --profile backend cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:VPCPeeringConnectionId") | .Value')" \
--stack-name am-multi-account-routes \
--capabilities CAPABILITY_IAM

aws --profile backend cloudformation deploy \
--template-file infrastructure/backend_vpc_peering_routes.yaml \
--stack-name am-multi-account-routes \
--capabilities CAPABILITY_IAM

