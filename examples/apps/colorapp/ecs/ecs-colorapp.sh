#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# ecs-colorapp.yaml expects "true" or "false" (default is "false")
# will deploy the TesterService, which perpetually invokes /color to generate history
: "${DEPLOY_TESTER:=false}"

# Creating Task Definitions
source ${DIR}/create-task-defs.sh

aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-ecs-colorapp" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/ecs-colorapp.yaml"  \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    ECSServicesDomain="${SERVICES_DOMAIN}" \
    AppMeshMeshName="${MESH_NAME}" \
    ColorGatewayTaskDefinition="${colorgateway_task_def_arn}" \
    ColorTellerWhiteTaskDefinition="${colorteller_white_task_def_arn}" \
    ColorTellerRedTaskDefinition="${colorteller_red_task_def_arn}" \
    ColorTellerBlueTaskDefinition="${colorteller_blue_task_def_arn}" \
    ColorTellerBlackTaskDefinition="${colorteller_black_task_def_arn}" \
    DeployTester="${DEPLOY_TESTER}"

