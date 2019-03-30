#!/bin/bash

# set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

stack_output=$(aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    cloudformation describe-stacks --stack-name "${ENVIRONMENT_NAME}-ecs-cluster" \
    | jq '.Stacks[].Outputs[]')

task_role_arn=($(echo $stack_output \
    | jq -r 'select(.OutputKey == "TaskIamRoleArn") | .OutputValue'))

execution_role_arn=($(echo $stack_output \
    | jq -r 'select(.OutputKey == "TaskExecutionIamRoleArn") | .OutputValue'))

ecs_service_log_group=($(echo $stack_output \
    | jq -r 'select(.OutputKey == "ECSServiceLogGroup") | .OutputValue'))

envoy_log_level="debug"

# Color Gateway Task Definition
envoy_container_json=$(jq -n \
    --arg ENVOY_IMAGE $ENVOY_IMAGE \
    --arg VIRTUAL_NODE "mesh/$MESH_NAME/virtualNode/colorgateway-vn" \
    --arg APPMESH_XDS_ENDPOINT "${APPMESH_XDS_ENDPOINT}" \
    --arg ENVOY_LOG_LEVEL $envoy_log_level \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg AWS_LOG_STREAM_PREFIX_ENVOY "colorgateway-envoy" \
    -f "${DIR}/envoy-container.json")
xray_container_json=$(jq -n \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg AWS_LOG_STREAM_PREFIX_ENVOY "colorgateway-xray" \
    -f "${DIR}/xray-container.json")
task_def_json=$(jq -n \
    --arg NAME "$ENVIRONMENT_NAME-ColorGateway" \
    --arg STAGE "$APPMESH_STAGE" \
    --arg COLOR_TELLER_ENDPOINT "colorteller.$SERVICES_DOMAIN:9080" \
    --arg TCP_ECHO_ENDPOINT "tcpecho.$SERVICES_DOMAIN:2701" \
    --arg APP_IMAGE $COLOR_GATEWAY_IMAGE \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_LOG_STREAM_PREFIX_APP "colorgateway-app" \
    --arg TASK_ROLE_ARN $task_role_arn \
    --arg EXECUTION_ROLE_ARN $execution_role_arn \
    --argjson ENVOY_CONTAINER_JSON "${envoy_container_json}" \
    --argjson XRAY_CONTAINER_JSON "${xray_container_json}" \
    -f "${DIR}/colorgateway-base-task-def.json")
task_def=$(aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    ecs register-task-definition \
    --cli-input-json "$task_def_json")
colorgateway_task_def_arn=($(echo $task_def \
    | jq -r '.taskDefinition | .taskDefinitionArn'))

# Color Teller White Task Definition
envoy_container_json=$(jq -n \
    --arg ENVOY_IMAGE $ENVOY_IMAGE \
    --arg VIRTUAL_NODE "mesh/$MESH_NAME/virtualNode/colorteller-white-vn" \
    --arg APPMESH_XDS_ENDPOINT "${APPMESH_XDS_ENDPOINT}" \
    --arg ENVOY_LOG_LEVEL $envoy_log_level \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg AWS_LOG_STREAM_PREFIX_ENVOY "colorteller-white-envoy" \
    -f "${DIR}/envoy-container.json")
xray_container_json=$(jq -n \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg AWS_LOG_STREAM_PREFIX_ENVOY "colorteller-white-xray" \
    -f "${DIR}/xray-container.json")
task_def_json=$(jq -n \
    --arg NAME "$ENVIRONMENT_NAME-ColorTellerWhite" \
    --arg STAGE "$APPMESH_STAGE" \
    --arg COLOR "white" \
    --arg APP_IMAGE $COLOR_TELLER_IMAGE \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_LOG_STREAM_PREFIX_APP "colorteller-white-app" \
    --arg TASK_ROLE_ARN $task_role_arn \
    --arg EXECUTION_ROLE_ARN $execution_role_arn \
    --argjson ENVOY_CONTAINER_JSON "${envoy_container_json}" \
    --argjson XRAY_CONTAINER_JSON "${xray_container_json}" \
    -f "${DIR}/colorteller-base-task-def.json")
task_def=$(aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    ecs register-task-definition \
    --cli-input-json "$task_def_json")
colorteller_white_task_def_arn=($(echo $task_def \
    | jq -r '.taskDefinition | .taskDefinitionArn'))

# Color Teller Red Task Definition
envoy_container_json=$(jq -n \
    --arg ENVOY_IMAGE $ENVOY_IMAGE \
    --arg VIRTUAL_NODE "mesh/$MESH_NAME/virtualNode/colorteller-red-vn" \
    --arg APPMESH_XDS_ENDPOINT "${APPMESH_XDS_ENDPOINT}" \
    --arg ENVOY_LOG_LEVEL $envoy_log_level \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg AWS_LOG_STREAM_PREFIX_ENVOY "colorteller-red-envoy" \
    -f "${DIR}/envoy-container.json")
