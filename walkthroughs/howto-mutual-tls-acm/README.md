# Configuring Mutual TLS with File Provided TLS Certificates from ACM

In this walkthrough, like the [basic file-based TLS example](../howto-tls-file-provided), we'll enable TLS encryption with mutual (two-way) authentication between two endpoints in App Mesh using X.509 certificates.

## Introduction

In App Mesh, traffic encryption is originated and terminated by the Envoy proxy. This means your application code is not responsible for negotiating a TLS-encrypted connection, instead allowing the local proxy to negotiate and terminate TLS on your application's behalf.

In a basic TLS encryption scenario (for example, when your browser originates an HTTPS connection), the server would present a certificate to any client. In Mutual TLS, both the client and the server present a certificate to each other, and both validate the peer's certificate.

Validation typically involves checking at least that the certificate is signed by a trusted Certificate Authority, and that the certificate is still within its validity period. 

In this guide, we will be configuring Envoy proxies using certificates hosted in AWS Secrets Manager, which a modified Envoy image will retrieve during startup. We will have a virtual gateway connected to a single backend service. Both the gateway and backend proxies will present certificates signed by the same Certificate Authority (CA), though you could choose to use separate CAs.

## Prerequisites

1. Install Docker. It is needed to build the demo application images.
2. Install the unix command line utility `jq`. If you don't already have it, [you can install it from here](https://stedolan.github.io/jq/).
3. Install session manager plugin from [here](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html). If that is not possible, use the AWS console to run commands from bastion host.

## Part 1: Setup

### Step 1: Create Color App Infrastructure

We'll start by setting up the basic infrastructure for our services. All commands will be provided as if run from the same directory as this README.

Next, we need to set a few environment variables before provisioning the infrastructure. Please change the value for `AWS_ACCOUNT_ID` and `ENVOY_IMAGE` below.

```bash
export AWS_ACCOUNT_ID=<your account id>
export AWS_DEFAULT_REGION=us-east-1
export ENVIRONMENT_NAME=mtls-appmesh-example
export MESH_NAME=mtls-appmesh
export SERVICES_DOMAIN="mtls.svc.cluster.local"
export ENVOY_IMAGE=<get the latest from https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html>
export COLOR_TELLER_IMAGE_NAME="colorteller"
export ENVOY_IMAGE_NAME="colorteller-envoy"
```

Now let's create the VPC.

```bash
./infrastructure/vpc.sh
```

Next, create the ECR repositories.
```bash
./infrastructure/ecr-repositories.sh
```
Now, we can build and deploy the color app image.

```bash
GO_PROXY=direct ./src/colorteller/deploy.sh
```

Note that the example apps use go modules. If you have trouble accessing https://proxy.golang.org during the deployment you can override the GOPROXY by setting `GO_PROXY=direct` as shown above.

### Step 2: Generate the CAs, Root Certs and Endpoint Certs in ACM PCA 

Before we can encrypt traffic between services in the mesh, we need a PKI setup and to generate our certificates. For this demo we will generate:

- Two Certificate Authorities and their corresponding root certs:
   -- ColorTeller CA
   -- ColorGateway CA
- Two end-point certs: 
   -- ColorTeller virtual node
   -- ColorGateway virtual gateway

Using AWS Lambda a random password is generated in secrets manager which is used as a passphrase to export certificate from AWS ACM and store certifcate material with passphrase in secrets manager by running the command below.
```bash
./infrastructure/acmpca.sh
```

Next, create the ECS cluster. ECS cluster will be created with permissions to retrieve the secret created above.

```bash
./infrastructure/ecs-cluster.sh
```

### Step 3: Export our Custom Envoy Image


Next, we can build and deploy our custom Envoy image. This container has a `/keys` directory and a custom startup script that will pull the necessary certificates from `AWS Secrets Manager` before starting up the Envoy proxy.

```bash
./src/customEnvoyImage/deploy.sh
```

> Note: This walkthrough uses this custom Envoy image for illustration purposes. App Mesh does not support an integration with ACM for mTLS at this time. These instructions are for exporting an ACM certificate and using it as a customer file provided certificate. Your certificates will not be automatically updated after renewal, rotating certificates will require a restart or deployment of your tasks. You may choose to setup an event when your certifactes are expiring to trigger an automation to update the services using the certificates.

### Step 4: Create a Mesh with no TLS

The initial state of the mesh will provision the gateway and colorteller to communicate in plain HTTP. Once we have bootstrapped the application, a follow-up section will progressively add TLS configuration.

The gateway will listen on port 9080, and route all traffic to the virtual node listening on port 9080.

Now with the mesh defined, we can deploy our service to ECS and test it out.

```bash
./infrastructure/mesh.sh no-tls
```

### Step 5: Deploy and Verify
Now with the mesh defined, we can deploy our service to ECS and test it out.
```bash
./infrastructure/ecs-service.sh
```

Before testing, setup the environment with variables needed for testing

