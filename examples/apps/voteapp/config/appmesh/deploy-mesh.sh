#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

shopt -s nullglob

required_env=(
    AWS_REGION
    ENVIRONMENT_NAME
)

suggested_env=(
    AWS_PROFILE
    KEY_PAIR_NAME
)

MESHNAME=default
AWS_PROFILE=${AWS_PROFILE:-"default"}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
SCRIPT="$( basename ${BASH_SOURCE[0]} )"

print() {
    printf "[APPMESH] %s\n" "$*"
}

err() {
    msg="Error: $1"
    print $msg
    code=${2:-"1"}
    exit $code
}

usage() {
    msg=$1
    [ -z "$msg" ] || printf "Error: $msg\n"
    printf "Usage: ${SCRIPT} <meshname>\n"
    exit 1
}

check_env() {
    for i in "${required_env[@]}"; do
        echo "$i=${!i}"
        [ -z "${!i}" ] && err "$i must be set"
    done
    for i in "${suggested_env[@]}"; do
        echo "$i=${!i}"
        [ -z "${!i}" ] && print "$i not set (using defaults)"
    done
}

check_args() {
    MESHNAME=$1
    [ -z "${MESHNAME}" ] && usage "missing argument: meshname"
}

sanity_check() {
    if [ "${AWS_REGION}" != "us-west-2" ]; then
        err "Only us-west-2 is supported at this time.  (Current default region: ${AWS_REGION})"
    fi
}

create_mesh() {
    print "Checking service mesh"
    arn=$(aws appmesh list-meshes --output=text --query 'meshes[?meshName==`'$MESHNAME'`]' | cut -f1)
    if [[ -n $arn ]]; then
        print $arn
        return
    fi
    print "Creating service mesh"
    cmd=( aws --region ${AWS_REGION} appmesh create-mesh --mesh-name ${MESHNAME} --query mesh.metadata.arn --output text )
    print "${cmd[@]}"
    arn=$("${cmd[@]}") || err "Unable to create service mesh" "$?"
    print "--> $arn"
}

create_virtual_node() {
    service=$1
    cmd=( aws --region ${AWS_REGION} appmesh create-virtual-node --mesh-name ${MESHNAME} --cli-input-json file:///${DIR}/config/virtualnodes/${service} --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create/update virtual node" "$?"
    print "--> ${uid}"
}

update_virtual_node() {
    service=$1
    cmd=( aws --region ${AWS_REGION} appmesh update-virtual-node --mesh-name ${MESHNAME} --cli-input-json file:///${DIR}/config/virtualnodes/${service} --query virtualNode.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}" 2>/dev/null) || create_virtual_node ${service}
    print "--> ${uid}"
}

configure_virtual_nodes() {
    print "Creating/updating virtual nodes"
    print "==============================="
    for service in $(ls ${DIR}/config/virtualnodes); do
        update_virtual_node ${service}
    done
}

create_virtual_router() {
    service=$1
    cmd=( aws --region ${AWS_REGION} appmesh create-virtual-router --mesh-name ${MESHNAME} --cli-input-json file:///${DIR}/config/virtualrouters/${service} --query virtualRouter.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create/update virtual router" "$?"
    print "--> ${uid}"
}

update_virtual_router() {
    service=$1
    cmd=( aws --region ${AWS_REGION} appmesh update-virtual-router --mesh-name ${MESHNAME} --cli-input-json file:///${DIR}/config/virtualrouters/${service} --query virtualRouter.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}" 2>/dev/null) || create_virtual_router ${service}
    print "--> ${uid}"
}

configure_virtual_routers() {
    print "Creating/updating virtual routers"
    print "================================="
    for service in $(ls ${DIR}/config/virtualrouters); do
        update_virtual_router ${service}
    done
}

create_route() {
    service=$1
    cmd=( aws --region ${AWS_REGION} appmesh create-route --mesh-name ${MESHNAME} --cli-input-json file:///${DIR}/config/routes/${service} --query route.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to create/update route" "$?"
    print "--> ${uid}"
}

update_route() {
    service=$1
    cmd=( aws --region ${AWS_REGION} appmesh update-route --mesh-name ${MESHNAME} --cli-input-json file:///${DIR}/config/routes/${service} --query route.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}" 2>/dev/null) || create_route ${service}
    print "--> ${uid}"
}

configure_routes() {
    print "Creating/updating routes"
    print "========================"
    for service in $(ls ${DIR}/config/routes); do
        update_route ${service}
    done
}

main() {
    # check_args $@
    check_env
    sanity_check
    create_mesh
    configure_virtual_nodes
    configure_virtual_routers
    configure_routes
}

main $@
