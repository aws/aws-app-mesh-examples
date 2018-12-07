#!/bin/bash

set -ex

if [ ! -z "${AWS_PROFILE}" ]; then
    PROFILE_OPT="--profile ${AWS_PROFILE}"
fi

if [ "$APPMESH_ENDPOINT" = "" ]; then
    appmesh_cmd="aws appmesh"
else
    appmesh_cmd="aws --endpoint-url "${APPMESH_ENDPOINT}" appmesh"
fi

$appmesh_cmd create-mesh \
    ${PROFILE_OPT}
     --mesh-name "${MESH_NAME}"
