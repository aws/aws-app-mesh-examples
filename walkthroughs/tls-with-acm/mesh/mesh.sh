#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-mesh" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/mesh.yaml" \
    --parameter-overrides \
    MeshName="${MESH_NAME}" \
    ServicesDomain="${SERVICES_DOMAIN}" \
    CertificateAuthorityArn="${ROOT_CA_ARN}" \
    CertificateArn="${CERTIFICATE_ARN}"
