#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


# $1= Certificate Name
removeSecret() {
    aws secretsmanager delete-secret --secret-id $1 --force-delete-without-recovery
}


main() {
    # Color Gateway
    removeSecret "ca_1_cert"
    removeSecret "ca_2_cert"
    removeSecret "ca_1_ca_2_bundle"
    # White Colorteller
    removeSecret "colorteller_white_cert"
    removeSecret "colorteller_white_key"
    removeSecret "colorteller_white_cert_chain"
    # Green Colorteller
    removeSecret "colorteller_green_cert"
    removeSecret "colorteller_green_key"
    removeSecret "colorteller_green_cert_chain"
    rm $DIR/*.pem
    rm $DIR/*.generated
}

main $@
