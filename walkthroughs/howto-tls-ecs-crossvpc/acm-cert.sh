# Create the CA Cert
export ROOT_CA_ARN=`aws acm-pca create-certificate-authority --certificate-authority-type ROOT  --certificate-authority-configuration "KeyAlgorithm=RSA_2048,SigningAlgorithm=SHA256WITHRSA,Subject={Country=US,State=VA,Locality=Herndon,Organization=App Mesh Examples,OrganizationalUnit=TLS Example,CommonName=appmeshworkshop.hosted.local}" --query CertificateAuthorityArn --output text`
# Export the CSR
ROOT_CA_CSR=`aws acm-pca get-certificate-authority-csr  --certificate-authority-arn ${ROOT_CA_ARN}  --query Csr --output text`
# Self sigh the CSR
AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)
[[ ${AWS_CLI_VERSION} -gt 1 ]] && ROOT_CA_CSR="$(echo ${ROOT_CA_CSR} | base64)"
ROOT_CA_CERT_ARN=`aws acm-pca issue-certificate --certificate-authority-arn ${ROOT_CA_ARN} --template-arn arn:aws:acm-pca:::template/RootCACertificate/V1 --signing-algorithm SHA256WITHRSA --validity Value=10,Type=YEARS  --csr "${ROOT_CA_CSR}" --query CertificateArn --output text`
# Import the signed certificate as the root CA
ROOT_CA_CERT=`aws acm-pca get-certificate --certificate-arn ${ROOT_CA_CERT_ARN} --certificate-authority-arn ${ROOT_CA_ARN} --query Certificate --output text`
[[ ${AWS_CLI_VERSION} -gt 1 ]] && ROOT_CA_CERT="$(echo ${ROOT_CA_CERT} | base64)"
aws acm-pca import-certificate-authority-certificate --certificate-authority-arn $ROOT_CA_ARN --certificate "${ROOT_CA_CERT}"
# Grant permission to CA to automatically renew the managed certificate
aws acm-pca create-permission --certificate-authority-arn $ROOT_CA_ARN --actions IssueCertificate GetCertificate ListPermissions  --principal acm.amazonaws.com
# Request Managed certificate from ACM
export CERTIFICATE_ARN=`aws acm request-certificate  --domain-name "*.appmeshworkshop.hosted.local" --certificate-authority-arn ${ROOT_CA_ARN}    --query CertificateArn --output text`
