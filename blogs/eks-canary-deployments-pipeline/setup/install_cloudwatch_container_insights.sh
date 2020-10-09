#!/usr/bin/env bash

# Load environment variables
source ~/.bash_profile

# Attach CloudWatchAgentServerPolicy to EKS nodegroup role
aws iam attach-role-policy --region $AWS_REGION --role-name $EKS_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

# Install Container Insights
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/$EKS_CLUSTER_NAME/;s/{{region_name}}/$AWS_REGION/" | kubectl apply -f -

# Configure Prometheus
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/prometheus-beta/k8s-deployment-manifest-templates/deployment-mode/service/cwagent-prometheus/prometheus-eks.yaml