xray_container_json=$(jq -n \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg AWS_LOG_STREAM_PREFIX_ENVOY "colorteller-red-xray" \
    -f "${DIR}/xray-container.json")
task_def_json=$(jq -n \
    --arg NAME "$ENVIRONMENT_NAME-ColorTellerRed" \
    --arg STAGE "$APPMESH_STAGE" \
    --arg COLOR "red" \
    --arg APP_IMAGE $COLOR_TELLER_IMAGE \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_LOG_STREAM_PREFIX_APP "colorteller-red-app" \
    --arg TASK_ROLE_ARN $task_role_arn \
    --arg EXECUTION_ROLE_ARN $execution_role_arn \
    --argjson ENVOY_CONTAINER_JSON "${envoy_container_json}" \
    --argjson XRAY_CONTAINER_JSON "${xray_container_json}" \
    -f "${DIR}/colorteller-base-task-def.json")
task_def=$(aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    ecs register-task-definition \
    --cli-input-json "$task_def_json")
colorteller_red_task_def_arn=($(echo $task_def \
    | jq -r '.taskDefinition | .taskDefinitionArn'))

# Color Teller Blue Task Definition
envoy_container_json=$(jq -n \
    --arg ENVOY_IMAGE $ENVOY_IMAGE \
    --arg VIRTUAL_NODE "mesh/$MESH_NAME/virtualNode/colorteller-blue-vn" \
    --arg APPMESH_XDS_ENDPOINT "${APPMESH_XDS_ENDPOINT}" \
    --arg ENVOY_LOG_LEVEL $envoy_log_level \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg AWS_LOG_STREAM_PREFIX_ENVOY "colorteller-blue-envoy" \
    -f "${DIR}/envoy-container.json")
xray_container_json=$(jq -n \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg AWS_LOG_STREAM_PREFIX_ENVOY "colorteller-blue-xray" \
    -f "${DIR}/xray-container.json")    
task_def_json=$(jq -n \
    --arg NAME "$ENVIRONMENT_NAME-ColorTellerBlue" \
    --arg STAGE "$APPMESH_STAGE" \
    --arg COLOR "blue" \
    --arg APP_IMAGE $COLOR_TELLER_IMAGE \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_LOG_STREAM_PREFIX_APP "colorteller-blue-app" \
    --arg TASK_ROLE_ARN $task_role_arn \
    --arg EXECUTION_ROLE_ARN $execution_role_arn \
    --argjson ENVOY_CONTAINER_JSON "${envoy_container_json}" \
    --argjson XRAY_CONTAINER_JSON "${xray_container_json}" \
    -f "${DIR}/colorteller-base-task-def.json")
task_def=$(aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    ecs register-task-definition \
    --cli-input-json "$task_def_json")
colorteller_blue_task_def_arn=($(echo $task_def \
    | jq -r '.taskDefinition | .taskDefinitionArn'))

# Color Teller Black Task Definition
envoy_container_json=$(jq -n \
    --arg ENVOY_IMAGE $ENVOY_IMAGE \
    --arg VIRTUAL_NODE "mesh/$MESH_NAME/virtualNode/colorteller-black-vn" \
    --arg APPMESH_XDS_ENDPOINT "${APPMESH_XDS_ENDPOINT}" \
    --arg ENVOY_LOG_LEVEL $envoy_log_level \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg AWS_LOG_STREAM_PREFIX_ENVOY "colorteller-black-envoy" \
    -f "${DIR}/envoy-container.json")
xray_container_json=$(jq -n \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg AWS_LOG_STREAM_PREFIX_ENVOY "colorteller-black-xray" \
    -f "${DIR}/xray-container.json")    
task_def_json=$(jq -n \
    --arg NAME "$ENVIRONMENT_NAME-ColorTellerBlack" \
    --arg STAGE "$APPMESH_STAGE" \
    --arg COLOR "black" \
    --arg APP_IMAGE $COLOR_TELLER_IMAGE \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg ECS_SERVICE_LOG_GROUP $ecs_service_log_group \
    --arg AWS_LOG_STREAM_PREFIX_APP "colorteller-black-app" \
    --arg TASK_ROLE_ARN $task_role_arn \
    --arg EXECUTION_ROLE_ARN $execution_role_arn \
    --argjson ENVOY_CONTAINER_JSON "${envoy_container_json}" \
    --argjson XRAY_CONTAINER_JSON "${xray_container_json}" \
    -f "${DIR}/colorteller-base-task-def.json")
task_def=$(aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    ecs register-task-definition \
    --cli-input-json "$task_def_json")
colorteller_black_task_def_arn=($(echo $task_def \
    | jq -r '.taskDefinition | .taskDefinitionArn'))

