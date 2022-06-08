# Configuring TLS with AWS Certificate Manager

In this walkthrough we'll enable TLS encryption between two services in App Mesh using X.509 certificates provided by AWS Certificate Manager (ACM). This walkthrough will be a simplified version of the [Color App Example](https://github.com/aws/aws-app-mesh-examples/tree/main/examples/apps/colorapp).

## Introduction

In App Mesh, traffic encryption works between Virtual Nodes and Virtual Gateways, and thus between Envoys in your service mesh. This means your application code is not responsible for negotiating a TLS-encrypted session, instead allowing the local proxy to negotiate and terminate TLS on your application's behalf.

With ACM, you can host some or all of your Public Key Infrastructure (PKI) in AWS, and App Mesh will automatically distribute the certificates to the Envoys configured by your Virtual Nodes and Virtual Gateways. App Mesh also automatically distributes the appropriate TLS validation context to other Virtual Nodes and Virtual Gateways which depend on your service by way of a Virtual Service.

Let's jump into a brief example of App Mesh TLS in action.

## Prerequisites

1. Install Docker. It is needed to build the demo application images.

## Step 1: Create Color App Infrastructure

We'll start by setting up the basic infrastructure for our services. All commands will be provided as if run from the same directory as this README.

You'll need a keypair stored in AWS to access a bastion host. You can create a keypair using the command below if you don't have one. See [Amazon EC2 Key Pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html).

```bash
aws ec2 create-key-pair --key-name color-app | jq -r .KeyMaterial > ~/.ssh/color-app.pem
chmod 400 ~/.ssh/color-app.pem
```

This command creates an Amazon EC2 Key Pair with name `color-app` and saves the private key at
`~/.ssh/color-app.pem`.

Next, we need to set a few environment variables before provisioning the
infrastructure. Please change the value for `AWS_ACCOUNT_ID`, `KEY_PAIR_NAME`, and `ENVOY_IMAGE` below.

```bash
export AWS_ACCOUNT_ID=<your account id>
export KEY_PAIR_NAME=<color-app or your SSH key pair stored in AWS>
export AWS_DEFAULT_REGION=us-west-2
export ENVIRONMENT_NAME=AppMeshTLSExample
export MESH_NAME=ColorApp-TLS
export ENVOY_IMAGE=<get the latest from https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html>
export SERVICES_DOMAIN="default.svc.cluster.local"
export COLOR_TELLER_IMAGE_NAME="colorteller"
```

First, create the VPC.

```bash
./infrastructure/vpc.sh
```

Next, create the ECS cluster and ECR repositories.

```bash
./infrastructure/ecs-cluster.sh
./infrastructure/ecr-repositories.sh
```

Finally, build and deploy the color app images.

```bash
./src/colorteller/deploy.sh
```

Note that the example apps use go modules. If you have trouble accessing https://proxy.golang.org during the deployment you can override the GOPROXY by setting `GO_PROXY=direct`

```bash
GO_PROXY=direct ./src/colorteller/deploy.sh
```

## Step 2: Create a Certificate

