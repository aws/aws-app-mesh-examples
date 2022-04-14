#!/usr/bin/env bash

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

update_mesh() {
    aws appmesh-ipv6 update-mesh --mesh-name "${MESH_NAME}-dns-mesh" --cli-input-json file://${DIR}/mesh.json
}

update_virtual_nodes() {
    aws appmesh-ipv6 update-virtual-node --mesh-name "${MESH_NAME}-dns-mesh" --cli-input-json file://${DIR}/red-vn.json
    aws appmesh-ipv6 update-virtual-node --mesh-name "${MESH_NAME}-dns-mesh" --cli-input-json file://${DIR}/orange-vn.json
    aws appmesh-ipv6 update-virtual-node --mesh-name "${MESH_NAME}-dns-mesh" --cli-input-json file://${DIR}/yellow-vn.json
    aws appmesh-ipv6 update-virtual-node --mesh-name "${MESH_NAME}-dns-mesh" --cli-input-json file://${DIR}/green-vn.json
    aws appmesh-ipv6 update-virtual-node --mesh-name "${MESH_NAME}-dns-mesh" --cli-input-json file://${DIR}/blue-vn.json
    aws appmesh-ipv6 update-virtual-node --mesh-name "${MESH_NAME}-dns-mesh" --cli-input-json file://${DIR}/purple-vn.json
}

update_virtual_node() {
    aws appmesh-ipv6 update-virtual-node --mesh-name "${MESH_NAME}-dns-mesh" --cli-input-json file://${DIR}/${1}.json
}

action=${1:-"mesh"}

if [ "$action" == "mesh" ]; then
    update_mesh
    exit 0
fi

if [ "$action" == "all-vn" ]; then
    update_virtual_nodes
    exit 0
fi

update_virtual_node $1