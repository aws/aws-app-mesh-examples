#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

required_env=(
    AWS_REGION
    ENVIRONMENT_NAME
)

MESHNAME=default
SERVICES_DOMAIN=default.svc.cluster.local
ACTION=${1:-"deploy"}
AWS_PROFILE=${AWS_PROFILE:-"default"}
DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) >/dev/null && pwd )
SCRIPT=$(basename ${BASH_SOURCE[0]})

print() {
    printf "[${SCRIPT}] %s\n" "$*"
}

err() {
    msg="Error: $1"
    print $msg
    code=${2:-"1"}
    exit $code
}

usage() {
    msg=$1
    [ -z "$msg" ] || printf "Error: $msg\n"
    printf "Usage: ${SCRIPT} <action>\n"
    exit 1
}

check_env() {
    for i in "${required_env[@]}"; do
        echo "$i=${!i}"
        [ -z "${!i}" ] && err "$i must be set"
    done
}

deploy() {
    echo "${ACTION}.."
    
    if [[ ${ACTION} = "delete-stack" ]]; then
        aws --profile ${AWS_PROFILE} --region ${AWS_REGION} \
            cloudformation delete-stack \
            --stack-name ${ENVIRONMENT_NAME}-ecs-voteapp
        return
    fi
    
    aws --profile ${AWS_PROFILE} --region ${AWS_REGION} \
        cloudformation ${ACTION} \
        --stack-name ${ENVIRONMENT_NAME}-ecs-voteapp \
        --template-file ${DIR}/ecs-voteapp.yaml \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides \
            "EnvironmentName=${ENVIRONMENT_NAME}" \
            "AppMeshMeshName=${MESHNAME}" \
            "ECSServicesDomain=${SERVICES_DOMAIN}"
}

register_prometheus_grafana() {
    # Get web target group name, arn, and registered IP
    web_target_group=${ENVIRONMENT_NAME}-web
    web_target_group_arn=$(aws elbv2 describe-target-groups --names $web_target_group --query "TargetGroups[0].TargetGroupArn" --output text)
    web_registered_ip=$(aws elbv2 describe-target-health --target-group-arn $web_target_group_arn --query "TargetHealthDescriptions[0].Target.Id" --output=text)
    
    # Get prometheus target group name and arn => register web target
    prom_target_group=${ENVIRONMENT_NAME}-prometheus-1
    prom_target_group_arn=$(aws elbv2 describe-target-groups --names $prom_target_group --query "TargetGroups[0].TargetGroupArn" --output text)
    aws elbv2 register-targets --target-group-arn $prom_target_group_arn --targets Id=$web_registered_ip,Port=9090
    
    # Get grafana target group name and arn => register web target
    grafana_target_group=${ENVIRONMENT_NAME}-grafana-1
    grafana_target_group_arn=$(aws elbv2 describe-target-groups --names $grafana_target_group --query "TargetGroups[0].TargetGroupArn" --output text)
    aws elbv2 register-targets --target-group-arn $grafana_target_group_arn --targets Id=$web_registered_ip,Port=3000
}

print_info() {
    print "Public endpoints"
    print "================"
    url=$(aws cloudformation --region us-west-2 describe-stacks --stack-name ${ENVIRONMENT_NAME}-ecs-cluster --query 'Stacks[0].Outputs[?OutputKey==`ExternalUrl`].OutputValue' --output text)
    print "voteapp: $url"
    print "prometheus: $url:9090/targets"
    print "grafana: $url:3000"
    
    logs=$(aws cloudformation --region us-west-2 describe-stacks --stack-name ${ENVIRONMENT_NAME}-ecs-cluster --query 'Stacks[0].Outputs[?OutputKey==`ECSServiceLogGroup`].OutputValue' --output text)
    print "logs: https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#logStream:group=$logs"
}

main() {
    check_env
    deploy
    register_prometheus_grafana
    print_info
}

main $@
