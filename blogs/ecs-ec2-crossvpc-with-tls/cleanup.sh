# Delete the Virtual Services

aws appmesh delete-virtual-service --mesh-name appmesh-workshop  --virtual-service-name  frontend.appmeshworkshop.hosted.local
aws appmesh delete-virtual-service --mesh-name appmesh-workshop  --virtual-service-name  crystal.appmeshworkshop.hosted.local
aws appmesh delete-virtual-service --mesh-name appmesh-workshop  --virtual-service-name  nodejs.appmeshworkshop.hosted.local

# Delete the Virtual Nodes
aws appmesh delete-virtual-node --mesh-name appmesh-workshop  --virtual-node-name frontend
aws appmesh delete-virtual-node --mesh-name appmesh-workshop  --virtual-node-name crystal-lb-vanilla
aws appmesh delete-virtual-node --mesh-name appmesh-workshop  --virtual-node-name nodejs-lb-strawberry

# Delete AppMesh

aws appmesh delete-mesh --mesh-name appmesh-workshop

# Delete the Private Certificate

Certificate_Arn=$(aws acm list-certificates |jq -r '.CertificateSummaryList[] | select(.DomainName=="*.appmeshworkshop.hosted.local")'.CertificateArn);
aws acm delete-certificate --certificate-arn $Certificate_Arn
CA_Arn=$(aws acm-pca list-certificate-authorities | jq -r '.CertificateAuthorities[] | select(.CertificateAuthorityConfiguration.Subject.CommonName=="appmeshworkshop.hosted.local")'.Arn);
aws acm-pca update-certificate-authority --certificate-authority-arn $CA_Arn --status "DISABLED"
aws acm-pca delete-certificate-authority --certificate-authority-arn $CA_Arn --permanent-deletion-time-in-days 16
