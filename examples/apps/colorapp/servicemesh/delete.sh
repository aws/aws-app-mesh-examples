#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

shopt -s nullglob

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

source $DIR/.region-config.sh

: ${AWS_DEFAULT_REGION:=$DEFAULT_REGION}

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

    if [ -z ${ENVIRONMENT_NAME} ]; then
        err "ENVIRONMENT_NAME is not set"
    fi

    if [ -z ${MESH_NAME} ]; then
        err "MESH_NAME is not set"
    fi
}

delete_route() {
    route_name=$1
    virtual_router_name=$2
    aws appmesh delete-route \
        --mesh-name ${MESH_NAME} \
        --virtual-router-name ${virtual_router_name} \
        --route-name ${route_name} || print "Unable to delete route $route_name under virtual-router $virtual_router_name" "$?"
}

delete_virtual_router() {
    virtual_router_name=$1
    print "Deleting virtual-router ${virtual_router_name}"
    aws appmesh delete-virtual-router \
        --mesh-name ${MESH_NAME} \
        --virtual-router-name ${virtual_router_name} || print "Unable to delete virtual-router $virtual_router_name" "$?"
}

delete_virtual_node() {
    virtual_node_name=$1
    print "Deleting virutal-node ${virtual_node_name}"
    aws appmesh delete-virtual-node \
        --mesh-name ${MESH_NAME} \
        --virtual-node-name ${virtual_node_name} || print "Unable to delete virtual-node $virtual_node_name" "$?"
}

main() {
    sanity_check

    #delete routes
    for f in $(ls "${DIR}/config/routes/")
    do
        pieces=($(cat ${DIR}/config/routes/${f} | jq -r ".routeName,.virtualRouterName"))
        delete_route "${pieces[0]}" "${pieces[1]}"
    done
    for f in $(ls "${DIR}/config/update_routes/")
    do
        pieces=($(cat ${DIR}/config/update_routes/${f} | jq -r ".routeName,.virtualRouterName"))
        delete_route "${pieces[0]}" "${pieces[1]}"
    done

    #delete virtual-routers
    for f in $(ls "${DIR}/config/virtualrouters/")
    do
        virtual_router_name=$(cat ${DIR}/config/virtualrouters/${f} | jq -r ".virtualRouterName")
        delete_virtual_router "${virtual_router_name}"
    done

    #delete virtual-nodes
    for f in $(ls "${DIR}/config/virtualnodes/")
    do
        virtual_node_name=$(cat ${DIR}/config/virtualnodes/${f} | jq -r ".virtualNodeName")
        delete_virtual_node "${virtual_node_name}"
    done

}

main
