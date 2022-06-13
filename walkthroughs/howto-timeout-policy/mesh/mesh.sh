#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

shopt -s nullglob

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
    dns_hostname="$3.${SERVICES_DOMAIN}"
    cli_input=$( jq -n \
        --arg ROOT_CA_ARN "${ROOT_CA_ARN}" \
        --arg CERTIFICATE_ARN "${CERTIFICATE_ARN}" \
        --arg DNS_HOSTNAME "$3.${SERVICES_DOMAIN}" \
        --arg COLOR_TELLER_VS "colorteller.${SERVICES_DOMAIN}" \
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
    dns_hostname="$3.${SERVICES_DOMAIN}"
    cli_input=$( jq -n \
        --arg ROOT_CA_ARN "${ROOT_CA_ARN}" \
        --arg CERTIFICATE_ARN "${CERTIFICATE_ARN}" \
        --arg DNS_HOSTNAME "$3.${SERVICES_DOMAIN}" \
        --arg COLOR_TELLER_VS "colorteller.${SERVICES_DOMAIN}" \
        -f "$spec_file" )
    cmd=( $appmesh_cmd update-virtual-node --mesh-name "${MESH_NAME}" \
                --virtual-node-name "${vnode_name}" \
                ${PROFILE_OPT} \
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
                ${PROFILE_OPT} \
                --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual node" "$?"
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

create_vrouter() {
    spec_file=$1
    vrouter_name=$2
    cmd=( $appmesh_cmd create-virtual-router --mesh-name "${MESH_NAME}" \
                --virtual-router-name "${vrouter_name}" \
                ${PROFILE_OPT} \
                --cli-input-json "file:///${spec_file}" \
                --query virtualRouter.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual router" "$?"
    print "--> ${uid}"
}

delete_vrouter() {
    vrouter_name=$1
    cmd=( $appmesh_cmd delete-virtual-router --mesh-name "${MESH_NAME}" \
                --virtual-router-name "${vrouter_name}" \
                ${PROFILE_OPT} \
                --query virtualRouter.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual router" "$?"
    print "--> ${uid}"
}

create_route() {
    spec_file=$1
    vrouter_name=$2
    route_name=$3
    cmd=( $appmesh_cmd create-route --mesh-name "${MESH_NAME}" \
                --virtual-router-name "${vrouter_name}" \
                --route-name "${route_name}" \
                ${PROFILE_OPT} \
                --cli-input-json "file:///${spec_file}" \
                --query route.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create route" "$?"
    print "--> ${uid}"
}

delete_route() {
    vrouter_name=$1
    route_name=$2
    cmd=( $appmesh_cmd delete-route --mesh-name "${MESH_NAME}" \
                --virtual-router-name "${vrouter_name}" \
                --route-name "${route_name}" \
                ${PROFILE_OPT} \
                --query route.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete route" "$?"
    print "--> ${uid}"
}

create_vgateway() {
    spec_file=$1
    vgateway_name=$2
    cli_input=$( jq -n \
    --arg CERTIFICATE_ARN "${CERTIFICATE_ARN}" \
    -f "$spec_file" )
    cmd=( $appmesh_cmd create-virtual-gateway \
                --mesh-name "${MESH_NAME}" \
                --virtual-gateway-name "${vgateway_name}" \
                --cli-input-json "$cli_input" \
                --query virtualGateway.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual gateway" "$?"
    print "--> ${uid}"
}

delete_vgateway() {
    vgateway_name=$1
    cmd=( $appmesh_cmd delete-virtual-gateway \
                --mesh-name "${MESH_NAME}" \
                --virtual-gateway-name "${vgateway_name}" \
                --query virtualGateway.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual gateway" "$?"
    print "--> ${uid}"
}

create_gateway_route() {
    spec_file=$1
    vgateway_name=$2
    gatewayroute_name=$3
    cli_input=$( jq -n \
        --arg VIRTUALSERVICE_NAME "$4" \
        -f "$spec_file" )
    cmd=( $appmesh_cmd create-gateway-route \
                --mesh-name "${MESH_NAME}" \
                --virtual-gateway-name "${vgateway_name}" \
                --gateway-route-name "${gatewayroute_name}" \
                --cli-input-json "$cli_input" \
                --query gatewayRoute.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create gateway route" "$?"
    print "--> ${uid}"
}

delete_gateway_route() {
    vgateway_name=$1
    gatewayroute_name=$2
    cmd=( $appmesh_cmd delete-gateway-route \
                --mesh-name "${MESH_NAME}" \
                --virtual-gateway-name "${vgateway_name}" \
                --gateway-route-name "${gatewayroute_name}" \
                --query gatewayRoute.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete gateway route" "$?"
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
        create_vnode "${TEST_MESH_DIR}/colorgateway-vn.json" "ColorGateway" "colorgateway"
        create_vnode "${TEST_MESH_DIR}/colorteller-vn.json" "ColorTellerWhite" "colorteller"

        create_vrouter "${TEST_MESH_DIR}/colorteller-vr.json" "colorteller-vr"
        create_route "${TEST_MESH_DIR}/colorteller-route.json" "colorteller-vr" "colorteller-route"
        create_vservice "${TEST_MESH_DIR}/colorteller-vs.json" "colorteller.${SERVICES_DOMAIN}"

        ;;
    down)
        delete_vservice "colorteller.${SERVICES_DOMAIN}"
        delete_route "colorteller-vr" "colorteller-route"
        delete_vrouter "colorteller-vr"
        delete_vnode "ColorGateway"
        delete_vnode "ColorTellerWhite"
        delete_mesh
        ;;
    add_virtual_gateway)
        create_vgateway "${TEST_MESH_DIR}/publicgateway-vg.json" "publicgateway-vg"
        create_gateway_route "${TEST_MESH_DIR}/publicgateway-route.json" "publicgateway-vg" "publicgateway-route" "colorteller.${SERVICES_DOMAIN}"   
        ;;
    add_red_node_and_routes)
        create_vnode "${TEST_MESH_DIR}/colorteller-vn.json" "ColorTellerRed" "colorteller-red"
        delete_route "colorteller-vr" "colorteller-route"
        create_route "${TEST_MESH_DIR}/colorteller-route1.json" "colorteller-vr" "colorteller-route"
        create_route "${TEST_MESH_DIR}/colorteller-route2.json" "colorteller-vr" "colorteller-route2"       
        ;;
    delete_virtual_gateway_and_red_node_and_routes)
        delete_gateway_route "publicgateway-vg" "publicgateway-route"
        delete_vgateway "publicgateway-vg"
        delete_route "colorteller-vr" "colorteller-route2"
        delete_vnode "ColorTellerRed"
        ;;
    update_colorteller-white-vn)
        update_vnode "$2" "ColorTellerWhite" "colorteller"
        ;;
    update_colorteller-red-vn)
        update_vnode "$2" "ColorTellerRed" "colorteller-red"
        ;;
    update_colorgateway-vn)
        update_vnode "$2" "ColorGateway" "colorgateway"
        ;;
    *)
        err "Invalid action specified: $action"
        ;;
    esac
}

main $@
