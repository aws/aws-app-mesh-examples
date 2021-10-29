#!/usr/bin/env bash

set -e

check_command() {
  if ! [ -x "$(command -v "$1")" ]; then
    echo "$1 is required to run this script"
    exit
  fi
}

check_command base64
check_command aws

if [ -x "$(command -v jq)" ]; then
  image_extract=(jq -r '.MetricWidgetImage')
else
  echo "jq is reccomended to run this script. Will fall back to parsing JSON with sed"
  image_extract=(sed -En 's/\{? *"MetricWidgetImage" *: *"([^"]+) *,? *\}?"/\1/p')
fi

case "$(uname -a)" in
  Linux*)
    open_cmd=xdg-open
    ;;
  Darwin*)
    open_cmd=open
    ;;
  *)
    echo "This command only works on Linux or MacOS"
    exit 1
    ;;
esac

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z "$AWS_DEFAULT_REGION" ]; then
    echo "AWS_DEFAULT_REGION environment variable is not set."
    exit 1
fi

PROJECT_NAME="${PROJECT_NAME:-"howto-metrics-extension"}"

usage() {
  echo "usage: $(basename "$0") [-h]
  -m <metric name>            envoy.appmesh.RequestCountPerTarget
  [ -n <node name> ]          e.g. djapp
  [ -t <node type> ]          VirtualNode, VirtualGateway
  [ -q <search expression> ]  e.g. TargetVirtualNode=metal-v1 
  [ -x <metric statistic> ]   Average, Sum, p50, etc. Default: Average
  [ -s <start time> ]         e.g. -PT3H, -P2D, etc. Default: -PT15M
  [ -p <period> ]             Period in seconds. Default: 60"
  exit 1
}

if [ -z "$1" ]; then
  usage
fi

statistic="Average"
start_time="-PT15M"
period="60"

while getopts ":m:x:s:t:n:q:p:h" options; do
  case "$options" in
    m)
      metric_name="$OPTARG"
      ;;
    x)
      statistic="$OPTARG"
      ;;
    s)
      start_time="$OPTARG"
      ;;
    t)
      node_type="$OPTARG"
      ;;
    n)
      node_name="$OPTARG"
      ;;
    q)
      query="$OPTARG"
      ;;
    p)
      period="$OPTARG"
      ;;
    h|:|*)
      usage
      ;;
  esac
done

if ! [ -z "$node_name" ]; then
  if [ -z "$node_type" ]; then
    echo "Node type must be specified with a node name"
    exit 1
  fi
fi

if ! [ -z "$node_type" ]; then
  if [ -z "$node_name" ]; then
    echo "Node name must be specified with a node type"
    exit 1
  fi
fi

if [ -z "$node_name" ]; then
  title="$metric_name $statistic"
  expression=$(cat <<EOF
{ "expression": "SEARCH('Namespace=\"$PROJECT_NAME\" MetricName=\"$metric_name\" $query', '$statistic', $period)" }
EOF
)
else
  title="$node_name - $metric_name $statistic"
  expression=$(cat <<EOF
{ "expression": "SEARCH('Namespace=\"$PROJECT_NAME\" Mesh=\"$PROJECT_NAME\" $node_type=\"$node_name\" MetricName=\"$metric_name\" $query', '$statistic', $period)" }
EOF
)
fi

widget=$(cat <<EOF
{
  "width": 1200,
  "height": 600,
  "period": $period,
  "start": "$start_time",
  "end": "PT0H",
  "title": "$title",
  "metrics": [
    [
      $expression
    ]
  ]
}
EOF
)

echo "Metric widget:"
echo "$widget"

file="$(mktemp -u).png"

echo "Saving metric snapshot to $file"

aws cloudwatch get-metric-widget-image --metric-widget "$widget" | "${image_extract[@]}" | base64 -d > "$file"

$open_cmd "$file"
