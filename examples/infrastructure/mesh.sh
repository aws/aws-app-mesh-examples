#!/bin/bash

set -ex

if [ ! -z "${AWS_PROFILE}" ]; then
    PROFILE_OPT="--profile ${AWS_PROFILE}"
fi

aws ${PROFILE_OPT} appmesh create-mesh --mesh-name "${MESH_NAME}"
