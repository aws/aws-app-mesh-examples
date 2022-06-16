#!/bin/bash

set -eo pipefail

AWS_REGION_1=$1
AWS_REGION_2=$2
CLUSTER_NAME_1=$3
CLUSTER_NAME_2=$4
DOMAIN_NAME=$5
SUB_DOMAIN_NAME=$6
HOSTED_ZONE_ID=$7

if [ -z $AWS_REGION_1 ]; then
    echo "Not a valid value for AWS region A."
    exit 1
fi

if [ -z $AWS_REGION_2 ]; then
    echo "Not a valid value for AWS region B."
    exit 1
fi

if [ -z $CLUSTER_NAME_1 ]; then
    echo "Not a valid value for cluster name in region A."
    exit 1
fi

if [ -z $CLUSTER_NAME_2 ]; then
    echo "Not a valid value for cluster name in region B."
    exit 1
fi

if [ -z $DOMAIN_NAME ]; then
    echo "Not a valid value for domain name."
    exit 1
fi

if [ -z $SUB_DOMAIN_NAME ]; then
    SUB_DOMAIN_NAME=`echo myapp.walkthrough.$DOMAIN_NAME`
else
    SUB_DOMAIN_NAME=`echo $SUB_DOMAIN_NAME.$DOMAIN_NAME`
fi

