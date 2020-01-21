#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

shopt -s nullglob
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )" TEST_MESH_DIR="${DIR}"

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
    if [ -z "${PROJECT_NAME}" ]; then
        err "PROJECT_NAME is not set"
    fi

    if [ -z "${AWS_SECONDARY_PROFILE}" ]; then
        err "AWS_SECONDARY_PROFILE is not set"
    fi

    if [ -z "${AWS_PRIMARY_ACCOUNT_ID}" ]; then
        err "AWS_PRIMARY_ACCOUNT_ID is not set"
    fi
}

appmesh_cmd="aws appmesh-preview"

create_mesh() {
    spec_file=$1
    cmd=( $appmesh_cmd create-mesh --mesh-name "${PROJECT_NAME}-mesh" \
                --mesh-owner ${AWS_PRIMARY_ACCOUNT_ID}
                --profile ${AWS_SECONDARY_PROFILE} \
                --cli-input-json "file:///${spec_file}" \
                --query mesh.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create mesh" "$?"
    print "--> ${uid}"
}

delete_mesh() {
    cmd=( $appmesh_cmd delete-mesh --mesh-name "${PROJECT_NAME}-mesh" \
                --mesh-owner ${AWS_PRIMARY_ACCOUNT_ID}
                --profile ${AWS_SECONDARY_PROFILE} \
                --query mesh.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete mesh" "$?"
    print "--> ${uid}"
}

create_vnode() {
    spec_file=$1
    vnode_name=$2
    cli_input=$( jq -n \
        --arg PROJECT_NAME "${PROJECT_NAME}" \
        -f "$spec_file" )
    cmd=( $appmesh_cmd create-virtual-node --mesh-name "${PROJECT_NAME}-mesh" \
                --virtual-node-name "${vnode_name}" \
                --mesh-owner ${AWS_PRIMARY_ACCOUNT_ID}
                --profile ${AWS_SECONDARY_PROFILE} \
                --cli-input-json "$cli_input" \
                --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual node" "$?"
    print "--> ${uid}"
}

delete_vnode() {
    vnode_name=$1
    cmd=( $appmesh_cmd delete-virtual-node --mesh-name "${PROJECT_NAME}-mesh" \
                --virtual-node-name "${vnode_name}" \
                --mesh-owner ${AWS_PRIMARY_ACCOUNT_ID}
                --profile ${AWS_SECONDARY_PROFILE} \
                --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual node" "$?"
    print "--> ${uid}"
}

create_vservice() {
    spec_file=$1
    vservice_name=$2
    cmd=( $appmesh_cmd create-virtual-service --mesh-name "${PROJECT_NAME}-mesh" \
                --virtual-service-name "${vservice_name}" \
                --mesh-owner ${AWS_PRIMARY_ACCOUNT_ID}
                --profile ${AWS_SECONDARY_PROFILE} \
                --cli-input-json "file:///${spec_file}" \
                --query virtualService.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual service" "$?"
    print "--> ${uid}"
}

delete_vservice() {
    vservice_name=$1
    cmd=( $appmesh_cmd delete-virtual-service --mesh-name "${PROJECT_NAME}-mesh" \
                --virtual-service-name "${vservice_name}" \
                --mesh-owner ${AWS_PRIMARY_ACCOUNT_ID}
                --profile ${AWS_SECONDARY_PROFILE} \
                --query virtualService.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual service" "$?"
    print "--> ${uid}"
}

create_vrouter() {
    spec_file=$1
    vrouter_name=$2
    cmd=( $appmesh_cmd create-virtual-router --mesh-name "${PROJECT_NAME}-mesh" \
                --virtual-router-name "${vrouter_name}" \
                --mesh-owner ${AWS_PRIMARY_ACCOUNT_ID}
                --profile ${AWS_SECONDARY_PROFILE} \
                --cli-input-json "file:///${spec_file}" \
                --query virtualRouter.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create virtual router" "$?"
    print "--> ${uid}"
}

delete_vrouter() {
    vrouter_name=$1
    cmd=( $appmesh_cmd delete-virtual-router --mesh-name "${PROJECT_NAME}-mesh" \
                --virtual-router-name "${vrouter_name}" \
                --mesh-owner ${AWS_PRIMARY_ACCOUNT_ID}
                --profile ${AWS_SECONDARY_PROFILE} \
                --query virtualRouter.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to delete virtual router" "$?"
    print "--> ${uid}"
}

create_route() {
    spec_file=$1
    vrouter_name=$2
    route_name=$3
    cmd=( $appmesh_cmd create-route --mesh-name "${PROJECT_NAME}-mesh" \
                --virtual-router-name "${vrouter_name}" \
                --route-name "${route_name}" \
                --mesh-owner ${AWS_PRIMARY_ACCOUNT_ID}
                --profile ${AWS_SECONDARY_PROFILE} \
                --cli-input-json "file:///${spec_file}" \
                --query route.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create route" "$?"
    print "--> ${uid}"
}

delete_route() {
    vrouter_name=$1
    route_name=$2
    cmd=( $appmesh_cmd delete-route --mesh-name "${PROJECT_NAME}-mesh" \
                --virtual-router-name "${vrouter_name}" \
                --route-name "${route_name}" \
                --mesh-owner ${AWS_PRIMARY_ACCOUNT_ID}
				    --profile ${AWS_SECONDARY_PROFILE}
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
        create_vnode "${TEST_MESH_DIR}/backend-2-vn.json" "backend-2-vn"
        ;;
    down)
        delete_vnode "backend-2-vn"
        ;;
    *)
        err "Invalid action specified: $action"
        ;;
    esac
}

main $@
