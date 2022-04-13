#!/usr/bin/env bash

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

aws appmesh update-mesh --mesh-name "${MESH_NAME}-vg-mesh" --cli-input-json file://${DIR}/mesh.json

aws appmesh update-virtual-node --mesh-name "${MESH_NAME}-vg-mesh" --cli-input-json file://${DIR}/red-vn.json
aws appmesh update-virtual-node --mesh-name "${MESH_NAME}-vg-mesh" --cli-input-json file://${DIR}/orange-vn.json
aws appmesh update-virtual-node --mesh-name "${MESH_NAME}-vg-mesh" --cli-input-json file://${DIR}/yellow-vn.json
aws appmesh update-virtual-node --mesh-name "${MESH_NAME}-vg-mesh" --cli-input-json file://${DIR}/green-vn.json
aws appmesh update-virtual-node --mesh-name "${MESH_NAME}-vg-mesh" --cli-input-json file://${DIR}/blue-vn.json
aws appmesh update-virtual-node --mesh-name "${MESH_NAME}-vg-mesh" --cli-input-json file://${DIR}/purple-vn.json