#!/bin/bash

set -ex

aws appmesh create-mesh --mesh-name ${MESH_NAME}
