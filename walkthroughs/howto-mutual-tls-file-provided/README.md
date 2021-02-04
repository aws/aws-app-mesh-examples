# Configuring Mutual TLS with File Provided TLS Certificates

In this walkthrough, like the [basic file-based TLS example](../howto-tls-file-provided), we'll enable TLS encryption with mutual (two-way) authentication between two endpoints in App Mesh using X.509 certificates.

## Introduction

In App Mesh, traffic encryption is originated and terminated by the Envoy proxy. This means your application code is not responsible for negotiating a TLS-encrypted connection, instead allowing the local proxy to negotiate and terminate TLS on your application's behalf.

In a basic TLS encryption scenario (for example, when your browser originates an HTTPS connection), the server would present a certificate to any client. In Mutual TLS, both the client and the server present a certificate to each other, and both validate the peer's certificate.

Validation typically involves checking at least that the certificate is signed by a trusted Certificate Authority, and that the certificate is still within its validity period. The application (in our case, Envoy) may also choose to validate other aspects of the certificate, such as the Subject Alternative Name identity signed into the certificate.

In this guide, we will be configuring Envoy proxies using certificates hosted in AWS Secrets Manager, which a modified Envoy image will retrieve during startup. We will have a virtual gateway connected to a single backend service. Both the gateway and backend proxies will present certificates signed by the same Certificate Authority (CA), though you could choose to use separate CAs.

## Prerequisites

1. Install Docker. It is needed to build the demo application images.
2. Install the unix command line utility `jq`. If you don't already have it, [you can install it from here](https://stedolan.github.io/jq/).

## Part 1: Setup

### Step 1: Create Color App Infrastructure

We'll start by setting up the basic infrastructure for our services. All commands will be provided as if run from the same directory as this README.

You'll need a keypair stored in AWS to access a bastion host. If you don't already have a keypair, you can create a keypair using the command below. See [Amazon EC2 Key Pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html).

```bash
aws ec2 create-key-pair --key-name color-app | jq -r .KeyMaterial > ~/.ssh/color-app.pem
chmod 400 ~/.ssh/color-app.pem
```

This command creates an Amazon EC2 Key Pair with name `color-app` and saves the private key at `~/.ssh/color-app.pem`.

Next, we need to set a few environment variables before provisioning the
infrastructure. Please change the value for `AWS_ACCOUNT_ID`, `KEY_PAIR_NAME`, and `ENVOY_IMAGE` below.

```bash
export AWS_ACCOUNT_ID=<your account id>
export KEY_PAIR_NAME=<color-app or your SSH key pair stored in AWS>
export AWS_DEFAULT_REGION=us-west-2
export ENVIRONMENT_NAME=AppMeshMutualTLSExample
export MESH_NAME=ColorApp-MutualTLS
export SERVICES_DOMAIN="appmesh-mtls.local"
export ENVOY_IMAGE=<get the latest from https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html>
export COLOR_TELLER_IMAGE_NAME="colorteller"
export ENVOY_IMAGE_NAME="colorteller-envoy"
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

Next, build and deploy the color app image.

```bash
./src/colorteller/deploy.sh
```

Note that the example apps use go modules. If you have trouble accessing https://proxy.golang.org during the deployment you can override the GOPROXY by setting `GO_PROXY=direct`.

### Step 2: Generate the Certificates

Before we can encrypt traffic between services in the mesh, we need to generate our certificates. For this demo we will generate:

- A Certificate Authority
- A private key and certificate for the Virtual Gateway
- A private key and certificate for the colorteller Virtual Node

```bash
./src/tlsCertificates/certs.sh
```

This generates a few different files:

- *_cert.pem: These files are the public side of the certificates
- *_key.pem: These files are the private key for the certificates
- *_cert_chain: These files are an ordered list of the public certificates used to sign a private key

You can verify that a certificate was signed by our CA using this command.

```bash
openssl verify -verbose -CAfile src/tlsCertificates/ca_cert.pem  src/tlsCertificates/colorteller_cert.pem
```

We are going to store these certificates in [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/). This will allow us to securely retrieve them at a later time.

```bash
./src/tlsCertificates/deploy.sh
```

### Step 3: Export our Custom Envoy Image

Finally, we can build and deploy our custom Envoy image. This container has a `/keys` directory and a custom startup script that will pull the necessary certificates from `AWS Secrets Manager` before starting up the Envoy proxy.

```bash
./src/customEnvoyImage/deploy.sh
```

> Note: This walkthrough uses this custom Envoy image for illustration purposes; using this method, rotating certificates will require a deployment of your tasks. You may instead choose to mount to your tasks an Elastic Block Storage or Elastic File System volume to store your TLS materials and reference them through the API accordingly.

### Step 4: Create a basic Mesh without TLS

The initial state of the mesh will provision the gateway and colorteller to communicate in plain HTTP. Once we have bootstrapped the application, a follow-up section will progressively add TLS configuration.

Let's create the mesh.

```bash
./mesh/mesh.sh up
```

The gateway will listen on port 9080, and route all traffic to the virtual node listening on port 9080.

### Step 5: Deploy and Verify

Now with the mesh defined, we can deploy our service to ECS and test it out.

```bash
./infrastructure/ecs-service.sh
```

Let's issue a request to the color gateway.

```bash
% COLORAPP_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $ENVIRONMENT_NAME-ecs-service \
    | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="ColorAppEndpoint") | .OutputValue')

