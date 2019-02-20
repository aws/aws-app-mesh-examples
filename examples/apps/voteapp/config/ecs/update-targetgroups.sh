#!/bin/bash

#Get web target group name and arn
web_target_group=${ENVIRONMENT_NAME}-web
web_target_group_arn=$(aws elbv2 describe-target-groups --names $web_target_group --query "TargetGroups[0].TargetGroupArn" --output text)

#Get prometheus target group name and arn
prom_target_group=${ENVIRONMENT_NAME}-prometheus-1
prom_target_group_arn=$(aws elbv2 describe-target-groups --names $prom_target_group --query "TargetGroups[0].TargetGroupArn" --output text)

#Get grafana target group name and arn
grafana_target_group=${ENVIRONMENT_NAME}-grafana-1
grafana_target_group_arn=$(aws elbv2 describe-target-groups --names $grafana_target_group --query "TargetGroups[0].TargetGroupArn" --output text)

#Get registered ip address with web target group
registered_ip=$(aws elbv2 describe-target-health --target-group-arn $web_target_group_arn --query "TargetHealthDescriptions[0].Target.Id" --output=text)


aws elbv2 register-targets --target-group-arn $prom_target_group_arn --targets Id=$registered_ip,Port=9090
aws elbv2 register-targets --target-group-arn $grafana_target_group_arn --targets Id=$registered_ip,Port=3000
