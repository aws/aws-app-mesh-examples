#!/bin/bash

set -eo pipefail

if [ -z $AWS_ACCOUNT_ID ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z $AWS_REGION ]; then
    echo "AWS_REGION environment variable is not set."
    exit 1
fi

AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PROJECT_NAME="howto-k8s-envoy-logging-custom-format"

ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_IMAGE_PREFIX="${ECR_URL}/${PROJECT_NAME}"
FRONT_APP_IMAGE="${ECR_IMAGE_PREFIX}/feapp"
COLOR_APP_IMAGE="${ECR_IMAGE_PREFIX}/colorapp"

error() {
    echo $1
    exit 1
}

ecr_login() {
    if [ $AWS_CLI_VERSION -gt 1 ]; then
        aws ecr get-login-password --region ${AWS_REGION} | \
            docker login --username AWS --password-stdin ${ECR_URL}
    else
        $(aws ecr get-login --no-include-email)
    fi
}

deploy_images() {
    ecr_login
    for app in colorapp feapp; do
        aws ecr describe-repositories --repository-name $PROJECT_NAME/$app >/dev/null 2>&1 || aws ecr create-repository --repository-name $PROJECT_NAME/$app >/dev/null
        docker build -t ${ECR_IMAGE_PREFIX}/${app} ${DIR}/${app}
        docker push ${ECR_IMAGE_PREFIX}/${app}
    done
}

main() {
    if [ -z $SKIP_IMAGES ]; then
        echo "deploy images..."
        deploy_images
    fi
    eval "cat <<EOF
$(<${DIR}/manifest.yaml.template)
EOF
" >${DIR}/manifest.yaml
    kubectl apply -f ${DIR}/manifest.yaml
}

main
