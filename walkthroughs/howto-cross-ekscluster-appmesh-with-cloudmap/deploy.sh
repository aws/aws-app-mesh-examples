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

if [ -z $CLUSTER1 ]; then
    echo "CLUSTER1 Name not set"
    exit 1
fi

if [ -z $CLUSTER2 ]; then
    echo "CLUSTER2 Name not set"
    exit 1
fi

if [ -z $VPC_ID ]; then
    echo "VPC_ID is not set"
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PROJECT_NAME="appmesh-demo"
APP_NAMESPACE=${PROJECT_NAME}
MESH_NAME=${PROJECT_NAME}
CLOUDMAP_NAMESPACE="${PROJECT_NAME}.pvt.aws.local"

ECR_IMAGE_PREFIX="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT_NAME}"
FRONT_APP_IMAGE="${ECR_IMAGE_PREFIX}/feapp"
COLOR_APP_IMAGE="${ECR_IMAGE_PREFIX}/colorapp"

deploy_images() {
    for app in colorapp feapp; do
        aws ecr describe-repositories --repository-name $PROJECT_NAME/$app >/dev/null 2>&1 || aws ecr create-repository --repository-name $PROJECT_NAME/$app
        docker build -t ${ECR_IMAGE_PREFIX}/${app} ${DIR}/${app}
        $(aws ecr get-login --no-include-email)
        docker push ${ECR_IMAGE_PREFIX}/${app}
    done
}


deploy_cloudmap_ns() {
    nsId=($(aws servicediscovery list-namespaces |
        jq -r ".Namespaces[] | select(.Name | contains(\"${CLOUDMAP_NAMESPACE}\")) | .Id"))

    if [ -z "${nsId}" ]; then
        if [ -z "${VPC_ID}" ]; then
            echo "VPC_ID must be set. VPC_ID corresponds to vpc where applications are deployed."
            exit 1
        fi

        aws servicediscovery create-private-dns-namespace \
            --name "${CLOUDMAP_NAMESPACE}" \
            --vpc "${VPC_ID}"
        echo "Created private-dns-namespace ${CLOUDMAP_NAMESPACE}"
        sleep 5
    fi
}

deploy_apps_and_mesh() {
    
    EXAMPLES_OUT_DIR="${DIR}/_output/"
    mkdir -p ${EXAMPLES_OUT_DIR}
    
    eval "cat <<EOF
    $(<${DIR}/cluster2.yaml.template)
    EOF
    " >${EXAMPLES_OUT_DIR}/cluster2.yaml

    eval "cat <<EOF
    $(<${DIR}/cluster1.yaml.template)
    EOF
    " >${EXAMPLES_OUT_DIR}/cluster1.yaml

    KUBECONFIG="$HOME/.kube/eksctl/clusters/${CLUSTER1}" kubectl apply -f ${EXAMPLES_OUT_DIR}/cluster1.yaml
    KUBECONFIG="$HOME/.kube/eksctl/clusters/${CLUSTER2}" kubectl apply -f ${EXAMPLES_OUT_DIR}/cluster2.yaml

}

main() {
    deploy_cloudmap_ns
    
    if [ -z $SKIP_IMAGES ]; then
        echo "deploy images..."
        deploy_images
    fi
    
    deploy_apps_and_mesh
}

main