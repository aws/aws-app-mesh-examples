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

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

PROJECT_NAME="howto-k8s-http-ingress-v2"
MESH_NAME=${PROJECT_NAME}
APP_NAMESPACE=${PROJECT_NAME}
EXAMPLES_OUT_DIR="${DIR}/_output/"
GW_ROUTES="gatewayroutes"
MANIFEST_VERSION="${2:-v1beta2}"
mkdir -p ${EXAMPLES_OUT_DIR}

gwRouteForPathMatch() {
    echo "Adding GWRoute for Path based match"
    eval "cat <<EOF
$(<${DIR}/${MANIFEST_VERSION}/${GW_ROUTES}/path-match.yaml.template)
EOF
" >${EXAMPLES_OUT_DIR}/path-match.yaml

kubectl apply -f ${EXAMPLES_OUT_DIR}/path-match.yaml
}

gwRouteForHeaderMatch() {
    echo "Adding GWRoute for Header based match"
    eval "cat <<EOF
$(<${DIR}/${MANIFEST_VERSION}/${GW_ROUTES}/header-match.yaml.template)
EOF
" >${EXAMPLES_OUT_DIR}/header-match.yaml

kubectl apply -f ${EXAMPLES_OUT_DIR}/header-match.yaml
}

gwRouteForQueryMatch() {
    echo "Adding GWRoute for Query based match"
    eval "cat <<EOF
$(<${DIR}/${MANIFEST_VERSION}/${GW_ROUTES}/query-match.yaml.template)
EOF
" >${EXAMPLES_OUT_DIR}/query-match.yaml

kubectl apply -f ${EXAMPLES_OUT_DIR}/query-match.yaml
}

gwRouteForPrefixRewrite() {
    echo "Adding GWRoute with Prefix Rewrite"
    eval "cat <<EOF
$(<${DIR}/${MANIFEST_VERSION}/${GW_ROUTES}/rewrite-prefix.yaml.template)
EOF
" >${EXAMPLES_OUT_DIR}/prefix-rewrite.yaml

kubectl apply -f ${EXAMPLES_OUT_DIR}/prefix-rewrite.yaml
}

gwRouteForPathRewrite(){
    echo "Adding GWRoute with Path Rewrite"
    eval "cat <<EOF
$(<${DIR}/${MANIFEST_VERSION}/${GW_ROUTES}/rewrite-path.yaml.template)
EOF
" >${EXAMPLES_OUT_DIR}/path-rewrite.yaml

kubectl apply -f ${EXAMPLES_OUT_DIR}/path-rewrite.yaml
}

gwRouteForMethodMatch(){ 
    echo "Adding GWRoute with Metod match"
    eval "cat <<EOF
$(<${DIR}/${MANIFEST_VERSION}/${GW_ROUTES}/method-match.yaml.template)
EOF
" >${EXAMPLES_OUT_DIR}/method-match.yaml

kubectl apply -f ${EXAMPLES_OUT_DIR}/method-match.yaml
}

gwRouteForAll() {
    echo "Adding all GWRoutes"
    gwRouteForPathMatch
    gwRouteForHeaderMatch
    gwRouteForQueryMatch
    gwRouteForMethodMatch
    gwRouteForPrefixRewrite
    gwRouteForPathRewrite
}

for i in $@
do
    if [ $i == "path-match" ]; then
        gwRouteForPathMatch
    elif [ $i == "header-match" ]; then
        gwRouteForHeaderMatch
    elif [ $i == "query-match" ]; then
        gwRouteForQueryMatch
    elif [ $i == "method-match" ]; then
        gwRouteForMethodMatch
    elif [ $i == "prefix-rewrite" ]; then
        gwRouteForPrefixRewrite
    elif [ $i == "path-rewrite" ]; then
        gwRouteForPathRewrite
    elif [ $i == "all" ]; then
        gwRouteForAll
        break
    fi
done
