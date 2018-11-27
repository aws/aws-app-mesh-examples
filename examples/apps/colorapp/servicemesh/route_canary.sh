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
UPDATE_ROUTES_DIR="${DIR}/config/update_routes/"

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

    if [ -z ${ENVIRONMENT_NAME} ]; then
        err "ENVIRONMENT_NAME is not set"
    fi

    if [ -z ${MESH_NAME} ]; then
        err "MESH_NAME is not set"
    fi

    if [ -z ${APPMESH_FRONTEND} ]; then
        err "APPMESH_FRONTEND is not set"
    fi
}

update_route() {
    route_spec_file=$1
    cmd=( aws --endpoint-url ${APPMESH_FRONTEND} appmesh update-route --mesh-name ${MESH_NAME} \
                #--client-token "${service}-${RANDOM}" \
                --cli-input-json file:///${route_spec_file} \
                --query route.metadata.uid --output text )
    print "${cmd[@]}"
    uid=$("${cmd[@]}") || err "Unable to update route" "$?"
    print "--> ${uid}"
}

main() {
    sanity_check
    files=($(ls "${UPDATE_ROUTES_DIR}"))
    while true; do \
        f=${files[$RANDOM % ${#files[@]}]}
        print "Using route in file ${f}"
        update_route "${UPDATE_ROUTES_DIR}/${f}"
        sleep ${SLEEP_TIME:-"600s"}
    done
}

main
