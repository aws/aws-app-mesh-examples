#!/bin/bash

set -eo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PROJECT_NAME="bulkhead-pattern"
APP_NAMESPACE=${PROJECT_NAME}
APP="price-app"
EXAMPLES_OUT_DIR="${DIR}/_output/"

delete_ecr_repository() {
    aws ecr delete-repository --repository-name $PROJECT_NAME/${APP} --force
}

delete_kubernetes_and_mesh() {
    kubectl delete -f ${EXAMPLES_OUT_DIR}/base.yaml
}

main() {
    delete_ecr_repository
    delete_kubernetes_and_mesh
}

main
