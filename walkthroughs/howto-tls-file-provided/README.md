# Configuring TLS with File Provided TLS Certificates

In this walkthrough we'll enable TLS encryption between two services in App Mesh using X.509 certificates packaged with your Envoy container. This walkthrough will be a simplified version of the [Color App Example](https://github.com/aws/aws-app-mesh-examples/tree/main/examples/apps/colorapp).

## Introduction

In App Mesh, traffic encryption works between Virtual Nodes and Virtual Gateways, and thus between Envoys in your service mesh. This means your application code is not responsible for negotiating a TLS-encrypted session, instead allowing the local proxy to negotiate and terminate TLS on your application's behalf.

In this guide, we will be configuring App Mesh to use the file based strategy of providing TLS certificates to Envoy.

## Prerequisites

1. Install Docker. It is needed to build the demo application images.
1. The unix command line utility `jq`. If you don't already have it, you can install it from [here](https://stedolan.github.io/jq/).

## Step 1: Create Color App Infrastructure

We'll start by setting up the basic infrastructure for our services. All commands will be provided as if run from the same directory as this README.

Next, we need to set a few environment variables before provisioning the
infrastructure. Please change the value for `AWS_ACCOUNT_ID` and `ENVOY_IMAGE` below.

```bash
export AWS_ACCOUNT_ID=<your account id>
export AWS_DEFAULT_REGION="us-west-2"
export ENVIRONMENT_NAME="AppMeshTLSExample"
export MESH_NAME="ColorApp-TLS"
export ENVOY_IMAGE=<get the latest from https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html>
export SERVICES_DOMAIN="default.svc.cluster.local"
export COLOR_TELLER_IMAGE_NAME="colorteller"
export COLOR_APP_ENVOY_IMAGE_NAME="colorapp-envoy"
```

You'll need a keypair stored in AWS to access a bastion host. You can create a keypair using the command below if you don't have one. See [Amazon EC2 Key Pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html).

Export the name of the keypair:

```bash
export KEY_PAIR_NAME=<name of the key pair to use>
```

If you are creating a new keypair, run these commands:

```bash
aws ec2 create-key-pair --key-name $KEY_PAIR_NAME | jq -r .KeyMaterial > ~/.ssh/$KEY_PAIR_NAME.pem
chmod 400 ~/.ssh/$KEY_PAIR_NAME.pem
```

This command creates an Amazon EC2 Key Pair and saves the private key at `~/.ssh/${KEY_PAIR_NAME}.pem`.

Now that you have your key pair set up, create the VPC.

```bash
./infrastructure/vpc.sh
```

Next, create the ECS cluster and ECR repositories.

```bash
./infrastructure/ecs-cluster.sh
./infrastructure/ecr-repositories.sh
```

Next, build and deploy the color app image.

```bash
./src/colorteller/deploy.sh
```

Note that the example apps use go modules. If you have trouble accessing https://proxy.golang.org during the deployment you can override the GOPROXY by setting `GO_PROXY=direct`

```bash
GO_PROXY=direct ./src/colorteller/deploy.sh
```

## Step 2: Generate the Certficates

Before we can encrypt traffic between services in the mesh, we need to generate our certificates.

For this demo, we are going to set up two separate Certificate Authorities. The first one will be used to sign the certificate for the White Color Teller, the second will be used to sign the certificate for the Green Color Teller.

```bash
./src/tlsCertificates/certs.sh
```

This generates a few different files

- *_cert.pem: These files are the public side of the certificates
- *_key.pem: These files are the private key for the certificates
- *_cert_chain: These files are an ordered list of the public certificates used to sign a private key
- ca_1_ca_2_bundle.pem: This file contains the public certificates for both CAs.

You can verify that the White Color Teller certificate was signed by CA 1 using this command.

```bash
openssl verify -verbose -CAfile src/tlsCertificates/ca_1_cert.pem  src/tlsCertificates/colorteller_white_cert.pem
```

We are going to store these certificates in [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/). This will allow us to securely retrieve them at a later time.

```bash
./src/tlsCertificates/deploy.sh
```

## Step 3: Export our Custom Docker Image

Finally, we can build and deploy our custom docker image. This container has a `/keys` directory and a custom startup script that will pull the necessary certificates from `AWS Secrets Manager`.

```bash
./src/customEnvoyImage/deploy.sh
```

## Step 4: Create a Mesh with TLS enabled

Our service will contain three components, a Virtual Gateway that will split requests between a White Color Teller and a Green Color Teller.
Initially, we will only serve traffic to the White Color Teller.

Let's create the mesh.

```bash
./mesh/mesh.sh up
```

The Virtual Node spec for the white colorteller looks like:

