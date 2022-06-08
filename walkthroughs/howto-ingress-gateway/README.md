# Configuring Ingress Gateway

In this walkthrough we'll configure an Ingress Gateway in our existing [ColorApp](https://github.com/aws/aws-app-mesh-examples/tree/main/examples/apps/colorapp) example but with a VirtualGateway resource to configure the ColorGateway instead of a VirtualNode.

## Introduction

A virtual gateway allows resources outside your mesh to communicate to resources that are inside your mesh. The virtual gateway represents an Envoy proxy running in an Amazon ECS, in a Kubernetes service, or on an Amazon EC2 instance. Unlike a virtual node, which represents a proxy running with an application, a virtual gateway represents the proxy deployed by itself.

- **VirtualGateway:** The Virtual Gateway has a listener on which the incoming traffic is accepted. As part of the listener, we can also configure the gateway to terminate TLS, specify health check policy. It also supports encrypting traffic by initiating TLS at the Virtual Gateway when communicating to the target Virtual Nodes as part of `backendDefaults`. A sample spec for the VirtualGateway is as follows:

	```json
	{
		"spec": {
			"listeners": [{
				"portMapping": {
					"port": 9080,
					"protocol": "http"
				},
				"tls": {
					"mode": "STRICT",
					"certificate": {
						"acm": {
							"certificateArn": $CERTIFICATE_ARN
						}
					}
				}
			}],
			"backendDefaults": {
				"clientPolicy": {
					"tls": {
						"validation": {
							"trust": {
								"acm": {
									"certificateAuthorityArns": [
										$ROOT_CA_ARN
									]
								}
							}
						}
					}
				}
			}
		}
	}
	```
	Here, Mode determines whether or not TLS is negotiated on this Virtual Node:
	- STRICT- TLS is required.
	- PERMISSIVE- TLS is optional (plain-text allowed).
	- DISABLED- TLS is disabled (plain-text only).

	BackendDefaults settings are applied to all backends with ClientPolicy being policy for how to handle traffic with backends (i.e. from the client perspective).

	- TLS determines whether or not TLS is negotiated, and how.
	- Validation determines how to validate a certificate offered by a backend.
	- Trust is the trust bundle (i.e. set of root certificate authorities) used to validate the certificate offered by a backend. Certificates signed by one of these certificate authorities are considered valid.

- **GatewayRoute:** Gateway Routes allows specifying routing conditions that match the incoming request and determines the Virtual Service to redirect the request to. These conditions are specified as match conditions (`prefix` for HTTP/HTTP2 routes and `serviceName` for GRPC). A sample spec for the GatewayRoute is as follows:

	```json
	{
    "spec": {
        "httpRoute" : {
            "match" : {
                "prefix" : "/color1"
            },
            "action" : {
                "target" : {
                    "virtualService": {
                        "virtualServiceName": $VIRTUALSERVICE_NAME
                    }
                }
            }
        }
    }
	}
	```
	A matched request by a gateway route is rewritten to the target Virtual Service's `hostname` and the matched prefix is rewritten to `/`, by default. Depending on how you configure your Virtual Service, it could then rely on a Virtual Router to route the request to different virtual nodes, based on specific prefixes or headers.

## ColorApp Setup
For the Color App setup, we'll use an NLB to forward traffic to the Virtual Gateway (running a set of Envoys). The Gateway will be configured to terminate TLS for the incoming traffic. We would configure 2 Gateway Routes - color1 and color2 pointing to 2 Virtual Services (backed by 2 Virtual Nodes each). Initially we will set up the flow without TLS between Virtual Gateway and Virtual Nodes and later in the example, we would modify the Client Policy at the Gateway to enforce TLS initiation. Hence, at the end of this exercise, the flow would be:

```
Internet --> (terminate TLS) NLB (originate TLS) --> (terminate TLS) Gateway (originate TLS) --> (terminate TLS) Virtual Nodes
```

![System Diagram](./howto-ingress-gateway.png "System Diagram")

 Let's now jump into an example of App Mesh Ingress in action.

## Step 1: Prerequisites

1. You'll need a keypair stored in AWS to access a bastion host. You can create a keypair using the command below if you don't have one. See [Amazon EC2 Key Pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html).

