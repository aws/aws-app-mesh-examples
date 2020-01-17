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

appmesh_cmd="aws appmesh-preview"

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

update_route() {
    spec_file=$1
    vrouter_name=$2
    route_name=$3
    cmd=( $appmesh_cmd update-route --mesh-name "${MESH_NAME}" \
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
        create_vnode "${TEST_MESH_DIR}/colorgateway-vn.json" "colorgateway-vn" "colorgateway"
        create_vnode "${TEST_MESH_DIR}/colorteller-white-vn.json" "colorteller-white-vn" "colorteller"
        create_vrouter "${TEST_MESH_DIR}/colorteller-vr.json" "colorteller-vr"
        create_route "${TEST_MESH_DIR}/colorteller-route.json" "colorteller-vr" "colorteller-route"
        create_vservice "${TEST_MESH_DIR}/colorteller-vs.json" "colorteller.${SERVICES_DOMAIN}"
        create_vnode "${TEST_MESH_DIR}/colortellerGreen/colorteller-green-vn.json" "colorteller-green-vn" "colorteller-green"
        ;;
    down)
        delete_vservice "colorteller.${SERVICES_DOMAIN}"
        delete_route "colorteller-vr" "colorteller-route"
        delete_vrouter "colorteller-vr"
        delete_vnode "colorgateway-vn"
        delete_vnode "colorteller-white-vn"
        delete_vnode "colorteller-green-vn"
        delete_mesh
        ;;
    addGreen)
        update_route "${TEST_MESH_DIR}/colortellerGreen/colorteller-updated-route.json" "colorteller-vr" "colorteller-route"
        ;;
    updateGateway)
        update_vnode "${TEST_MESH_DIR}/colorGatewayValidation/colorgateway-vn-update_1.json" "colorgateway-vn" "colorgateway"
        ;;
    updateGateway2)
        update_vnode "${TEST_MESH_DIR}/colorGatewayValidation/colorgateway-vn-update_2.json" "colorgateway-vn" "colorgateway"
        ;;    
    *)
        err "Invalid action specified: $action"
        ;;
    esac
}

main $@
