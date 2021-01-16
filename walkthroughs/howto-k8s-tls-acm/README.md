## Overview
In this walkthrough we'll enable TLS encryption between two applications in App Mesh using private certificate from AWS Certificate Manager issued by an AWS Certificate Manager Private Certificate Authority (ACM PCA) .

## Prerequisites
* To install appmesh-controller with IAM Roles for Service Account, follow the instructions [here](https://github.com/aws/eks-charts/blob/master/stable/appmesh-controller/README.md#eks-with-iam-roles-for-service-account) otherwise follow the instructions in [Walkthrough: App Mesh with EKS](../eks/)
* If all the IAM permissions are being added to the worker node IAM role, then the nodes should have the IAM permissions from the following policies: `AWSAppMeshFullAccess`, `AWSCloudMapFullAccess`.

* While using ACM PCA for TLS, we require some additional IAM permissions. As per [Transport Layer Security (TLS)](https://docs.aws.amazon.com/app-mesh/latest/userguide/tls.html), Proxy authorization must be enabled and the following IAM permissions would be required to use ACM PCA for TLS.Please verify that the worker node IAM roles have the below IAM permissions
    * `appmesh:StreamAggregatedResources` 
    * `acm:ExportCertificate`
    * `acm-pca:GetCertificateAuthorityCertificate`

* The manifest in this walkthrough requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

* Install Docker. It is needed to build the demo application images.



## Step 1: Setup environment
1. Clone this repository and navigate to the walkthrough/howto-k8s-tls-acm folder, all commands will be executed from this location
2. Your AWS account id:

    export AWS_ACCOUNT_ID=<your_account_id>

3. Region e.g. us-west-2

    export AWS_DEFAULT_REGION=us-west-2

4. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.

5. SERVICES_DOMAIN to be used while creating the AWS Certificate Manager Private Certificate Authority

     export SERVICES_DOMAIN="howto-k8s-tls-acm.svc.cluster.local"


## Step 2: Create a Certificate

Before we can encrypt traffic between services in the mesh, we need to generate a certificate. App Mesh currently supports certificates issued by an [ACM Private Certificate Authority](https://docs.aws.amazon.com/acm-pca/latest/userguide/PcaWelcome.html), which we'll setup in this step.

Start by creating a root certificate authority (CA) in ACM.

***Note: You pay a monthly fee for the operation of each AWS Certificate Manager Private Certificate Authority until you delete it and you pay for the private certificates you issue each month. For more information, see [AWS Certificate Manager Pricing](https://aws.amazon.com/certificate-manager/pricing/).***

```bash
export ROOT_CA_ARN=`aws acm-pca create-certificate-authority \
    --certificate-authority-type ROOT \
    --certificate-authority-configuration \
    "KeyAlgorithm=RSA_2048,
    SigningAlgorithm=SHA256WITHRSA,
    Subject={
        Country=US,
        State=WA,
        Locality=Seattle,
        Organization=App Mesh Examples,
        OrganizationalUnit=TLS Example,
        CommonName=${SERVICES_DOMAIN}}" \
        --query CertificateAuthorityArn --output text`
```

Next you need to self-sign your root CA. Start by retrieving the CSR contents:

```bash
ROOT_CA_CSR=`aws acm-pca get-certificate-authority-csr \
    --certificate-authority-arn ${ROOT_CA_ARN} \
    --query Csr --output text`
```

Sign the CSR using itself as the issuer.

Note that if you are using AWS CLI version 2, you will need to pass the CSR data through encoding prior to invoking the 'issue-certificate' command.

```bash
AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)
[[ ${AWS_CLI_VERSION} -gt 1 ]] && ROOT_CA_CSR="$(echo ${ROOT_CA_CSR} | base64)"
```

```bash
ROOT_CA_CERT_ARN=`aws acm-pca issue-certificate \
    --certificate-authority-arn ${ROOT_CA_ARN} \
    --template-arn arn:aws:acm-pca:::template/RootCACertificate/V1 \
    --signing-algorithm SHA256WITHRSA \
    --validity Value=10,Type=YEARS \
    --csr "${ROOT_CA_CSR}" \
    --query CertificateArn --output text`
```

Then import the signed certificate as the root CA:

```bash
ROOT_CA_CERT=`aws acm-pca get-certificate \
    --certificate-arn ${ROOT_CA_CERT_ARN} \
    --certificate-authority-arn ${ROOT_CA_ARN} \
    --query Certificate --output text`
```

Note again with AWS CLI version 2, you will need to pass the certificate data through encoding.

```bash
[[ ${AWS_CLI_VERSION} -gt 1 ]] && ROOT_CA_CERT="$(echo ${ROOT_CA_CERT} | base64)"
```

Import the certificate:

```bash
aws acm-pca import-certificate-authority-certificate \
    --certificate-authority-arn $ROOT_CA_ARN \
    --certificate "${ROOT_CA_CERT}"
```

We also want to grant permissions to the CA to automatically renew the managed certificates it issues:

```bash
aws acm-pca create-permission \
    --certificate-authority-arn $ROOT_CA_ARN \
    --actions IssueCertificate GetCertificate ListPermissions \
    --principal acm.amazonaws.com
```

Request a managed certificate from ACM using this CA:

```bash
export CERTIFICATE_ARN=`aws acm request-certificate \
    --domain-name "*.${SERVICES_DOMAIN}" \
    --certificate-authority-arn ${ROOT_CA_ARN} \
    --query CertificateArn --output text`
```

With managed certificates, ACM will automatically renew certificates that are nearing the end of their validity, and App Mesh will automatically distribute the renewed certificates. See [Managed Renewal and Deployment](https://aws.amazon.com/certificate-manager/faqs/#Managed_Renewal_and_Deployment) for more information.

## Step 3: Create a Mesh with TLS enabled

We are going to setup a mesh with four virtual nodes: Frontend, Blue, Green and Red, one virtual service: color and one virtual router: color.

Let's create the mesh.

```bash
./mesh.sh up
```

Frontend has backend virtual service (color) configured and the virtual service (color) uses virtual router (color) as the provider. The virtual router (color) has three routes configured:
- color-route-blue: matches on HTTP header "blue" to route traffic to virtual node `blue`
- color-route-green: matches on HTTP header "green" to route traffic to virtual node `green` 
- color-route-red: matches on HTTP header "red" to route traffic to virtual node `red`

Virtual node `blue` is configured with TLS enabled for it's respective listeners. Here's the spec for `blue` Virtual Node:

```
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: blue
  namespace: howto-k8s-tls-acm
spec:
  podSelector:
    matchLabels:
      app: color
      version: blue
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      healthCheck:
        protocol: http
        path: '/ping'
        healthyThreshold: 2
        unhealthyThreshold: 2
        timeoutMillis: 2000
        intervalMillis: 5000
      tls:
        mode: STRICT
        certificate:
          acm:
            certificateARN: arn:aws:acm:us-west-2:<ACCOUNT_ID>:certificate/<certificate>
  serviceDiscovery:
    dns:
      hostname: color-blue.howto-k8s-tls-acm.svc.cluster.local
```

The `tls` block specifies the ACM certificate to use.


## Setup 4: Verify TLS is enabled

```bash
kubectl -n default run -it --rm curler --image=tutum/curl /bin/bash
```

```
curl -H "color_header: blue" front.howto-k8s-tls-acm.svc.cluster.local:8080/; echo;

```

You should see a successful response when using the HTTP header "color_header: blue"

Let's check the SSL handshake statistics.

```bash
BLUE_POD=$(kubectl get pod -l "version=blue" -n howto-k8s-tls-acm --output=jsonpath={.items..metadata.name})
kubectl exec -it $BLUE_POD -n howto-k8s-tls-acm -c envoy -- curl -s http://localhost:9901/stats | grep ssl.handshake
```

You should see output similar to: listener.0.0.0.0_15000.ssl.handshake: 1, indicating a successful SSL handshake was achieved between front and blue color app


## Step 5: Cleanup

If you want to keep the application running, you can do so, but this is the end of this walkthrough.Run the following commands to clean up and tear down the resources that we’ve created.

```bash
kubectl delete -f _output/manifest.yaml
```

Delete the ECR Repositories. The `force` flag would delete the docker images inside the ECR repository
```bash
aws ecr delete-repository  --repository-name howto-k8s-tls-acm/colorapp --force

aws ecr delete-repository  --repository-name howto-k8s-tls-acm/feapp --force
```

And finally delete the certificates.
```bash
aws acm delete-certificate --certificate-arn $CERTIFICATE_ARN
aws acm-pca update-certificate-authority --certificate-authority-arn $ROOT_CA_ARN --status DISABLED
aws acm-pca delete-certificate-authority --certificate-authority-arn $ROOT_CA_ARN
```

To uninstall/delete the `appmesh-controller` deployment:
```bash
helm delete appmesh-controller -n appmesh-system
```

To delete the `appmesh-system` namespace:
```bash
kubectl delete ns appmesh-system
```
