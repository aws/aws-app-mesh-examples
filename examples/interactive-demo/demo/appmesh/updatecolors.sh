#!/bin/bash
set -x
aws appmesh update-route --mesh-name ${MESH_NAME} --cli-input-json file://colors.r.2.json
