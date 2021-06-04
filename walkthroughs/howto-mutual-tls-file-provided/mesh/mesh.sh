#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

shopt -s nullglob
set -eo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
TEST_MESH_DIR="${DIR}"

print() {
    printf "[$(date)] : %s\n" "$*"
}

err() {
    msg="Error: $1"
    print "${msg}"
    code=${2:-"1"}
    exit ${code}
}

sanity_check() {
    if [ -z "${MESH_NAME}" ]; then
        err "MESH_NAME is not set"
    fi
}

appmesh_cmd="aws appmesh"

create_mesh() {
    spec_file=$1
    cmd=( $appmesh_cmd create-mesh --mesh-name "${MESH_NAME}" \
                ${PROFILE_OPT} \
                --cli-input-json "file:///${spec_file}" \
                --query mesh.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create mesh" "$?"
    print "--> ${uid}"
}

delete_mesh() {
    cmd=( $appmesh_cmd delete-mesh --mesh-name "${MESH_NAME}" \
                ${PROFILE_OPT} \
                --query mesh.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete mesh" "$?"
    print "--> ${uid}"
}

create_vnode() {
    spec_file=$1
    vnode_name=$2
    cli_input=$( jq -n \
        --arg SERVICES_DOMAIN $SERVICES_DOMAIN \
        -f "$spec_file" )
    cmd=( $appmesh_cmd create-virtual-node --mesh-name "${MESH_NAME}" \
                --virtual-node-name "${vnode_name}" \
                ${PROFILE_OPT} \
                --cli-input-json "$cli_input" \
                --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual node" "$?"
    print "--> ${uid}"
}

update_vnode() {
    spec_file=$1
    vnode_name=$2
    gateway_san=$3
    cli_input=$( jq -n \
        --arg SERVICES_DOMAIN $SERVICES_DOMAIN \
        --arg GATEWAY_SAN $gateway_san \
        -f "$spec_file" )
    cmd=( $appmesh_cmd update-virtual-node --mesh-name "${MESH_NAME}" \
                --virtual-node-name "${vnode_name}" \
                ${PROFILE_OPT} \
                --cli-input-json "$cli_input" \
                --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to update virtual node" "$?"
    print "--> ${uid}"
}

delete_vnode() {
    vnode_name=$1
    cmd=( $appmesh_cmd delete-virtual-node --mesh-name "${MESH_NAME}" \
                --virtual-node-name "${vnode_name}" \
                ${PROFILE_OPT} \
                --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual node" "$?"
    print "--> ${uid}"
}

create_vgateway() {
    spec_file=$1
    gateway_name=$2
    cli_input=$( jq -n \
        -f "$spec_file" )
    cmd=( $appmesh_cmd create-virtual-gateway --mesh-name "${MESH_NAME}" \
                --virtual-gateway-name "${gateway_name}" \
                ${PROFILE_OPT} \
                --cli-input-json "$cli_input" \
                --query virtualGateway.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual gateway" "$?"
    print "--> ${uid}"
}

update_vgateway() {
    spec_file=$1
    gateway_name=$2
    backend_san=$3
    cli_input=$( jq -n \
        --arg COLOR_TELLER_SAN $backend_san \
        -f "$spec_file" )
    cmd=( $appmesh_cmd update-virtual-gateway --mesh-name "${MESH_NAME}" \
                --virtual-gateway-name "${gateway_name}" \
                ${PROFILE_OPT} \
                --cli-input-json "$cli_input" \
                --query virtualGateway.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to update virtual gateway" "$?"
    print "--> ${uid}"
}

delete_vgateway() {
    gateway_name=$1
    cmd=( $appmesh_cmd delete-virtual-gateway --mesh-name "${MESH_NAME}" \
                --virtual-gateway-name "${gateway_name}" \
                ${PROFILE_OPT} \
                --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual gateway" "$?"
    print "--> ${uid}"
}

create_gwroute() {
    spec_file=$1
    route_name=$2
    gateway_name=$3
    vservice_name=$4
    cli_input=$( jq -n \
        --arg VIRTUAL_SERVICE $vservice_name \
        -f "$spec_file" )
    cmd=( $appmesh_cmd create-gateway-route --mesh-name "${MESH_NAME}" \
                --gateway-route-name "${route_name}" \
                --virtual-gateway-name "${gateway_name}" \
                ${PROFILE_OPT} \
                --cli-input-json "$cli_input" \
                --query gatewayRoute.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual gateway" "$?"
    print "--> ${uid}"
}

update_gwroute() {
    spec_file=$1
    route_name=$2
    gateway_name=$3
    cli_input=$( jq -n \
        --arg VIRTUAL_SERVICE $service_name \
        -f "$spec_file" )
    cmd=( $appmesh_cmd update-gateway-route --mesh-name "${MESH_NAME}" \
                --gateway-route-name "${route_name}" \
                --virtual-gateway-name "${gateway_name}" \
                ${PROFILE_OPT} \
                --cli-input-json "$cli_input" \
                --query gatewayRoute.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to update virtual gateway" "$?"
    print "--> ${uid}"
}

delete_gwroute() {
    route_name=$1
    gateway_name=$2
    cmd=( $appmesh_cmd delete-gateway-route --mesh-name "${MESH_NAME}" \
                --virtual-gateway-name "${gateway_name}" \
                --gateway-route-name "${route_name}" \
                ${PROFILE_OPT} \
                --query gatewayRoute.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual gateway" "$?"
    print "--> ${uid}"
}

create_vservice() {
    spec_file=$1
    vservice_name=$2
    cmd=( $appmesh_cmd create-virtual-service --mesh-name "${MESH_NAME}" \
                --virtual-service-name "${vservice_name}" \
                ${PROFILE_OPT} \
                --cli-input-json "file:///${spec_file}" \
                --query virtualService.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual service" "$?"
    print "--> ${uid}"
}

delete_vservice() {
    vservice_name=$1
    cmd=( $appmesh_cmd delete-virtual-service --mesh-name "${MESH_NAME}" \
                --virtual-service-name "${vservice_name}" \
                ${PROFILE_OPT} \
                --query virtualService.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual service" "$?"
    print "--> ${uid}"
}

main() {
    action="$1"
    if [ -z "$action" ]; then
        echo "Usage:"
        echo "mesh.sh [up|down]"
    fi
    sanity_check

    case "$action" in
    up)
        create_mesh "${TEST_MESH_DIR}/mesh.json"
        create_vnode "${TEST_MESH_DIR}/colorteller-vn.json" "colorteller-vn"
        create_vservice "${TEST_MESH_DIR}/colorteller-vs.json" "colorteller.${SERVICES_DOMAIN}"
        create_vgateway "${TEST_MESH_DIR}/gateway-vgw.json" "gateway-vgw"
        create_gwroute "${TEST_MESH_DIR}/colorteller-gwroute.json" "colorteller-route" "gateway-vgw" "colorteller.${SERVICES_DOMAIN}"
        ;;
    down)
        delete_gwroute "colorteller-route" "gateway-vgw"
        delete_vgateway "gateway-vgw"
        delete_vservice "colorteller.${SERVICES_DOMAIN}"
        delete_vnode "colorteller-vn"
        delete_mesh
        ;;
    update_1_strict_tls)
        update_vnode "${TEST_MESH_DIR}/updates/colorteller-vn-strict-tls.json" "colorteller-vn" "gateway.$SERVICES_DOMAIN"
        ;;
    update_2_client_policy_bad_san)
        update_vgateway "${TEST_MESH_DIR}/updates/gateway-vgw-client-policy.json" "gateway-vgw" "bogus.$SERVICES_DOMAIN"
        ;;
    update_3_client_policy_good_san)
        update_vgateway "${TEST_MESH_DIR}/updates/gateway-vgw-client-policy.json" "gateway-vgw" "colorteller.$SERVICES_DOMAIN"
        ;;
    update_4_require_client_cert)
        update_vnode "${TEST_MESH_DIR}/updates/colorteller-vn-strict-validation.json" "colorteller-vn" "gateway.$SERVICES_DOMAIN"
        ;;
    update_5_client_cert)
        update_vgateway "${TEST_MESH_DIR}/updates/gateway-vgw-client-cert.json" "gateway-vgw" "colorteller.$SERVICES_DOMAIN"
        ;;
    *)
        err "Invalid action specified: $action"
        ;;
    esac
}

main $@
