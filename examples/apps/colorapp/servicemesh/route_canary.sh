#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

shopt -s nullglob

# Optional pre-load script
if [ -f meshvars.sh ]; then
    source meshvars.sh
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
UPDATE_ROUTES_DIR="${DIR}/config/update_routes/"

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

sanity_check() {
    if [ ! -n "${SUPPORTED_REGIONS[$AWS_DEFAULT_REGION]}" ]; then
        err "Region ${AWS_DEFAULT_REGION} is not supported at this time (Supported regions: ${!SUPPORTED_REGIONS[*]})"
    fi

    if [ -z ${ENVIRONMENT_NAME} ]; then
        err "ENVIRONMENT_NAME is not set"
    fi

    if [ -z ${MESH_NAME} ]; then
        err "MESH_NAME is not set"
    fi
}

update_route() {
    route_spec_file=$1
    cmd=( aws appmesh update-route --mesh-name ${MESH_NAME} \
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
