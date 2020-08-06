#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


# $1= Certificate Name
deployAppSecret() {
    echo $1
    kubectl create -n howto-k8s-tls-file-based secret generic $1-tls --from-file=$DIR/$1_key.pem --from-file=$DIR/$1_cert_chain.pem
}


deployGenericSecret() {
    kubectl create -n howto-k8s-tls-file-based secret generic $1 --from-file=$DIR/$2
}

main() {

    kubectl create ns howto-k8s-tls-file-based
    # Blue Color App
    deployAppSecret "colorapp-blue"
    # Green Color App
    deployAppSecret "colorapp-green"

    deployGenericSecret ca1-ca2-bundle-tls ca_1_ca_2_bundle.pem
    deployGenericSecret ca1-cert-tls ca_1_cert.pem 
}

main $@
