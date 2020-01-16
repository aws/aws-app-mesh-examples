#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


# $1= Certificate Name
deploySecret() {
    secret=`cat $DIR/$1.pem`
    aws secretsmanager create-secret --name $1 --secret-string "$secret"
}


main() {
    # Color Gateway
    deploySecret "ca_1_cert"
    deploySecret "ca_2_cert"
    deploySecret "ca_1_ca_2_bundle"
    # White Colorteller
    deploySecret "colorteller_white_cert"
    deploySecret "colorteller_white_key"
    deploySecret "colorteller_white_cert_chain"
    # Green Colorteller
    deploySecret "colorteller_green_cert"
    deploySecret "colorteller_green_key"
    deploySecret "colorteller_green_cert_chain"
}

main $@
