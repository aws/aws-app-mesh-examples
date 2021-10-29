#!/usr/bin/env bash

check_command() {
  if ! [ -x "$(command -v "$1")" ]; then
    echo "$1 is required to run this script"
    exit
  fi
}

check_command aws

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z "$AWS_DEFAULT_REGION" ]; then
    echo "AWS_DEFAULT_REGION environment variable is not set."
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

usage() {
  echo "usage: $(basename "$0") [-h]
    -c <command>                         deploy or delete
    -s <stack name>                      Cloudformation stack name 
    [ -q <metric namespace> ]            Metric namespace name
    [ -d <dashboard name> ]              Cloudformation dashboard name
    [ -i <dashboard lambda image uri> ]  Dashboard generator lambda image URI
    [ -m <mesh name> ]                   Mesh name
    [ -g <virtual gateway name> ]        Virtual gateway name.
    [ -n <virtual nodes> ]               Comma separated list of virtual node names."
  exit 1
}

delete_cfn_stack() {
    stack_name="$1"
    aws cloudformation delete-stack --stack-name "$stack_name"
    echo "Waiting for the stack $stack_name to be deleted, this may take a few minutes..."
    aws cloudformation wait stack-delete-complete --stack-name "$stack_name"
    echo "Done"
}

check_opt() {
  name="$1"
  msg="$2"
  if [ -z "$name" ]; then
    echo "$msg"
    exit 1
  fi
}

if [ -z "$1" ]; then
  usage
fi

while getopts ":c:s:q:d:i:m:g:n:h" options; do
  case "$options" in
    c)
      cmd="$OPTARG"
      ;;
    s)
      stack_name="$OPTARG"
      ;;
    q)
      metric_namespace="$OPTARG"
      ;;
    d)
      dashboard_name="$OPTARG"
      ;;
    i)
      dashboard_image="$OPTARG"
      ;;
    m)
      mesh_name="$OPTARG"
      ;;
    g)
      resource_type=VirtualGateway
      resources="$OPTARG"
      ;;
    n)
      resource_type=VirtualNodes
      resources="$OPTARG"
      ;;
    h|:|*)
      usage
      ;;
  esac
done

check_opt "$cmd" "A command, deploy or delete must be specified"
check_opt "$stack_name" "Stack name is required"

case "$cmd" in
  delete)
    delete_cfn_stack "$stack_name" 
    ;;
  deploy)
    check_opt "$dashboard_image" "Dashboard generator image URI is required"
    check_opt "$metric_namespace" "Metric namespace is required"
    check_opt "$mesh_name" "Mesh name is required"
    check_opt "$dashboard_name" "Dashboard name is required"
    check_opt "$resources" "Either a list of virtual node names or a virtual gateway name is required"

    echo "Deploying stack $stack_name, this may take a few minutes..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "$stack_name" \
        --template-file "$DIR/deploy/dashboard-v1.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides \
        "DashboardImage=$dashboard_image" \
        "MetricNamespace=$metric_namespace" \
        "MeshName=$mesh_name" \
        "Name=$dashboard_name" \
        "$resource_type=$resources"    
    ;;
  *)
    echo "Command must be either deploy or delete"
    exit 1
    ;;
esac
