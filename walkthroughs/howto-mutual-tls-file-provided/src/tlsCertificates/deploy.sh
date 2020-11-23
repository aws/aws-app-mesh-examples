#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


# $1= Certificate Name
deploySecret() {
    secret=`cat $DIR/$1.pem`
    aws secretsmanager create-secret --name $1 --secret-string "$secret"
}


main() {
    deploySecret "ca_cert"
    # deploySecret "gateway_cert"
    deploySecret "gateway_key"
    deploySecret "gateway_cert_chain"
    # deploySecret "colorteller_cert"
    deploySecret "colorteller_key"
    deploySecret "colorteller_cert_chain"
}

main $@
