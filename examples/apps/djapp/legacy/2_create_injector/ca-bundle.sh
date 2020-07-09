#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

export MESH_NAME=dj-app
export IMAGE_NAME=602401143452.dkr.ecr.us-west-2.amazonaws.com/amazon/aws-app-mesh-inject:v0.1.0
export MESH_REGION="" # Leave this empty

ROOT=$(cd $(dirname $0)/; pwd)

if [[ -z ${CA_BUNDLE:-} ]]; then
    export CA_BUNDLE=$(kubectl config view --raw -o json --minify | jq -r '.clusters[0].cluster."certificate-authority-data"' | tr -d '"')
fi

echo "processing templates"
eval "cat <<EOF
$(<${ROOT}/inject.yaml.template)
EOF
" > ${ROOT}/inject.yaml

echo "Created injector manifest at:${ROOT}/inject.yaml"
