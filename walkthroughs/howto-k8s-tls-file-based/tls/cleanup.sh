#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


# $1= Certificate Name
removeSecret() {
    echo "Removing $1"
    kubectl delete secret $1 -n howto-k8s-tls-file-based
}


main() {
    rm $DIR/*.pem
    rm $DIR/*.generated

    # Blue Color App
    removeSecret "colorapp-blue-tls"
    # Green Color App
    removeSecret "colorapp-green-tls"
    # Remove CA1 CA2 certs
    removeSecret "ca1-ca2-bundle-tls"
    removeSecret "ca1-cert-tls"
}

main $@
