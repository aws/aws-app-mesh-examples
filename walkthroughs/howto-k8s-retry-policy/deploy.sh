#!/bin/bash

set -e

if [ -z $AWS_ACCOUNT_ID ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z $AWS_DEFAULT_REGION ]; then
    echo "AWS_DEFAULT_REGION environment variable is not set."
    exit 1
fi

if [ -z $ENVOY_IMAGE ]; then
    echo "ENVOY_IMAGE environment variable is not set to App Mesh Envoy, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html"
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PROJECT_NAME="howto-k8s-retry-policy"
APP_NAMESPACE=${PROJECT_NAME}
MESH_NAME=${PROJECT_NAME}

ECR_IMAGE_PREFIX="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT_NAME}"
FRONT_APP_IMAGE="${ECR_IMAGE_PREFIX}/feapp"
COLOR_APP_IMAGE="${ECR_IMAGE_PREFIX}/colorapp"

error() {
    echo $1
    exit 1
}

check_appmesh_k8s() {
    #check CRD
    crd=$(kubectl get crd virtualservices.appmesh.k8s.aws -o json | jq -e '.. | .retryPolicy? | select(. != null)')
    if [ "$crd" = "" ]; then 
        echo "$PROJECT_NAME requires CRD that supports retryPolicy. See https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/CHANGELOG.md#v020"
        exit 1
    fi

    #check aws-app-mesh-controller version
    currentver=$(kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':')
    requiredver="v0.2.0"
    if [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" = "$requiredver" ]; then
        echo "aws-app-mesh-controller check passed! $currentver >= $requiredver"
    else
        error "$PROJECT_NAME requires aws-app-mesh-controller version >=$requiredver but found $currentver. See https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/CHANGELOG.md#v020"
    fi
}

deploy_images() {
    for app in colorapp feapp; do
        aws ecr describe-repositories --repository-name $PROJECT_NAME/$app >/dev/null 2>&1 || aws ecr create-repository --repository-name $PROJECT_NAME/$app
        docker build -t ${ECR_IMAGE_PREFIX}/${app} ${DIR}/${app}
        $(aws ecr get-login --no-include-email)
        docker push ${ECR_IMAGE_PREFIX}/${app}
    done
}

deploy_app() {
    EXAMPLES_OUT_DIR="${DIR}/_output/"
    mkdir -p ${EXAMPLES_OUT_DIR}
    eval "cat <<EOF
$(<${DIR}/manifest.yaml.template)
EOF
" >${EXAMPLES_OUT_DIR}/manifest.yaml

    kubectl apply -f ${EXAMPLES_OUT_DIR}/manifest.yaml
}

main() {
    check_appmesh_k8s

    if [ -z $SKIP_IMAGES ]; then
        echo "deploy images..."
        deploy_images
    fi

    deploy_app
}

main
