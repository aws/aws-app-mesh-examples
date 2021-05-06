#!/bin/bash

set -xe

PASSPHRASE=`echo $CertSecret|jq -r '.Passphrase'`
PASSPHRASE_B64=`echo -n $PASSPHRASE | base64`


# -------- CollorGateway Cert ----------
echo $CertSecret|jq -r '.GatewayCertificate' > /keys/colorgateway_endpoint_cert.pem
echo $CertSecret|jq -r '.GatewayCertificateChain' > /keys/colorgateway_root_cert.pem
echo $CertSecret|jq -r '.GatewayPrivateKey' > /keys/colorgateway_endpoint_enc_pri_key.pem 

cat /keys/colorgateway_endpoint_cert.pem /keys/colorgateway_root_cert.pem > /keys/colorgateway_endpoint_cert_chain.pem
openssl rsa -in /keys/colorgateway_endpoint_enc_pri_key.pem -out /keys/colorgateway_endpoint_dec_pri_key.pem -passin pass:$PASSPHRASE_B64
openssl rsa -in /keys/colorgateway_endpoint_dec_pri_key.pem -check

# Clear environment of secret values
unset CertSecret
unset PASSPHRASE
unset PASSPHRASE_B64

# Start Envoy
/usr/bin/envoy-wrapper
