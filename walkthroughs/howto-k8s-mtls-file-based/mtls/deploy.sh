#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


# $1=Certificate Name; $2=AppCert/Private Key; $3=CA Cert Name
deployAppSecret() {
    echo $1
    kubectl create -n howto-k8s-mtls-file-based secret generic $1-tls --from-file=$DIR/$2_key.pem --from-file=$DIR/$2_cert_chain.pem --from-file=$DIR/$3.pem
}


#deployGenericSecret() {
#    kubectl create -n howto-k8s-mtls-file-based secret generic $1 --from-file=$DIR/$2
#}

main() {

    kubectl create ns howto-k8s-mtls-file-based
    # Front App
    deployAppSecret "front-ca1" "front" "ca_1_cert"
    deployAppSecret "front-ca1-ca2" "front" "ca_1_ca_2_bundle"
    # Blue Color App
    deployAppSecret "colorapp-blue" "colorapp-blue" "ca_1_cert"
    # Green Color App
    deployAppSecret "colorapp-green" "colorapp-green" "ca_1_cert"

   #deployGenericSecret ca1-ca2-bundle-tls ca_1_ca_2_bundle.pem
   #deployGenericSecret ca1-cert-tls ca_1_cert.pem 
}

main $@