```bash
COLORAPP_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $ENVIRONMENT_NAME-ecs-service \
    | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="ColorAppEndpoint") | .OutputValue')

BASTION_HOST=$(aws cloudformation describe-stack-resource \
 --stack-name $ENVIRONMENT_NAME-ecs-cluster \
 --logical-resource-id BastionHost --query StackResourceDetail.PhysicalResourceId --output text)

ECS_CLUSTER=$(aws cloudformation describe-stack-resource \
 --stack-name $ENVIRONMENT_NAME-ecs-cluster \
 --logical-resource-id ECSCluster --query StackResourceDetail.PhysicalResourceId --output text)

COLORTELLER_SERVICE=$(aws cloudformation describe-stack-resource \
 --stack-name $ENVIRONMENT_NAME-ecs-service \
 --logical-resource-id ColorTellerService --query StackResourceDetail.PhysicalResourceId --output text)

GATEWAY_SERVICE=$(aws cloudformation describe-stack-resource \
 --stack-name $ENVIRONMENT_NAME-ecs-service \
 --logical-resource-id GatewayService --query StackResourceDetail.PhysicalResourceId --output text)
```


Now, let's issue a request to the color gateway.

```bash
$ curl $COLORAPP_ENDPOINT
yellow
```

You should see a successful response with the color yellow.

Finally, let's log in to the bastion host and check the SSL handshake statistics. You should do this in a separate terminal, as you will be switching back and forth.

```bash
aws ssm start-session --target $BASTION_HOST
```
```bash
curl -s colorteller.mtls.svc.cluster.local:9901/stats | grep -E 'ssl.handshake|ssl.no_certificate'
```

You won't see any results, as Envoy will not have emitted this stat until a TLS connection occurs.