```bash
aws ec2 create-key-pair --key-name color-app | jq -r .KeyMaterial > ~/.ssh/color-app.pem
chmod 400 ~/.ssh/color-app.pem
```

This command creates an Amazon EC2 Key Pair with name `color-app` and saves the private key at
`~/.ssh/color-app.pem`.

2. Additionally, this walkthrough makes use of the unix command line utility `jq`. If you don't already have it, you can install it from [here](https://stedolan.github.io/jq/).

3. Install Docker. It is needed to build the demo application images.

## Step 2: Set Environment Variables
We need to set a few environment variables before provisioning the
infrastructure. Please change the value for `AWS_ACCOUNT_ID`, `KEY_PAIR_NAME`, and `ENVOY_IMAGE` below.

```bash
export AWS_ACCOUNT_ID=<your account id>
export KEY_PAIR_NAME=<color-app or your SSH key pair stored in AWS>
export AWS_DEFAULT_REGION=us-west-2
export ENVIRONMENT_NAME=AppMeshIngressExample
export MESH_NAME=ColorApp-Ingress
export ENVOY_IMAGE=<get the latest from https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html>
export SERVICES_DOMAIN="default.svc.cluster.local"
export COLOR_TELLER_IMAGE_NAME="howto-ingress/colorteller"
```

## Step 3: Generate Certificate from ACM

Before we can encrypt traffic between NLB --> VirtualGateway and VirtualGateway --> VirtualNodes, we need to generate a certificate. App Mesh currently supports certificates issued by an ACM Private Certificate Authority, which we'll setup in this step. We'll use this ACM certificate to terminate TLS at the NLB, the VirtualGateway and the target VirtualNodes.

Refer [Configuring TLS with AWS Certificate Manager](https://github.com/aws/aws-app-mesh-examples/tree/main/walkthroughs/tls-with-acm) walkthrough for information about what permissions does the IAM role used by Envoy need in order to retrieve a certificate and private key from ACM and retrieve a Certificate Authority Certificate.

Start by creating a root certificate authority (CA) in ACM.

>You pay a monthly fee for the operation of each AWS Certificate Manager Private Certificate Authority until you delete it and you pay for the private certificates you issue each month. For more information, see [AWS Certificate Manager Pricing](https://aws.amazon.com/certificate-manager/pricing/).

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
        OrganizationalUnit=Ingress Example,
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

## Step 4: Create Color App Infrastructure

We'll start by setting up the basic infrastructure for our services. All commands will be provided as if run from the same directory as this README.

First, create the VPC.

```bash
./infrastructure/vpc.sh
```

Next, create the ECS cluster and ECR repositories.

```bash
./infrastructure/ecs-cluster.sh
./infrastructure/ecr-repositories.sh
```

Finally, build and deploy the colorteller image.

```bash
./src/colorteller/deploy.sh
```
Note that the example app uses go modules. If you have trouble accessing https://proxy.golang.org during the deployment you can override the GOPROXY by setting `GO_PROXY=direct`

```bash
GO_PROXY=direct ./src/colorteller/deploy.sh
```

## Step 5: Create a Mesh

This mesh is a variation of the original Color App Example, so we have four colorteller services all returning different colors (white, blue, red and black). These VirtualNodes will be target for two VirtualServices which will be exposed to clients outside the mesh via colorgateway which is a VirtualGateway. Both the virtualServices will be routed from virtualGateway using two gatewayRoutes matching on different prefixes. The spec for the VirtualGateway looks like this:

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
    ]
  }
}
```
There are two HTTP GatewayRoutes attached to this VirtualGateway one for each VirtualService backend. One of the gatewayRoute will match on prefix `/color1` and other will match on prefix `/color2`. The spec for one of the GatewayRoutes is follows:

```json
{
"spec": {
    "httpRoute" : {
        "match" : {
            "prefix" : "/color1"
        },
        "action" : {
            "target" : {
                "virtualService": {
                    "virtualServiceName": "colorteller-1.${SERVICES_DOMAIN}"
                }
            }
        }
    }
}
}
```
Both the VirtualServices are provided by a VirtualRouter which routes the traffic matching on prefix `/tell` to equal weight target VirtualNodes. The spec for one of the service route is as follows:

```json
{
    "spec": {
        "httpRoute": {
            "action": {
                "weightedTargets": [
                    {
                        "virtualNode": "colorteller-white-vn",
                        "weight": 1
                    },
                    {
                        "virtualNode": "colorteller-blue-vn",
                        "weight": 1
                    }
                ]
            },
            "match": {
                "prefix": "/tell"
            }
        }
    }
}
```

Let's create the mesh.

```bash
./mesh/mesh.sh up
```

## Step 6: Deploy and Verify

Our next step is to deploy the service in ECS and test it out.

```bash
./infrastructure/ecs-service.sh
```

1. After a few minutes, the applications should be deployed and you will see an output such as:

	```bash
	Successfully created/updated stack - ${ENVIRONMENT_NAME}-ecs-service
	Bastion endpoint:
	12.345.6.789
	ColorApp endpoint:
	http://howto-Publi-55555555.us-west-2.elb.amazonaws.com
	```
	> **Note:** Since, we have enabled TLS termination at the NLB, we'll use `https` in our curl requests and use `-k` option to accept the cert without validation.

	Export the public endpoint to access the gateway replacing `http` with `https` (e.g., above returned url will be changed to `https://howto-Publi-55555555.us-west-2.elb.amazonaws.com`).

	```bash
	export COLORAPP_ENDPOINT=<your_https_colorApp_endpoint e.g. https://howto-Publi-55555555.us-west-2.elb.amazonaws.com>
	```
	And export the bastion endpoint for use later.

	```bash
	export BASTION_IP=<your_bastion_endpoint e.g. 12.245.6.189>
	```

