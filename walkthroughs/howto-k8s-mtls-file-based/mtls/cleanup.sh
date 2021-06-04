#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


# $1= Certificate Name
removeSecret() {
    echo "Removing $1"
    kubectl delete secret $1 -n howto-k8s-mtls-file-based
}


main() {
    rm $DIR/*.pem
    rm $DIR/*.generated

    # Front App
    removeSecret "front-ca1-tls"
    removeSecret "front-ca1-ca2-tls"
    # Blue Color App
    removeSecret "colorapp-blue-tls"
    # Green Color App
    removeSecret "colorapp-green-tls"
}

main $@
