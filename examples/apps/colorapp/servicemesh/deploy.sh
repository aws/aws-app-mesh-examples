#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

shopt -s nullglob

# Optional pre-load script
if [ -f meshvars.sh ]; then
    source meshvars.sh
fi

if [ ! -z "$AWS_PROFILE" ]; then
    PROFILE_OPT="--profile ${AWS_PROFILE}"
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

source $DIR/.region-config.sh

: ${AWS_DEFAULT_REGION:=$DEFAULT_REGION}

if [ "$APPMESH_ENDPOINT" = "" ]; then
    appmesh_cmd="aws appmesh"
else
    appmesh_cmd="aws --endpoint-url "${APPMESH_ENDPOINT}" appmesh"
fi

print() {
    printf "[MESH] [$(date)] : %s\n" "$*"
}

err() {
    msg="Error: $1"
    print ${msg}
    code=${2:-"1"}
    exit ${code}
}

contains() {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

sanity_check() {
    if ! contains "${AWS_DEFAULT_REGION}" "${SUPPORTED_REGIONS[@]}"; then
        err "Region ${AWS_DEFAULT_REGION} is not supported at this time (Supported regions: ${SUPPORTED_REGIONS[*]})"
    fi

    if [ -z "${MESH_NAME}" ]; then
        err "MESH_NAME is not set"
    fi
}

update_virtual_node() {
    cli_input=$1
    cmd=( $appmesh_cmd update-virtual-node \
              ${PROFILE_OPT} \
              --mesh-name "${MESH_NAME}" \
              --cli-input-json "${cli_input}" \
              --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || create_virtual_node "${cli_input}"
    print "--> ${uid}"
}

create_virtual_node() {
    cli_input=$1
    cmd=( $appmesh_cmd create-virtual-node \
              ${PROFILE_OPT} \
              --mesh-name "${MESH_NAME}" \
              --cli-input-json "${cli_input}" \
              --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to save virtual node" "$?"
    print "--> ${uid}"
}

save_virtual_nodes() {
    print "Creating virtual nodes"
    print "======================"
    for service in $(ls ${DIR}/config/virtualnodes); do
      cli_input=$(cat ${DIR}/config/virtualnodes/${service} | sed "s/@@SERVICES_DOMAIN@@/.${SERVICES_DOMAIN}/g")
      print "cli_input=${cli_input}"
      update_virtual_node "${cli_input}"
    done
}

create_virtual_router() {
    cli_input=$1
    cmd=( $appmesh_cmd create-virtual-router \
              ${PROFILE_OPT} \
              --mesh-name "${MESH_NAME}" \
              --cli-input-json "${cli_input}" \
              --query virtualRouter.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to save virtual router" "$?"
    print "--> ${uid}"
}

update_virtual_router() {
    cli_input=$1
    cmd=( $appmesh_cmd update-virtual-router \
              ${PROFILE_OPT} \
              --mesh-name "${MESH_NAME}" \
              --cli-input-json "${cli_input}" \
              --query virtualRouter.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || create_virtual_router "${cli_input}"
    print "--> ${uid}"
}

save_virtual_routers() {
    print "Creating virtual routers"
    print "========================"
    for service in $(ls ${DIR}/config/virtualrouters); do
      cli_input=$(cat ${DIR}/config/virtualrouters/${service} | sed "s/@@SERVICES_DOMAIN@@/.${SERVICES_DOMAIN}/g")
      update_virtual_router "${cli_input}"
    done
}

create_route() {
    cli_input=$1
    cmd=( $appmesh_cmd create-route \
              ${PROFILE_OPT} \
              --mesh-name "${MESH_NAME}" \
              --cli-input-json "${cli_input}" \
              --query route.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to save route" "$?"
    print "--> ${uid}"
}

update_route() {
    cli_input=$1
    cmd=( $appmesh_cmd update-route \
              ${PROFILE_OPT} \
              --mesh-name "${MESH_NAME}" \
              --cli-input-json "${cli_input}" \
              --query route.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || create_route "${cli_input}"
    print "--> ${uid}"
}

save_routes() {
    print "Saving routes"
    print "======================="
    for service in $(ls ${DIR}/config/routes); do
      cli_input=$(cat ${DIR}/config/routes/${service})
      update_route "${cli_input}"
    done
}

main() {
    sanity_check
    save_virtual_nodes
    save_virtual_routers
    save_routes
}

main
