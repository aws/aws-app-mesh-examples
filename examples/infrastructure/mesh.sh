#!/bin/bash

set -ex

aws --endpoint-url ${APPMESH_FRONTEND} appmesh create-mesh --mesh-name ${MESH_NAME}
