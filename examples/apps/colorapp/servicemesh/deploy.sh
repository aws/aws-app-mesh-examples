#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

shopt -s nullglob

# Optional pre-load script
if [ -f meshvars.sh ]; then
    source meshvars.sh
fi

# Only us-west-2 is supported right now.
: ${AWS_DEFAULT_REGION:=us-west-2}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

print() {
    printf "[MESH] [$(date)] : %s\n" "$*"
}

err() {
    msg="Error: $1"
    print ${msg}
    code=${2:-"1"}
    exit ${code}
}

sanity_check() {
    if [ "${AWS_DEFAULT_REGION}" != "us-west-2" ]; then
        err "Only us-west-2 is supported at this time.  (Current default region: ${AWS_DEFAULT_REGION})"
    fi

    if [ -z ${MESH_NAME} ]; then
        err "MESH_NAME is not set"
    fi

    if [ -z ${APPMESH_FRONTEND} ]; then
        err "APPMESH_FRONTEND is not set"
    fi
}

update_virtual_node() {
    cli_input=$1
    cmd=( aws --endpoint-url ${APPMESH_FRONTEND} appmesh update-virtual-node \
              --mesh-name ${MESH_NAME} \
              --cli-input-json "${cli_input}" \
              --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || create_virtual_node "${cli_input}"
    print "--> ${uid}"
}

create_virtual_node() {
    cli_input=$1
    cmd=( aws --endpoint-url ${APPMESH_FRONTEND} appmesh create-virtual-node \
              --mesh-name ${MESH_NAME} \
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
    cmd=( aws --endpoint-url ${APPMESH_FRONTEND} appmesh create-virtual-router \
              --mesh-name ${MESH_NAME} \
              --cli-input-json "${cli_input}" \
              --query virtualRouter.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to save virtual router" "$?"
    print "--> ${uid}"
}

update_virtual_router() {
    cli_input=$1
    cmd=( aws --endpoint-url ${APPMESH_FRONTEND} appmesh update-virtual-router \
              --mesh-name ${MESH_NAME} \
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
    cmd=( aws --endpoint-url ${APPMESH_FRONTEND} appmesh create-route \
              --mesh-name ${MESH_NAME} \
              --cli-input-json "${cli_input}" \
              --query route.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to save route" "$?"
    print "--> ${uid}"
}

update_route() {
    cli_input=$1
    cmd=( aws --endpoint-url ${APPMESH_FRONTEND} appmesh update-route \
              --mesh-name ${MESH_NAME} \
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