2. Let's issue a request to the color gateway with gatewayRoute prefix as `/color1` and backend service route prefix as `/tell`.

	```bash
	curl -k "${COLORAPP_ENDPOINT}/color1/tell"
	```
	If you run above command several time you should see successful `white` and `blue` responses back from `colorteller-white-vn` and `colorteller-blue-vn` virtualNodes respectively. These are both the targets for `colorteller-2.${SERVICES_DOMAIN}` VirtualService.

	Similarly, let's issue a request to the gateway with gatewayRoute prefix as `/color2` and backend service route prefix as `/tell`.

	```bash
	curl -k "${COLORAPP_ENDPOINT}/color2/tell"
	```
	In this case, you should receive `black` and `red` responses back from targets of `colorteller-2.${SERVICES_DOMAIN}` VirtualService.

3. Now let's log in to the bastion host and see ssl handshake stats for the gateway envoy.

	```bash
	ssh -i <key_pair_location> ec2-user@$BASTION_IP
	```
	We'll curl Envoy's stats endpoint to verify ssl handshake (replace default.svc.cluster.local in the below command with the value of $SERVICES_DOMAIN environment variable)

	```bash
	curl -s http://colorgateway.default.svc.cluster.local:9901/stats | grep ssl.handshake
	```
You should see output similar to: `listener.0.0.0.0_9080.ssl.handshake: 1`, indicating a successful SSL handshake was achieved between the NLB and the gateway. At this point the traffic from NLB to the VirtualGateway is encrypted while the traffic from VirtualGateway to VirtualNodes is not.

## Step 7: Initiate TLS at the Gateway

We'll now be encrypting traffic from the colorgateway to the colorteller white VirtualNode. Our colorteller white will be terminating TLS with a certificate provided by ACM. The spec looks like this:

```json
{
    "spec": {
          "listeners": [
             {
                "healthCheck": {
                   "healthyThreshold": 2,
                   "intervalMillis": 5000,
                   "path": "/ping",
                   "protocol": "http",
                   "timeoutMillis": 2000,
                   "unhealthyThreshold": 2
                },
                "portMapping": {
                   "port": 9080,
                   "protocol": "http"
                },
                "tls": {
                    "mode": "STRICT",
                    "certificate": {
                        "acm": {
                            "certificateArn": $CERTIFICATE_ARN
                        }
                    }
                }
             }
          ],
          "serviceDiscovery": {
             "dns": {
                "hostname": $DNS_HOSTNAME
             }
          }
    }
}
```
Additionally, the VirtualGateway will be configured to validate the certificate of the colorteller node by specifying the CA that issued it. The spec for colorgateway looks like this:

