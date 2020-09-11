#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
TEST_MESH_DIR="${DIR}"

sanity_check() {
    if [ -z "${MESH_NAME}" ]; then
        err "MESH_NAME is not set"
    fi
    if [ -z "${ENVIRONMENT_NAME}" ]; then
        err "ENVIRONMENT_NAME is not set"
    fi
    if [ -z "${SERVICES_DOMAIN}" ]; then
        err "SERVICES_DOMAIN is not set"
    fi
    if [ -z "${AWS_DEFAULT_REGION}" ]; then
        err "AWS_DEFAULT_REGION is not set"
    fi
}


# $1 ColorTellerGreenRouteWeight
# $2 EnableClientValidationFlag
# $3 ColorGatewayTlsValidationPath
callCloudformation() {
    aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
        cloudformation deploy \
        --stack-name "${ENVIRONMENT_NAME}-mesh" \
        --capabilities CAPABILITY_IAM \
        --template-file "${DIR}/mesh.yaml" \
        --parameter-overrides \
        MeshName="${MESH_NAME}" \
        ServicesDomain="${SERVICES_DOMAIN}" \
        ColorTellerGreenRouteWeight=$1 \
        EnableClientValidationFlag=$2 \
        ColorGatewayTlsValidationPath=$3
}


main() {
    action="$1"
    if [ -z "$action" ]; then
        echo "Usage:"
        echo "mesh.sh [up|addGreen|updateGateway|updateGateway2]"
    fi
    sanity_check

    case "$action" in
    up)
        callCloudformation 0 "false"
        ;;
    addGreen)
        callCloudformation 1 "false"
        ;;
    updateGateway)
        callCloudformation 1 "true" "/keys/ca_1_cert.pem"
        ;;
    updateGateway2)
        callCloudformation 1 "true" "/keys/ca_1_ca_2_bundle.pem"
        ;;    
    *)
        err "Invalid action specified: $action"
        ;;
    esac
}

main $@