Before we can encrypt traffic between services in the mesh, we need to generate a certificate. App Mesh currently supports certificates issued by an [ACM Private Certificate Authority](https://docs.aws.amazon.com/acm-pca/latest/userguide/PcaWelcome.html), which we'll setup in this step.

Start by creating a root certificate authority (CA) in ACM.

> You pay a monthly fee for the operation of each AWS Certificate Manager Private Certificate Authority until you delete it and you pay for the private certificates you issue each month. For more information, see [AWS Certificate Manager Pricing](https://aws.amazon.com/certificate-manager/pricing/).

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

Now you can request a managed certificate from ACM using this CA:

```bash
export CERTIFICATE_ARN=`aws acm request-certificate \
    --domain-name "*.${SERVICES_DOMAIN}" \
    --certificate-authority-arn ${ROOT_CA_ARN} \
    --query CertificateArn --output text`
```

With managed certificates, ACM will automatically renew certificates that are nearing the end of their validity, and App Mesh will automatically distribute the renewed certificates. See [Managed Renewal and Deployment](https://aws.amazon.com/certificate-manager/faqs/#Managed_Renewal_and_Deployment) for more information.

## Step 3: Create a Mesh with TLS enabled

This mesh will be a simplified version of the original Color App Example, so we'll only be deploying the gateway and one color teller service (white).

We'll be encrypting traffic from the Virtual Gateway to the color teller node. Our color teller white Virtual Node will be terminating TLS with a certificate provided by ACM. The spec looks like this:

```yaml
ColorTellerVirtualNode:
  Type: AWS::AppMesh::VirtualNode
  Properties:
    MeshName: !GetAtt Mesh.MeshName
    VirtualNodeName: ColorTellerWhite
    Spec:
      Listeners:
        - PortMapping:
            Port: 80
            Protocol: http
          HealthCheck:
            Protocol: http
            Path: /ping
            HealthyThreshold: 2
            UnhealthyThreshold: 3
            TimeoutMillis: 2000
            IntervalMillis: 5000
          TLS:
            # Mode determines whether or not TLS is negotiated on this Virtual Node.
            # STRICT - TLS is required.
            # PERMISSIVE - TLS is optional (plain-text allowed).
            # DISABLED - TLS is disabled (plain-text only).
            Mode: STRICT
            # Use a certificate from ACM.
            Certificate:
              ACM:
                CertificateArn: !Ref CertificateArn
      ServiceDiscovery:
        DNS:
          Hostname: !Sub "colorteller.${SERVICES_DOMAIN}"
```

Additionally, the gateway service will be configured to validate the certificate of the color teller node by specifying the CA that issued it. The spec for the gateway looks like this:

```yaml
ColorGatewayVirtualGateway:
  Type: AWS::AppMesh::VirtualGateway
  Properties:
    MeshName: !GetAtt Mesh.MeshName
    VirtualGatewayName: ColorGateway
    Spec:
      BackendDefaults:
        ClientPolicy:
          TLS:
            Validation:
              Trust:
                ACM:
                  CertificateAuthorityArns:
                    - !Ref CertificateAuthorityArn
      Listeners:
        - PortMapping:
            Port: 80
            Protocol: http

ColorGatewayRoute:
  DependsOn:
    - ColorGatewayVirtualGateway
    - ColorTellerVirtualService
  Type: AWS::AppMesh::GatewayRoute
  Properties: 
    GatewayRouteName: ColorGatewayRoute
    MeshName: !GetAtt Mesh.MeshName
    Spec: 
      HttpRoute:
        Action: 
          Target:
            VirtualService:
              VirtualServiceName: !Sub "colorteller.${ServicesDomain}"
        Match: 
          Prefix: /
    VirtualGatewayName: ColorGateway
```

For more information on what TLS settings you can provide for a Virtual Node, see the [TLS Encryption](https://docs.aws.amazon.com/app-mesh/latest/userguide/virtual-node-tls.html) documentation.

Let's create the mesh.

```bash
./mesh/mesh.sh up
```

## Step 4: Deploy and Verify

Our final step is to deploy the service and test it out.

```bash
./infrastructure/ecs-service.sh
```

Let's issue a request to the color gateway.

```bash
COLORAPP_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $ENVIRONMENT_NAME-ecs-service \
    | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="ColorAppEndpoint") | .OutputValue')
curl "${COLORAPP_ENDPOINT}/color"
```

You should see a successful response with the color white.

Finally, let's log in to the bastion host and check the SSL handshake statistics.

```bash
BASTION_IP=$(aws cloudformation describe-stacks \
    --stack-name $ENVIRONMENT_NAME-ecs-cluster \
    | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="BastionIP") | .OutputValue')
ssh -i ~/.ssh/$KEY_PAIR_NAME.pem ec2-user@$BASTION_IP
curl -s http://colorteller.default.svc.cluster.local:9901/stats | grep ssl.handshake
```

You should see output similar to: `listener.0.0.0.0_15000.ssl.handshake: 1`, indicating a successful SSL handshake was achieved between gateway and color teller.

That's it! We've encrypted traffic from our gateway service to our color teller white service using a certificate from ACM.

Check out the [TLS Encryption](https://docs.aws.amazon.com/app-mesh/latest/userguide/virtual-node-tls.html) documentation for more information on enabling encryption between services in App Mesh.

## Step 5: Clean Up

If you want to keep the application running, you can do so, but this is the end of this walkthrough.
Run the following commands to clean up and tear down the resources that we’ve created.

```bash
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-service
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-cluster
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-mesh
aws ecr delete-repository --force --repository-name colorteller
aws ecr delete-repository --force --repository-name gateway
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecr-repositories
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-vpc
```

And finally delete the certificates.

```bash
aws acm delete-certificate --certificate-arn $CERTIFICATE_ARN
aws acm-pca update-certificate-authority --certificate-authority-arn $ROOT_CA_ARN --status DISABLED
aws acm-pca delete-certificate-authority --certificate-authority-arn $ROOT_CA_ARN
```

## Frequently Asked Questions

### 1. What permissions does the IAM role used by the Envoy need in order to retrieve a certificate and private key from ACM?

The IAM role used by the Envoy needs the ability to connect to App Mesh (`appmesh:StreamAggregatedResources`) and export certificates from ACM (`acm:ExportCertificate`). An example policy is provided below and is available in `./infrastructure/ecs-cluster.yaml`:

```yaml
TaskIamRole:
  Type: AWS::IAM::Role
  Properties:
    Path: /
    AssumeRolePolicyDocument: |
      {
        "Statement": [{
            "Effect": "Allow",
            "Principal": { "Service": [ "ecs-tasks.amazonaws.com" ]},
            "Action": [ "sts:AssumeRole" ]
        }]
      }
    Policies:
    - PolicyName: ACMExportCertificateAccess
      PolicyDocument: |
        {
          "Statement": [{
              "Effect": "Allow",
              "Action": ["acm:ExportCertificate"],
              "Resource": ["*"]
          }]
        }
    ManagedPolicyArns:
    - arn:aws:iam::aws:policy/CloudWatchFullAccess
    - arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess
    - arn:aws:iam::aws:policy/AWSAppMeshPreviewEnvoyAccess
```

The policy above uses the App Mesh managed policy `AppMeshPreviewEnvoyAccess` which provides permissions for the action `appmesh:StreamAggregatedResources` for all Virtual Nodes in the mesh.

In a production setting, you should set more specific policies to scope down what Virtual Nodes and Certificates an Envoy has access to.

### 2. Will App Mesh export the certificate from ACM?

Yes, App Mesh will export your certificate using the `ExportCerticate` API. See [AWS Certificate Manager Pricing](https://aws.amazon.com/certificate-manager/pricing/) for information on the cost associated with exporting a certificate.

### 3. What permissions does the IAM role used by the Envoy need in order to retrieve a certificate authority certificate?

When using an ACM Private Certificate Authority in a client policy for a Virtual Node's backend, the IAM role used by the Envoy needs the ability to connect to App Mesh (`appmesh:StreamAggregatedResources`) and retrieve certificate authority certificates from ACM (`acm-pca:GetCertificateAuthorityCertificate`). An example policy is provided below and is available in `./infrastructure/ecs-cluster.yaml`:

```yaml
TaskIamRole:
  Type: AWS::IAM::Role
  Properties:
    Path: /
    AssumeRolePolicyDocument: |
      {
        "Statement": [{
            "Effect": "Allow",
            "Principal": { "Service": [ "ecs-tasks.amazonaws.com" ]},
            "Action": [ "sts:AssumeRole" ]
        }]
      }
    Policies:
    - PolicyName: ACMCertificateAuthorityAccess
      PolicyDocument: |
        {
          "Statement": [{
              "Effect": "Allow",
              "Action": ["acm-pca:GetCertificateAuthorityCertificate"],
              "Resource": ["*"]
          }]
        }
    ManagedPolicyArns:
    - arn:aws:iam::aws:policy/CloudWatchFullAccess
    - arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess
    - arn:aws:iam::aws:policy/AWSAppMeshPreviewEnvoyAccess
```

The policy above uses the App Mesh managed policy `AppMeshPreviewEnvoyAccess` which provides permissions for the action `appmesh:StreamAggregatedResources` for all Virtual Nodes in the mesh.

In a production setting, you should set more specific policies to scope down what Virtual Nodes and Certificate Authorities an Envoy has access to.

### 4. What happens if I don't specify a client policy to enforce TLS, but the backend has TLS enabled?

To preserve connectivity and provide for a smooth migration to TLS between services, App Mesh automatically distributes the certificate chain required to validate a TLS connection to all clients of a Virtual Node with TLS enabled when a client policy is not provided. This allows the backend to enable TLS termination, and ensures that the certificate offered by the backend is what was intended by the service owner. This is not meant to serve as sufficient configuration to support trust between services. When a client policy is provided, the default behavior is overridden with the specifications of the policy.

We recommend you specify client policies for backends when TLS is required between services so you can ensure the TLS certificate presented during TLS negotiation is from a certificate authority you trust.