```json
{
	"spec": {
		"listeners": [{
			"portMapping": {
				"port": 9080,
				"protocol": "http"
			},
			"tls": {
				"mode": "STRICT",
				"certificate": {
					"acm": {
						"certificateArn": $CERTIFICATE_ARN
					}
				}
			}
		}],
		"backendDefaults": {
			"clientPolicy": {
				"tls": {
					"validation": {
						"trust": {
							"acm": {
								"certificateAuthorityArns": [
									$ROOT_CA_ARN
								]
							}
						}
					}
				}
			}
		}
	}
}
```
Let's update the `colorteller-white-vn` VirtualNode and `colorgateway-vg` VirtualGateway:

```bash
./mesh/mesh.sh partial_tls_up
```

### Verify TLS
Issue a request to the color gateway with prefix `/color1` to get encrypted response from `colorteller-white-vn`.

```bash
curl -k "${COLORAPP_ENDPOINT}/color1/tell"
```
If you run above command several times, you should see successful `white` response from only the `colorteller-white-vn` virtual node and a connection error as below for the `colorteller-blue-vn` virtual node.

```
upstream connect error or disconnect/reset before headers. reset reason: connection failure%
```
Similarly, try to curl `colorteller-black-vn` and `colorteller-red-vn` virtualNodes and verify we get a connection error as these virtualNodes don't have tls configuration at the listener.

```bash
curl -k "${COLORAPP_ENDPOINT}/color2/tell"
```

Now, we'll enable TLS at the listener of other colorteller nodes too. Run the following commands to enable TLS at listener for `colorteller-blue-vn`, `colorteller-black-vn` and `colorteller-red-vn`.

```bash
./mesh/mesh.sh full_tls_up
```

Now again let's send curl requests to all colortellers to verify that the encrypted traffic flows between all the virtualNodes and the virtualGateway.

```bash
curl -k "${COLORAPP_ENDPOINT}/color1/tell"
curl -k "${COLORAPP_ENDPOINT}/color2/tell"
```

Finally, let's log in to the bastion host again and check the SSL handshake statistics for the gateway envoy.

```bash
ssh -i <key_pair_location> ec2-user@$BASTION_IP
```
We'll curl Envoy's stats endpoint to verify ssl handshake (replace default.svc.cluster.local in the below command with the value of $SERVICES_DOMAIN environment variable)

```bash
curl -s http://colorgateway.default.svc.cluster.local:9901/stats | grep ssl.handshake
```
You should see output similar to following, indicating a successful SSL handshake was achieved between the gateway and the colorteller nodes:

```bash
cluster.cds_egress_New-ColorApp-Ingress_colorteller-black-vn_http_9080.ssl.handshake: 3
cluster.cds_egress_New-ColorApp-Ingress_colorteller-blue-vn_http_9080.ssl.handshake: 3
cluster.cds_egress_New-ColorApp-Ingress_colorteller-red-vn_http_9080.ssl.handshake: 3
cluster.cds_egress_New-ColorApp-Ingress_colorteller-white-vn_http_9080.ssl.handshake: 5
listener.0.0.0.0_9080.ssl.handshake: 60
```

That's it! We've encrypted traffic from our gateway to our colorteller nodes using a certificate from ACM.

## Step 9: Clean Up

If you want to keep the application running, you can do so, but this is the end of this walkthrough.
Run the following commands to clean up and tear down the resources that we’ve created.

Delete the CloudFormation stacks:

```bash
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-service
aws cloudformation wait stack-delete-complete --stack-name $ENVIRONMENT_NAME-ecs-service
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-cluster
aws cloudformation wait stack-delete-complete --stack-name $ENVIRONMENT_NAME-ecs-cluster
aws ecr delete-repository --force --repository-name $COLOR_TELLER_IMAGE_NAME
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecr-repositories
aws cloudformation wait stack-delete-complete --stack-name $ENVIRONMENT_NAME-ecr-repositories
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-vpc
aws cloudformation wait stack-delete-complete --stack-name $ENVIRONMENT_NAME-vpc
```
Delete the Mesh:

```bash
./mesh/mesh.sh down
```
And finally delete the certificates.

```bash
aws acm delete-certificate --certificate-arn $CERTIFICATE_ARN
aws acm-pca update-certificate-authority --certificate-authority-arn $ROOT_CA_ARN --status DISABLED
aws acm-pca delete-certificate-authority --certificate-authority-arn $ROOT_CA_ARN
```
