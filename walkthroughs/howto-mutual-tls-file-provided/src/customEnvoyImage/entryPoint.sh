#!/bin/bash

# $1=Secret Name
getSecret() {
    aws secretsmanager get-secret-value --secret-id $1 | jq -r .SecretString > /keys/${1}.pem
    echo "Added $1 to container"
}

getCertificates() {
    if [[ $CERTIFICATE_NAME = "gateway" ]];
    then
        getSecret "ca_cert"
        getSecret "gateway_key"
        getSecret "gateway_cert_chain"
    fi
    if [[ $CERTIFICATE_NAME = "colorteller" ]];
    then
        getSecret "colorteller_key"
        getSecret "colorteller_cert_chain"
        getSecret "ca_cert"
    fi
}

# Get the appropriate certificates
getCertificates
# Start Envoy
/usr/bin/envoy-wrapper
