#!/bin/bash

set -e

deploySpire() {
    kubectl apply -f spire/spire_setup.yaml
}

echo "Installing SPIRE Server and Agent"
deploySpire
