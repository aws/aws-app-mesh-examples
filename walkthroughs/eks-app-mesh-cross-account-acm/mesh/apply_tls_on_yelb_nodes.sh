#!/bin/bash

#CreateCA
export certificateAuthorityArn=$(aws acm-pca create-certificate-authority --certificate-authority-configuration file://ca_config.txt --revocation-configuration file://revoke_config.txt --certificate-authority-type "ROOT" --idempotency-token 98256344 --tags  Key=Name,Value=MyAppMeshPCA --profile frontend |jq -r '.CertificateAuthorityArn' )

sleep 0.5

export csr1=$(aws acm-pca get-certificate-authority-csr --certificate-authority-arn $certificateAuthorityArn --profile frontend |jq '.Csr')   

echo $csr1 > ca.csr
awk '{gsub(/\\n/,"\n")}1' ca.csr > ca_csr.csr
sed -i 's/\"//g' ca_csr.csr



export CertificateArn=$(aws acm-pca issue-certificate --certificate-authority-arn $certificateAuthorityArn --csr file://ca_csr.csr --signing-algorithm SHA256WITHRSA --template-arn arn:aws:acm-pca:::template/RootCACertificate/V1 --validity Value=10,Type="YEARS" --idempotency-token 1234 --profile frontend | jq -r '.CertificateArn' )


certificate=$(aws acm-pca get-certificate --certificate-authority-arn $certificateAuthorityArn --certificate-arn $CertificateArn --profile frontend |jq '.Certificate')

echo $certificate > certificate.cer
awk '{gsub(/\\n/,"\n")}1' certificate.cer  > cert.cer
sed -i 's/\"//g' cert.cer
aws acm-pca import-certificate-authority-certificate --certificate-authority-arn $certificateAuthorityArn  --certificate file://cert.cer --profile frontend                       

aws acm-pca create-permission  --certificate-authority-arn $certificateAuthorityArn --actions IssueCertificate GetCertificate ListPermissions --principal acm.amazonaws.com --profile frontend

#RAMShareCA
export frontendaccount=$(aws sts get-caller-identity --profile frontend | jq -r .'Account')
export backendaccount=$(aws sts get-caller-identity --profile backend | jq -r .'Account')

export resourceshareArn=$(aws ram create-resource-share --name Shared_Private_CA_MESH --resource-arn $certificateAuthorityArn --principals $backendaccount --profile frontend | jq -r '.resourceShare.resourceShareArn')

sleep 1 

export CA_RESOURCE_INVITE_ARN=$(aws --profile backend ram get-resource-share-invitations | jq -r '.resourceShareInvitations[]|select (.resourceShareArn=='\"$resourceshareArn\"')|.resourceShareInvitationArn')

aws --profile backend ram accept-resource-share-invitation --resource-share-invitation-arn $CA_RESOURCE_INVITE_ARN


#UpdateVirtualNodes
export backend_certificate_arn=$(aws acm request-certificate --domain-name "*.example.com" --certificate-authority-arn $certificateAuthorityArn  --query CertificateArn --output text --profile backend) 
export frontend_certificate_arn=$(aws acm request-certificate --domain-name "*.example.com" --certificate-authority-arn $certificateAuthorityArn  --query CertificateArn --output text --profile frontend)


export frontendworkerrole=$(eksctl get iamidentitymapping --profile frontend --cluster am-multi-account-1  -o json |jq -r '.[].rolearn |split("/")|.[1]')
export backendworkerrole=$(eksctl get iamidentitymapping --profile backend --cluster am-multi-account-2  -o json |jq -r '.[].rolearn |split("/")|.[1]')

aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSCertificateManagerReadOnly --role-name $frontendworkerrole --profile frontend
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSCertificateManagerPrivateCAReadOnly --role-name $frontendworkerrole --profile frontend
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSAppMeshPreviewEnvoyAccess --role-name $frontendworkerrole --profile frontend


aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSCertificateManagerReadOnly --role-name $backendworkerrole  --profile backend
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSCertificateManagerPrivateCAReadOnly --role-name $backendworkerrole --profile backend
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSAppMeshPreviewEnvoyAccess --role-name $backendworkerrole --profile backend



sed -e  "s%CERTIFICATE_ARN%"$backend_certificate_arn"%g" -e "s%CA_ARN%"$certificateAuthorityArn"%g" -e "s%FRONTEND_ACCOUNT%"$frontendaccount"%g" redis_update > redis_update.json
sed -e  "s%CERTIFICATE_ARN%"$backend_certificate_arn"%g" -e "s%CA_ARN%"$certificateAuthorityArn"%g" -e "s%FRONTEND_ACCOUNT%"$frontendaccount"%g" appserver_update > appserver_update.json
sed -e  "s%CERTIFICATE_ARN%"$backend_certificate_arn"%g" -e "s%CA_ARN%"$certificateAuthorityArn"%g" -e "s%FRONTEND_ACCOUNT%"$frontendaccount"%g" yelb_db_update > yelb_db_update.json
sed -e  "s%FRONTEND_CERTIFICATE_ARN%"$frontend_certificate_arn"%g" -e "s%CA_ARN%"$certificateAuthorityArn"%g" -e "s%FRONTEND_ACCOUNT%"$frontendaccount"%g" yelb_ui_update > yelb_ui_update.json


kubectl apply -f mesh/redis_update.yaml
kubectl apply -f mesh/appserver_update.yaml
kubectl apply -f mesh/yelb_db_update.yaml
kubectl apply -f mesh/yelb_ui_update.yaml