% curl $COLORAPP_ENDPOINT
yellow
```

You should see a successful response with the color yellow.

Finally, let's log in to the bastion host and check the SSL handshake statistics. You should do this in a separate terminal, as you will be switching back and forth.

```bash
BASTION_IP=$(aws cloudformation describe-stacks \
    --stack-name $ENVIRONMENT_NAME-ecs-cluster \
    | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="BastionIP") | .OutputValue')
ssh -i ~/.ssh/$KEY_PAIR_NAME.pem ec2-user@$BASTION_IP
```
```bash
curl -s colorteller.appmesh-mtls.local:9901/stats | grep ssl.handshake
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
./mesh/mesh.sh update_1_strict_tls
```

> Note: Updates to a mesh have some amount of propagation delay, usually measured in seconds. If you notice that some of the steps in the rest of this walkthrough don't match the expected outcome, allow some time for the configuration to be distributed to your Envoy proxies and try again. For example, in this step, the TLS configuration may not have propagated to your proxies by the time you curl the app, so the proxies would actually still be communicating over plain HTTP and therefore would not have any SSL statistics emitted.

This updates the virtual node to be configured to provide a certificate.

```json
{
    "spec": {
        "listeners": [
            {
                "portMapping": {
                    "port": 9080,
                    "protocol": "http"
                },
                ...
                "tls": {
                    "mode": "STRICT",
                    "certificate": {
                        "file": {
                            "certificateChain": "/keys/colorteller_cert_chain.pem",
                            "privateKey": "/keys/colorteller_key.pem"
                        }
                    }
                }
            }
        ],
        ...
    }
}
```

The `tls` block specifies a filepath to where the Envoy can find the materials it expects. In order to encrypt the traffic, Envoy needs to have both the certificate chain and the private key.

By default, App Mesh will configure your clients to accept any certificate provided by a backend. So, if you query the endpoint again now, the request will still succeed.

```bash
% curl $COLORAPP_ENDPOINT
yellow
```

From the bastion, check the SSL stats on the backend application. You should now see a non-zero number of TLS handshakes.

```bash
% curl -s colorteller.appmesh-mtls.local:9901/stats | grep ssl.handshake
listener.0.0.0.0_15000.ssl.handshake: 1
```

The gateway Envoy will have a similar metric.

```bash
% curl -s gateway.appmesh-mtls.local:9901/stats | grep ssl.handshake
cluster.cds_egress_ColorApp-MutualTLS_colorteller-vn_http_9080.ssl.handshake: 1
```

Also take a look at the `ssl.no_certificate` metric on the colorteller, which shows the number of successful connections in which no client certificate was provided. Right now, this metric should match the number of handshakes, but it will become interesting later.

```bash
% curl -s colorteller.appmesh-mtls.local:9901/stats | grep ssl.no_certificate
listener.0.0.0.0_15000.ssl.no_certificate: 3
```

### Step 2: Set Explicit Client Validation (with an incorrect Subject Alternative Name)

As mentioned above, by default a client proxy will be configured to accept any certificate provided by a backend. The connection will be encrypted, but a client should always authenticate the server. To specify the trusted Certificate Authority, let's add a client policy to the virtual gateway.

```bash
./mesh/mesh.sh update_2_client_policy_bad_san
```

> Note: if you get an "Unknown parameter" error, you may need to update your AWS CLI

This adds the following configuration to the gateway, specifying which Certificate Authorities it trusts (in our case, just the one certificate that we generated).

```json
{
    "spec": {
        "listeners": [
            {
                "portMapping": {
                    "port": 9080,
                    "protocol": "http"
                }
            }
        ],
        "backendDefaults": {
            "clientPolicy": {
                "tls": {
                    "validation": {
                        "trust": {
                            "file": {
                                "certificateChain": "/keys/ca_cert.pem"
                            }
                        }
                    },
                    "subjectAlternativeNames": {
                        "match": {
                            "exact": [
                                "bogus.appmesh-mtls.local"
                            ]
                        }
                    }
                }
            }
        }
    }
}
```

On Virtual Gateways, one client policy is configured for all backends (hence backend "defaults"). On Virtual Nodes, you can specify defaults for all backends or specify a client policy per backend.

Notice one of the features introduced with Mutual TLS support: Subject Alternative Names (SANs). We're configuring Envoy to verify that one of the SANs on the certificate provided by the server matches one of the SAN strings provided in this list; in this example, the gateway will only accept a single SAN identity.

For an example of how we've configured the SAN on the colorteller certificate, look at [the configuration file for its certificate](src/tlsCertificates/colorteller_cert.cfg).

```
[alt_names]
DNS.1 = colorteller.${services_domain}
```

To highlight the behavior of an incorrect SAN, we've intentionally specified the wrong name here.

```bash
% curl $COLORAPP_ENDPOINT
upstream connect error or disconnect/reset before headers. reset reason: connection failure
```

From the bastion, look at the stats on the gateway envoy. This can include things like health checks between Envoys, which is why the number may be much higher than the number of requests to the gateway.

```bash
% curl -s gateway.appmesh-mtls.local:9901/stats | grep ssl.fail_verify_san
cluster.cds_egress_ColorApp-MutalTLS_colorteller-vn_http_9080.ssl.fail_verify_san: 49
```

**Inspecting logs**

This walkthrough configures the gateway to log at a higher level using the `ENVOY_LOG_LEVEL` environment variable set to `debug`, to illustrate some debugging.

Navigate to the CloudWatch console, and find the log group named `AppMeshExamples/mutual-tls-file-providedecs-services`. Open the most recent log stream prefixed with `gateway/envoy` to inspect the logs emitted by the Envoy proxy representing the virtual gateway.

Search for the string `"TLS error"`, and you'll find a result like the following. This is one of many error codes raised by Envoy's TLS implementation.

```
TLS error: 268435581:SSL routines:OPENSSL_internal:CERTIFICATE_VERIFY_FAILED
```

### Step 3. Correct the Subject Alternative Name to restore communication

Let's fix that SAN to match the one in the colorteller's certificate.

```bash
./mesh/mesh.sh update_3_client_policy_good_san
```

```json
{
    "spec": {
                    ...
                    "subjectAlternativeNames": {
                        "match": {
                            "exact": [
                                "colorteller.appmesh-mtls.local"
                            ]
                        }
                    }
                    ...
    }
}
```

```bash
% curl $COLORAPP_ENDPOINT
yellow
```

We're back to succeeding with an encrypted connection, just like in step 1; however, Envoy will not emit any stats the distinguish this scenario. Check out our [basic file-based TLS example](../howto-tls-file-provided) which highlights trusting a CA which wasn't used to sign a backend's certificate.

### Step 4: Require a Client Certificate

Now, let's update the colorteller node to require clients to present a certificate, by specifying a trusted authority just as we did with the client policy. When you specify a validation context on a listener, App Mesh will configure the Envoy to require a client certificate. This is half of the configuration required for Mutual TLS.

> Note: We do this first to illustrate what happens when TLS validation is unmet. If you are migrating existing App Mesh-enabled services which are already communicating with TLS, you should first configure your clients to provide a client certificate, so that when your servers are updated to request a certificate, connections are maintained.

> Note: You can also configure your virtual gateway to require a client certificate.

```bash
./mesh/mesh.sh update_4_require_client_cert
```

This updates the virtual node with a `validation` object, similar to what is available on client policies.

```bash
{
    "spec": {
        "listeners": [
            {
                ...
                "tls": {
                    "mode": "STRICT",
                    "certificate": {
                        "file": {
                            "certificateChain": "/keys/colorteller_cert_chain.pem",
                            "privateKey": "/keys/colorteller_key.pem"
                        }
                    },
                    "validation": {
                        "trust": {
                            "file": {
                                "certificateChain": "/keys/ca_cert.pem"
                            }
                        },
                        "subjectAlternativeNames": {
                            "match": {
                                "exact": [
                                    "gateway.appmesh-mtls.local"
                                ]
                            }
                        }
                    }
                }
            }
        ],
        ...
    }
}
```

```bash
% curl $COLORAPP_ENDPOINT
upstream connect error or disconnect/reset before headers. reset reason: connection failure
```

From the bastion, take a look at SSL stats:

```bash
% curl -s colorteller.appmesh-mtls.local:9901/stats | grep ssl.fail_verify_no_cert
listener.0.0.0.0_15000.ssl.fail_verify_no_cert: 208
```

These are connections that failed because the peer didn't provide a certificate. This can include things like health checks, which is why the number may be much higher than the number of requests to the gateway.

### Step 5: Provide a Client Certificate to restore communication

Now, let's give the gateway a client certificate to provide to the backend.

```bash
./mesh/mesh.sh update_5_client_cert
```

```bash
{
    "spec": {
        ...
        "backendDefaults": {
            "clientPolicy": {
                "tls": {
                    "validation": {
                        "trust": {
                            "file": {
                                "certificateChain": "/keys/ca_cert.pem"
                            }
                        },
                        "subjectAlternativeNames": {
                            "match": {
                                "exact": [
                                    "colorteller.appmesh-mtls.local"
                                ]
                            }
                        }
                    },
                    "certificate": {
                        "file": {
                            "certificateChain": "/keys/gateway_cert_chain.pem",
                            "privateKey": "/keys/gateway_key.pem"
                        }
                    }
                }
            }
        }
    }
}
```

We have configured the correct Subject Alternative Name for the colorteller, but you could change this to an incorrect SAN to see the same behavior as in step 2.

```bash
% curl $COLORAPP_ENDPOINT
yellow
```

The requests once again succeed.

> Note: As mentioned in step 4, typically you would configure your clients to provide a client certificate before requiring them on your server, so that connections continue to succeed as you migrate to mutual authentication.

At this point, you have mutual TLS authentication between the gateway and the application node. Both are providing a certificate, both are validating that certificate against a certificate authority, and both are validating that the SAN identity is one that is explicitly allowed.

### Part 3: Clean Up

If you want to keep the application running, you can do so, but this is the end of this walkthrough.
Run the following commands to clean up and tear down the resources that we’ve created.

```bash
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-service
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-cluster
aws ecr delete-repository --force --repository-name $COLOR_TELLER_IMAGE_NAME
aws ecr delete-repository --force --repository-name $ENVOY_IMAGE_NAME
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecr-repositories
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-vpc
```

> Note: Deletion of the `ecs-service` stack can sometimes fail on the first attempt, as the ECS instances may not be fully deregistered before CloudFormation attempts to delete the Cloud Map services. A retry of the delete should succeed.

Delete the mesh.

```bash
./mesh/mesh.sh down
```

And finally delete the certificates.

```bash
./src/tlsCertificates/cleanup.sh
```
