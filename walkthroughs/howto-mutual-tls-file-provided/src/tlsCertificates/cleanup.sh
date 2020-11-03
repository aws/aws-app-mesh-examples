#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


# $1= Certificate Name
removeSecret() {
    aws secretsmanager delete-secret --secret-id $1 --force-delete-without-recovery
}


removeSecret "ca_cert"
removeSecret "gateway_cert"
removeSecret "gateway_key"
removeSecret "gateway_cert_chain"
removeSecret "colorteller_cert"
removeSecret "colorteller_key"
removeSecret "colorteller_cert_chain"
rm $DIR/*.pem
rm $DIR/*.generated
