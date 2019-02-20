#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

required_env=(
    AWS_REGION
    ENVIRONMENT_NAME
)

ACTION=${1:-"deploy"}
AWS_PROFILE=${AWS_PROFILE:-"default"}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
SCRIPT="$(basename ${BASH_SOURCE[0]})"

print() {
    printf "[${SCRIPT}] %s\n" "$*"
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
    printf "Usage: ${SCRIPT} <action>\n"
    exit 1
}

check_env() {
    for i in "${required_env[@]}"; do
        echo "$i=${!i}"
        [ -z "${!i}" ] && err "$i must be set"
    done
}

deploy() {
    echo "${ACTION}.."
    aws --profile ${AWS_PROFILE} --region ${AWS_REGION} \
        cloudformation ${ACTION} \
        --stack-name ${ENVIRONMENT_NAME}-vpc \
        --template-file ${DIR}/vpc.yaml \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "EnvironmentName=${ENVIRONMENT_NAME}"
}

main() {
    check_env
    deploy
}

main $@
