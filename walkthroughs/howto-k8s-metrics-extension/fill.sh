#!/usr/bin/env bash

set -e

if [ -z "$1" ]; then
  echo "A file name is required" >&2
  exit 1
fi

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set." >&2
    exit 1
fi

if [ -z "$AWS_DEFAULT_REGION" ]; then
    echo "AWS_DEFAULT_REGION environment variable is not set." >&2
    exit 1
fi

if [ -z "$ENVOY_IMAGE" ]; then
    echo "ENVOY_IMAGE environtment variable is not set, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html" >&2
    exit 1
fi

if [ -z "$CLUSTER_NAME" ]; then
    echo "CLUSTER_NAME environment variable is not set." >&2
    exit 1
fi

if [ -z "$NAMESPACE_NAME" ]; then
    echo "NAMESPACE_NAME environment variable is not set." >&2
    exit 1
fi

eval "cat <<EOF
$(<"$1")
EOF"