echo "Creating health check records for region A"
export KUBECONFIG=~/.kube/eksctl/clusters/$CLUSTER_NAME_1
export GW_ENDPOINT_1=$(kubectl get svc ingress-gw -n howto-k8s-multi-region --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')

uidRegioAWhite=`uuidgen`
uidRegioARed=`uuidgen`
uidRegioABlue=`uuidgen`

regionAWhite=`aws route53 create-health-check --caller-reference $uidRegioAWhite --health-check-config '{"Port": 80, "Type": "HTTP", "ResourcePath": "paths/white", "FullyQualifiedDomainName": "'"$GW_ENDPOINT_1"'"}' --query 'HealthCheck.Id' --output text`
regionARed=`aws route53 create-health-check --caller-reference $uidRegioARed --health-check-config '{"Port": 80, "Type": "HTTP", "ResourcePath": "paths/red", "FullyQualifiedDomainName": "'"$GW_ENDPOINT_1"'"}' --query 'HealthCheck.Id' --output text`
regionABlue=`aws route53 create-health-check --caller-reference $uidRegioABlue --health-check-config '{"Port": 80, "Type": "HTTP", "ResourcePath": "paths/blue", "FullyQualifiedDomainName": "'"$GW_ENDPOINT_1"'"}' --query 'HealthCheck.Id' --output text`

aws route53 change-tags-for-resource --resource-type healthcheck --resource-id $regionAWhite --add-tags Key=Name,Value=regionA-white
aws route53 change-tags-for-resource --resource-type healthcheck --resource-id $regionARed --add-tags Key=Name,Value=regionA-red
aws route53 change-tags-for-resource --resource-type healthcheck --resource-id $regionABlue --add-tags Key=Name,Value=regionA-blue

uidRegioACombined=`uuidgen`
regionACombinedHealthCheck=`aws route53 create-health-check --caller-reference $uidRegioACombined --health-check-config '{"Type": "CALCULATED", "HealthThreshold": 3, "ChildHealthChecks" : ["'"$regionAWhite"'","'"$regionARed"'","'"$regionABlue"'"]}' --query 'HealthCheck.Id' --output text`
aws route53 change-tags-for-resource --resource-type healthcheck --resource-id $regionACombinedHealthCheck --add-tags Key=Name,Value=regionA-health

echo "Region A white path health check ID : $regionAWhite"
echo "Region A red path health check ID : $regionARed"
echo "Region A blue path health check ID : $regionABlue"
echo "Region A combined health check ID : $regionACombinedHealthCheck"


echo "Creating health check records for region B"
export KUBECONFIG=~/.kube/eksctl/clusters/$CLUSTER_NAME_2
export GW_ENDPOINT_2=$(kubectl get svc ingress-gw -n howto-k8s-multi-region --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')

uidRegioBWhite=`uuidgen`
uidRegioBRed=`uuidgen`
uidRegioBBlue=`uuidgen`

regionBWhite=`aws route53 create-health-check --caller-reference $uidRegioBWhite --health-check-config '{"Port": 80, "Type": "HTTP", "ResourcePath": "paths/white", "FullyQualifiedDomainName": "'"$GW_ENDPOINT_2"'"}' --query 'HealthCheck.Id' --output text`
regionBRed=`aws route53 create-health-check --caller-reference $uidRegioBRed --health-check-config '{"Port": 80, "Type": "HTTP", "ResourcePath": "paths/red", "FullyQualifiedDomainName": "'"$GW_ENDPOINT_2"'"}' --query 'HealthCheck.Id' --output text`
regionBBlue=`aws route53 create-health-check --caller-reference $uidRegioBBlue --health-check-config '{"Port": 80, "Type": "HTTP", "ResourcePath": "paths/blue", "FullyQualifiedDomainName": "'"$GW_ENDPOINT_2"'"}' --query 'HealthCheck.Id' --output text`

aws route53 change-tags-for-resource --resource-type healthcheck --resource-id $regionBWhite --add-tags Key=Name,Value=regionB-white
aws route53 change-tags-for-resource --resource-type healthcheck --resource-id $regionBRed --add-tags Key=Name,Value=regionB-red
aws route53 change-tags-for-resource --resource-type healthcheck --resource-id $regionBBlue --add-tags Key=Name,Value=regionB-blue

uidRegioBCombined=`uuidgen`
regionBCombinedHealthCheck=`aws route53 create-health-check --caller-reference $uidRegioBCombined --health-check-config '{"Type": "CALCULATED", "HealthThreshold": 3, "ChildHealthChecks" : ["'"$regionBWhite"'","'"$regionBRed"'","'"$regionBBlue"'"]}' --query 'HealthCheck.Id' --output text`
aws route53 change-tags-for-resource --resource-type healthcheck --resource-id $regionBCombinedHealthCheck --add-tags Key=Name,Value=regionB-health

echo "Region B white path health check ID : $regionBWhite"
echo "Region B red path health check ID : $regionBRed"
echo "Region B blue path health check ID : $regionBBlue"
echo "Region B combined health check ID : $regionBCombinedHealthCheck"

echo "Completed creating health check records"

if [ -z $HOSTED_ZONE_ID ]; then
    echo "Creating route53 hostedzone"
    uidHostedZone=`uuidgen`
    hostedZoneId=`aws route53 create-hosted-zone --name $DOMAIN_NAME --caller-reference $uidHostedZone --hosted-zone-config Comment="Hosted zone for app mesh multiregion walkthrough" --query 'HostedZone.Id' --output text`
    echo "Created new Hosted Zone with ID: $hostedZoneId"
else
    hostedZoneId=$HOSTED_ZONE_ID
    echo "Using existing Hosted Zone ID: $hostedZoneId" 
fi

echo "Creating CNAME record for region A"
regionARecord=`aws route53 change-resource-record-sets --hosted-zone-id $hostedZoneId --change-batch '{"Changes": [{ "Action": "CREATE", "ResourceRecordSet":{ "Name": "'"$SUB_DOMAIN_NAME"'", "Type": "CNAME", "SetIdentifier": "regionARecordID", "Region": "'"$AWS_REGION_1"'", "TTL": 300, "ResourceRecords": [{ "Value": "'"$GW_ENDPOINT_1"'" }], "HealthCheckId": "'"$regionACombinedHealthCheck"'" }}]}'`

echo "Creating CNAME record for region B"
regionBRecord=`aws route53 change-resource-record-sets --hosted-zone-id $hostedZoneId --change-batch '{"Changes": [{ "Action": "CREATE", "ResourceRecordSet":{ "Name": "'"$SUB_DOMAIN_NAME"'", "Type": "CNAME", "SetIdentifier": "regionBRecordID", "Region": "'"$AWS_REGION_2"'", "TTL": 300, "ResourceRecords": [{ "Value": "'"$GW_ENDPOINT_2"'" }], "HealthCheckId": "'"$regionBCombinedHealthCheck"'" }}]}'`


echo "Completed configuring route53"