```yaml
ColorTellerWhiteVirtualNode:
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
            Mode: STRICT
            Certificate:
              File:
                CertificateChain: "/keys/colorteller_white_cert_chain.pem"
                PrivateKey: "/keys/colorteller_white_key.pem"
      ServiceDiscovery:
        DNS:
          Hostname: !Sub "colorteller.${ServicesDomain}"
```

The `tls` block specifies a filepath to where the Envoy can find the certificates it expects. In order to encrypt the traffic, Envoy needs to have both the certificate chain and the private key.

## Step 5: Deploy and Verify

Now with the mesh defined, we can deploy our service to ECS and test it out.

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

Check out the [TLS Encryption](https://docs.aws.amazon.com/app-mesh/latest/userguide/tls.html) documentation for more information on enabling encryption between services in App Mesh.

## Client TLS Validation Tutorial

Enabling TLS communication from your virtual node is the first step to securing your traffic. In a zero trust system, the Color Gateway should also be responsible for defining what certificate authorities are trusted. App Mesh allows you to configure Envoy with information on what CAs you trust to vend certificates. We will demonstrate this by adding a new color teller to our service that has a TLS certificate vended from a different CA than the first.

## Step 6: Add the Green Color Teller

We previously added two color tellers, the White Color Teller and the Green Color Teller. The TLS configuration for the Green Color Teller looks almost identical to the White, but now we are using the `colorteller_green` related certificates.

```yaml
TLS:
  Mode: STRICT
  Certificate:
    File:
      CertificateChain: "/keys/colorteller_green_cert_chain.pem"
      PrivateKey: "/keys/colorteller_green_key.pem"
```

The route we have currently, only routes to the White Color Teller. We will also need to update the to serve traffic to both color tellers:

```yaml
HttpRoute:
  Action:
    WeightedTargets:
      - VirtualNode: !GetAtt ColorTellerWhiteVirtualNode.VirtualNodeName
        Weight: 1
      - VirtualNode: !GetAtt ColorTellerGreenVirtualNode.VirtualNodeName
        Weight: 1
```

Let's update our mesh

```bash
./mesh/mesh.sh addGreen
```

After a couple seconds, when you hit the service, you should see both green and white returned. Note, you may have to call it a few times.

```bash
curl "${COLORAPP_ENDPOINT}/color"
```

### Step 7: Add TLS Validation to the Virtual Gateway

As you just saw, we were able to add a new Virtual Node with TLS to our mesh and the Virtual Gateway was able to communicate with it no problem.  

In the client/server relationship, if the server decides to turn on TLS, App Mesh configures the client Envoys to accept the certificate offered. However, clients should also validate that the certificate offered by the server is from a certificate authority they trust. App Mesh allows you to define a client policy for TLS validation to ensure that the certificate is valid and issued from a trustworthy source.

If you recall, the Green Color Teller certificates were signed by a different CA than the White Color Teller certificates.  Perhaps this is not the intended behavior and we want to reject certificates from any CA that is not CA 1.

We are going to update the Virtual Gateway backend to have this configuration:

```yaml
BackendDefaults:
  ClientPolicy:
    TLS:
      Enforce: !If [EnableClientValidation, True, False]
      Validation:
        Trust:
          File:
            CertificateChain: "/keys/ca_1_cert.pem"
```

In this situation, we add a backend default for the Client Policy that instructs Envoy to only allow certificates signed by CA 1 to be accepted.

```bash
./mesh/mesh.sh updateGateway
```  

Now when call the service, you will see `white` is working properly, but you will start to see `upstream connect error or disconnect/reset before headers. reset reason: connection failure` from the Green Colorteller.

```bash
curl "${COLORAPP_ENDPOINT}/color"
```

### Step 8: Restore Communication to Green Color Teller

We can restore communication by changing the `certificateChain` in the backend group to be `ca_1_ca_2_bundle.pem`. This contains both the public certificates for CA 1 and CA 2, which will instructs Envoy to accept certificates signed by both CA 1 and CA 2.

```bash
./mesh/mesh.sh updateGateway2
```

Now when you call the service, you will see both `white` and `green` again.

```bash
curl "${COLORAPP_ENDPOINT}/color"
```

### Step 9: Clean Up

If you want to keep the application running, you can do so, but this is the end of this walkthrough.
Run the following commands to clean up and tear down the resources that we’ve created.

```bash
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-service
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-cluster
aws ecr delete-repository --force --repository-name $COLOR_TELLER_IMAGE_NAME
aws ecr delete-repository --force --repository-name $COLOR_APP_ENVOY_IMAGE_NAME
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecr-repositories
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-vpc
```

Delete the mesh.

```bash
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-mesh
```

And finally delete the certificates.

```bash
./src/tlsCertificates/cleanup.sh
```
