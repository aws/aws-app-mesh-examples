#!/bin/bash

# $1=Secret Name
getSecret() {
    aws secretsmanager get-secret-value --secret-id $1 | jq -r .SecretString > /keys/${1}.pem
    echo "Added $1 to container"
}

getCertificates() {
    if [[ $CERTIFICATE_NAME = "colorgateway" ]];
    then
        getSecret "ca_1_cert"
        getSecret "ca_2_cert"
        getSecret "ca_1_ca_2_bundle"
    fi
    if [[ $CERTIFICATE_NAME = "colorteller_green" ]];
    then
        getSecret "colorteller_green_cert"
        getSecret "colorteller_green_key"
        getSecret "colorteller_green_cert_chain"
    fi
    if [[ $CERTIFICATE_NAME = "colorteller_white" ]];
    then
        getSecret "colorteller_white_cert"
        getSecret "colorteller_white_key"
        getSecret "colorteller_white_cert_chain"
    fi
}

# Get the appropriate certificates
getCertificates
# Start Envoy
/usr/bin/envoy-wrapper