Check out the [TLS Encryption](https://docs.aws.amazon.com/app-mesh/latest/userguide/tls.html) documentation for more information on enabling encryption between services in App Mesh.

## Part 2: Adding TLS to the Mesh

For demonstration purposes, we will progressively add TLS configuration to your mesh:

1. Add TLS termination at the virtual node
1. Add client validation to the virtual gateway with an incorrect Subject Alternative Name
1. Update client validation on virtual gateway to correct the SAN
1. Require a client certificate at the virtual node
1. Provide a client certificate at the virtual gateway

### Step 1: Enable Strict TLS Termination

Run the following command:

```bash
./infrastructure/mesh.sh 1way-tls
```

> Note: Updates to a mesh have some amount of propagation delay, usually measured in seconds. If you notice that some of the steps in the rest of this walkthrough don't match the expected outcome, allow some time for the configuration to be distributed to your Envoy proxies and try again. For example, in this step, the TLS configuration may not have propagated to your proxies by the time you curl the app, so the proxies would actually still be communicating over plain HTTP and therefore would not have any SSL statistics emitted.

This updates the virtual gateway to be configured to use ACM for TLS.

```yaml
meshName: mtls-appmesh
virtualGatewayName: gateway-vgw
spec:
  backendDefaults:
    clientPolicy:
      tls:
        enforce: true
        validation:
          trust:
            acm:
              certificateAuthorityArns:
                - >-
                  arn:aws:acm-pca:us-east-1:012345678912:certificate-authority/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
                # this is the  ACM PCA CA ARN for colorteller.mtls.svc.cluster.local
  listeners:
    - portMapping:
        port: 9080
        protocol: http
```

The `tls` block specifies a validation to acm where the Envoy can find the materials it expects. 

The update also configures virtual node to use ACM for TLS.

```yaml
meshName: mtls-appmesh
virtualNodeName: colorteller-vn
spec:
  listeners:
    - portMapping:
        port: 9080
        protocol: http
      tls:
        certificate:
          acm:
            certificateArn: >-
              arn:aws:acm:us-east-1:012345678912:certificate/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
            # this is the ACM ARN for colorteller.mtls.svc.cluster.local
        mode: STRICT
  serviceDiscovery:
    awsCloudMap:
      namespaceName: mtls.svc.cluster.local
      serviceName: colorteller
```
So instead of providing client and server certs as a file tls is made possible by referencing ACM.

By default, App Mesh will configure your clients to accept any certificate provided by a backend. So, if you query the endpoint again now, the request will still succeed.

Recycle the containers after the update so that a new connection can take place. Then wait for the deployment to complete.
```bash
aws ecs update-service --cluster $ECS_CLUSTER --service $COLORTELLER_SERVICE --force-new-deployment
aws ecs update-service --cluster $ECS_CLUSTER --service $GATEWAY_SERVICE --force-new-deployment
aws ecs wait services-stable --cluster $ECS_CLUSTER --service $COLORTELLER_SERVICE
aws ecs wait services-stable --cluster $ECS_CLUSTER --service $GATEWAY_SERVICE
```

```bash
% curl $COLORAPP_ENDPOINT
yellow
```

From the bastion, check the SSL stats on the backend application. You should now see a non-zero number of TLS handshakes.

```bash
% curl -s colorteller.mtls.svc.cluster.local:9901/stats | grep -E 'ssl.handshake|ssl.no_certificate'
listener.0.0.0.0_15000.ssl.handshake: 1
listener.0.0.0.0_15000.ssl.no_certificate: 1
```

Also take a look at the `ssl.no_certificate` metric on the colorteller, which shows the number of successful connections in which no client certificate was provided. Right now, this metric should match the number of handshakes, but it will become interesting later.

### Step 2: Require a Client Certificate for Mutual TLS

Now, let's update the colorteller node to require clients to present a certificate, by specifying a trusted authority just as we did with the client policy. When you specify a validation context on a listener, App Mesh will configure the Envoy to require a client certificate. This is half of the configuration required for Mutual TLS.

> Note: We do this first to illustrate what happens when TLS validation is met. 

```bash
./infrastructure/mesh.sh mtls
```

This updates the virtual gateway with a `certificate` object.

```yaml
meshName: mtls-appmesh
virtualGatewayName: gateway-vgw
spec:
  backendDefaults:
    clientPolicy:
      tls:
        certificate:
          file:
            certificateChain: /keys/colorgateway_endpoint_cert_chain.pem
            # this is the ACM Certificate Chain for colorgateway.mtls.svc.cluster.local
            privateKey: /keys/colorgateway_endpoint_dec_pri_key.pem
            # this is the decrypted ACM private key for colorgateway.mtls.svc.cluster.local
        enforce: true
        validation:
          trust:
            acm:
              certificateAuthorityArns:
                - >-
                  arn:aws:acm:us-east-1:012345678912:certificate/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
              # this is the ACM ARN for colorteller.mtls.svc.cluster.local
  listeners:
    - portMapping:
        port: 9080
        protocol: http
```

On the virtual node `validation` is added to check for colorgateway certificate chain.
```yaml
meshName: mtls-appmesh
virtualNodeName: colorteller-vn
spec:
  listeners:
    - portMapping:
        port: 9080
        protocol: http
      tls:
        certificate:
          acm:
            certificateArn: >-
              arn:aws:acm:us-east-1:012345678912:certificate/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
            # this is the ACM ARN for colorteller.mtls.svc.cluster.local
        mode: STRICT
        validation:
          trust:
            file:
              certificateChain: /keys/colorgateway_endpoint_cert_chain.pem
              # this is the ACM Certificate Chain for colorgateway.mtls.svc.cluster.local
  serviceDiscovery:
    awsCloudMap:
      namespaceName: mtls.svc.cluster.local
      serviceName: colorteller
```

Recycle the containers after the update so that a new connection can take place. Then wait for the deployment to complete.
```bash
aws ecs update-service --cluster $ECS_CLUSTER --service $COLORTELLER_SERVICE --force-new-deployment
aws ecs update-service --cluster $ECS_CLUSTER --service $GATEWAY_SERVICE --force-new-deployment
aws ecs wait services-stable --cluster $ECS_CLUSTER --service $COLORTELLER_SERVICE
aws ecs wait services-stable --cluster $ECS_CLUSTER --service $GATEWAY_SERVICE
```

Now query the endpoint again
```bash
% curl $COLORAPP_ENDPOINT
yellow
```

From the bastion, take a look at SSL stats:

```bash
% curl -s colorteller.mtls.svc.cluster.local:9901/stats | grep -E 'ssl.handshake|ssl.no_certificate'
listener.0.0.0.0_15000.ssl.handshake: 1
listener.0.0.0.0_15000.ssl.no_certificate: 0
```
As you can see `ssl.no_certificate` metric on the colorteller, which shows the number of successful connections in which no client certificate was provided is now set to zero proving Mutual TLS.

At this point, you have mutual TLS authentication between the gateway and the application node. Both are providing a certificate, both are validating that certificate against a certificate authority which in this case is ACM.

## Part 3: Clean Up

If you want to keep the application running, you can do so, but this is the end of this walkthrough.
Run the following commands to clean up and tear down the resources that we’ve created.

```bash
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-service
aws cloudformation wait stack-delete-complete --stack-name $ENVIRONMENT_NAME-ecs-service
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-mesh
aws cloudformation wait stack-delete-complete --stack-name $ENVIRONMENT_NAME-mesh
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-cluster
aws cloudformation wait stack-delete-complete --stack-name $ENVIRONMENT_NAME-ecs-cluster
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-acm
aws cloudformation wait stack-delete-complete --stack-name $ENVIRONMENT_NAME-acm
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecr-repositories
aws cloudformation wait stack-delete-complete --stack-name $ENVIRONMENT_NAME-ecr-repositories
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-vpc
aws cloudformation wait stack-delete-complete --stack-name $ENVIRONMENT_NAME-vpc
```

> Note: Deletion of the `ecs-service` and `mesh` stack can sometimes fail on the first attempt, as the resources may not be fully deregistered before CloudFormation attempts to delete the Cloud Map services. A retry of the delete should succeed.
