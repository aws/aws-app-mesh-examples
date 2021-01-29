#!/usr/bin/env bash

shopt -s nullglob

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
MESH_DIR="${DIR}/mesh"
PROJECT_NAME="howto-outlier-detection"
MESH_NAME=$PROJECT_NAME
CLOUDMAP_NAMESPACE_NAME=${PROJECT_NAME}.local

print() {
    printf "[$(date)] : %s\n" "$*"
}

err() {
    msg="Error: $1"
    print "${msg}"
    code=${2:-"1"}
    exit ${code}
}

appmesh_cmd="aws appmesh"

create_mesh() {
    cmd=( $appmesh_cmd create-mesh --mesh-name "${MESH_NAME}" \
                --query mesh.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create mesh" "$?"
    print "--> ${uid}"
}

delete_mesh() {
    cmd=( $appmesh_cmd delete-mesh --mesh-name "${MESH_NAME}" \
                --query mesh.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete mesh" "$?"
    print "--> ${uid}"
}

create_vnode() {
    spec_file=$1
    cli_input=$( jq -n \
        --arg NAMESPACE_NAME "${CLOUDMAP_NAMESPACE_NAME}" \
        --arg BACKEND_VS_NAME "color.${CLOUDMAP_NAMESPACE_NAME}" \
        -f "$spec_file" )
    cmd=( $appmesh_cmd create-virtual-node --mesh-name "${MESH_NAME}" \
                --cli-input-json "$cli_input" \
                --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual node" "$?"
    print "--> ${uid}"
}

update_vnode() {
    spec_file=$1
    cli_input=$( jq -n \
        --arg NAMESPACE_NAME "${CLOUDMAP_NAMESPACE_NAME}" \
        -f "$spec_file" )
    cmd=( $appmesh_cmd update-virtual-node --mesh-name "${MESH_NAME}" \
                --cli-input-json "$cli_input" \
                --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual node" "$?"
    print "--> ${uid}"
}

delete_vnode() {
    vnode_name=$1
    cmd=( $appmesh_cmd delete-virtual-node --mesh-name "${MESH_NAME}" \
                --virtual-node-name "${vnode_name}" \
                --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual node" "$?"
    print "--> ${uid}"
}

create_vservice() {
    spec_file=$1
    vservice_name=$2
    cli_input=$( jq -n \
    --arg VIRTUAL_SERVICE_NAME "${vservice_name}" \
    -f "$spec_file" )
    cmd=( $appmesh_cmd create-virtual-service --mesh-name "${MESH_NAME}" \
                --cli-input-json "$cli_input" \
                --query virtualService.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual service" "$?"
    print "--> ${uid}"
}

delete_vservice() {
    vservice_name=$1
    cmd=( $appmesh_cmd delete-virtual-service --mesh-name "${MESH_NAME}" \
                --virtual-service-name "${vservice_name}" \
                --query virtualService.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual service" "$?"
    print "--> ${uid}"
}

create_vgateway() {
    spec_file=$1
    cli_input=$( jq -n \
        -f "$spec_file" )
    vgateway_name=$2
    cmd=( $appmesh_cmd create-virtual-gateway --mesh-name "${MESH_NAME}" \
            --cli-input-json "$cli_input" \
            --query virtualGateway.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual gateway" "$?"
    print "--> ${uid}"
}

delete_vgateway(){
    vgateway_name=$1
    cmd=( $appmesh_cmd delete-virtual-gateway --mesh-name "${MESH_NAME}" \
            --virtual-gateway-name "${vgateway_name}" \
            --query virtualGateway.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual gateway" "$?"
    print "--> ${uid}"
}

create_gateway_route() {
    spec_file=$1
    vservice_name=$2
    gateway_route_name=$3
    vgateway_name=$4
    cli_input=$( jq -n \
    --arg VIRTUAL_SERVICE_NAME "${vservice_name}" \
    -f "$spec_file" )
    cmd=( $appmesh_cmd create-gateway-route --mesh-name "${MESH_NAME}" \
            --gateway-route-name "${gateway_route_name}" \
            --virtual-gateway-name "${vgateway_name}" \
            --cli-input-json "$cli_input" \
            --query gatewayRoute.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create gateway route" "$?"
    print "--> ${uid}"
}

delete_gateway_route(){
    vgateway_name=$1
    gateway_route_name=$2
    cmd=( $appmesh_cmd delete-gateway-route --mesh-name "${MESH_NAME}" \
            --virtual-gateway-name "${vgateway_name}" \
            --gateway-route-name "${gateway_route_name}")
            #--query gatewayRoute.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual gateway" "$?"
    print "--> ${uid}"
}

main() {
    action="$1"
    if [ -z "$action" ]; then
        echo "Usage:"
        echo "mesh.sh [up|down|add-outlier-detection|remove-outlier-detection|up-vg-setup|down-vg-setup]"
    fi

    case "$action" in
    up)
        create_mesh
        create_vnode "${MESH_DIR}/front-vn.json"
        create_vnode "${MESH_DIR}/color-vn.json"
        create_vservice "${MESH_DIR}/color-vs.json" "color.${PROJECT_NAME}.local"
        ;;
    down)
        delete_vservice "color.${PROJECT_NAME}.local"
        delete_vnode "color-node"
        delete_vnode "front-node"
        delete_mesh
        ;;
    up-vg-setup)
        create_mesh
        create_vnode "${MESH_DIR}/color-vn.json"
        create_vservice "${MESH_DIR}/color-vs.json" "color.${PROJECT_NAME}.local"
        create_vgateway "${MESH_DIR}/front-vg.json"
        create_gateway_route "${MESH_DIR}/front-gr.json" "color.${PROJECT_NAME}.local" "front-gr" "front-vg"
        ;;
    down-vg-setup)
        delete_gateway_route "front-vg" "front-gr"
        delete_vservice "color.${PROJECT_NAME}.local"
        delete_vnode "color-node"
        delete_vgateway "front-vg"
        delete_mesh
        ;;
    add-outlier-detection)
        update_vnode "${MESH_DIR}/color-vn-with-outlier-detection.json"
        ;;
    remove-outlier-detection)
        update_vnode "${MESH_DIR}/color-vn.json"
        ;;
    *)
        err "Invalid action specified: $action"
        ;;
    esac
}

main $@
