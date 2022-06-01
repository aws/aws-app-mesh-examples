#!/bin/bash

set -eo pipefail

if [ -z $AWS_ACCOUNT_ID ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z $AWS_DEFAULT_REGION ]; then
    echo "AWS_DEFAULT_REGION environment variable is not set."
    exit 1
fi

AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PROJECT_NAME="howto-k8s-ipv6"
APP_NAMESPACE=${PROJECT_NAME}
CLOUDMAP_NAMESPACE="${APP_NAMESPACE}.svc.cluster.local"
MESH_NAME=${PROJECT_NAME}

ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
ECR_IMAGE_PREFIX="${ECR_URL}/${PROJECT_NAME}"
FRONT_APP_IMAGE="${ECR_IMAGE_PREFIX}/color_client"
COLOR_APP_IMAGE="${ECR_IMAGE_PREFIX}/color_server"
MANIFEST_VERSION="${2:-v1beta2}"

error() {
    echo $1
    exit 1
}

check_k8s_virtualrouter() {
    #check CRD
    crd=$(kubectl get crd virtualrouters.appmesh.k8s.aws -o json )
    if [ -z "$crd" ]; then
        error "$PROJECT_NAME requires virtualrouters.appmesh.k8s.aws CRD to support HTTP headers match. See https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/CHANGELOG.md"
    else
        echo "CRD check passed!"
    fi
}

check_k8s_virtualservice() {
    #check CRD
    crd=$(kubectl get crd virtualservices.appmesh.k8s.aws -o json | jq -r '.. | .match?.properties.headers | select(. != null)')
    if [ -z "$crd" ]; then
        error "$PROJECT_NAME requires virtualservices.appmesh.k8s.aws CRD to support HTTP headers match. See https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/CHANGELOG.md#v020"
    else
        echo "CRD check passed!"
    fi
}

check_appmesh_k8s() {
    #check aws-app-mesh-controller version
    if [ "$MANIFEST_VERSION" = "v1beta2" ]; then
        currentver=$(kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1)
        requiredver="v1.0.0"
        check_k8s_virtualrouter
    elif [ "$MANIFEST_VERSION" = "v1beta1" ]; then
        currentver=$(kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':')
        requiredver="v0.2.0"
        check_k8s_virtualservice
    else
        error "$PROJECT_NAME unexpected manifest version input: $MANIFEST_VERSION. Should be v1beta2 or v1beta1 based on the AppMesh controller version. See https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/CHANGELOG.md"
    fi

    if [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" = "$requiredver" ]; then
        echo "aws-app-mesh-controller check passed! $currentver >= $requiredver"
    else
        error "$PROJECT_NAME requires aws-app-mesh-controller version >=$requiredver but found $currentver. See https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/CHANGELOG.md"
    fi
}

ecr_login() {
    if [ $AWS_CLI_VERSION -gt 1 ]; then
        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
            docker login --username AWS --password-stdin ${ECR_URL}
    else
        $(aws ecr get-login --no-include-email)
    fi
}

deploy_images() {
    ecr_login
    for app in color_client color_server; do
        aws ecr describe-repositories --repository-name $PROJECT_NAME/$app >/dev/null 2>&1 || aws ecr create-repository --repository-name $PROJECT_NAME/$app >/dev/null
        docker build -t ${ECR_IMAGE_PREFIX}/${app} ${DIR}/${app}
        docker push ${ECR_IMAGE_PREFIX}/${app}
    done
}

deploy_cloudmap_ns() {
    nsId=($(aws servicediscovery list-namespaces --output json |
        jq -r ".Namespaces[] | select(.Name | contains(\"${CLOUDMAP_NAMESPACE}\")) | .Id"))

    if [ -z "${nsId}" ]; then
        if [ -z "${VPC_ID}" ]; then
            echo "VPC_ID must be set. VPC_ID corresponds to vpc where applications are deployed."
            exit 1
        fi

        aws servicediscovery create-private-dns-namespace \
            --name "${CLOUDMAP_NAMESPACE}" \
            --vpc "${VPC_ID}" >/dev/null
        echo "Created private-dns-namespace ${CLOUDMAP_NAMESPACE}"
        sleep 5
    fi
}

deploy_cloud() {
    EXAMPLES_OUT_DIR="${DIR}/_output/cloud"
    mkdir -p ${EXAMPLES_OUT_DIR}
    eval "cat <<EOF
$(<${DIR}/${MANIFEST_VERSION}/cloud/manifest.yaml.template)
EOF
" >${EXAMPLES_OUT_DIR}/manifest.yaml

    kubectl apply -f ${EXAMPLES_OUT_DIR}/manifest.yaml
}

deploy_dns() {
    EXAMPLES_OUT_DIR="${DIR}/_output/dns"
    mkdir -p ${EXAMPLES_OUT_DIR}
    eval "cat <<EOF
$(<${DIR}/${MANIFEST_VERSION}/dns/manifest.yaml.template)
EOF
" >${EXAMPLES_OUT_DIR}/manifest.yaml

    kubectl apply -f ${EXAMPLES_OUT_DIR}/manifest.yaml
}

main() {
    #check_appmesh_k8s

    action="$1"

    if [ -z $SKIP_IMAGES ]; then
        echo "deploy images..."
        deploy_images
    fi

    if [ "$action" = "cloudmap" ]; then
        echo "deploy cloudmap..."
        deploy_cloudmap_ns
        deploy_cloud
        exit 0
    fi

    if [ "$action" = "dns" ]; then
        deploy_dns
        exit 0
    fi
}

main $@
