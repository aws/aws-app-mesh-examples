# Testing Header/Hostname Matching and Path/Prefix Rewrites

## Concepts

In this walkthrough we'll extend our existing [ColorApp](https://github.com/aws/aws-app-mesh-examples/tree/master/examples/apps/colorapp) example with a VirtualGateway resource and configure Header/Hostname Matching, Query Parameter and Prefix/Path Matching in Gateway Route and Route resources and Rewrites in Gateway Route resources.

- **GatewayRoute:** Gateway Routes allows specifying routing conditions that match the incoming request and determines the Virtual Service to redirect the request to. These conditions are specified as match conditions (`prefix` , `path`, `queryParameters`, `hostname` for HTTP/HTTP2 routes and `serviceName` and `hostname` for GRPC). A sample spec for the GatewayRoute is as follows:

	```json
	{
    "spec": {
        "httpRoute" : {
            "match" : {
                "prefix" : "/red",
                "queryParameters" : [{
                    "name" : "color",
                    "value" : {
                      "exact" : "red"
                    }
                 }],
                "hostname" : {
                   "exact" : "www.example.com"
                },
                "headers" : [{
                   "name" : "CACHE_CONTROL",
                   "match" :  {
                      "exact" : "no-cache" 
                   }
                }]
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
	A matched request by a gateway route is rewritten to the target Virtual Service's `hostname` and the matched prefix is rewritten to `/`, by default, or when default Prefix rewrite is `Enabled`. 
	Alternatively, you can specify a custom prefix to rewrite the matched prefix to, as well as specify configuration for matching/rewriting based on paths.
	Depending on how you configure your Virtual Service, it could then rely on a Virtual Router to route the request to different virtual nodes, based on specific prefixes or headers.
	
- **Routes**: A route is associated with a virtual router. The route is used to match requests for the virtual router and to distribute traffic to its associated virtual nodes. If a route matches a request, it can distribute traffic to one or more target virtual nodes. In this walkthrough, we will look at routes matching on `path`, `prefix`, `queryParameters` and `headers` in HTTP Routes. 
 
    A sample spec for Route is:
    
    ```
  {
  	"spec": {
  		"priority": 1,
  		"httpRoute": {
  			"action": {
  				"weightedTargets": [{
  					"virtualNode": "my-ingress-v2-node",
  					"weight": 1
  				}]
  			},
  			"match": {
  				"headers": [{
  					"name": "color_header",
  					"match": {
  						"prefix": "redoryellow"
  					}
  				}],
  				"prefix": "/",
  				"queryParameters": [{
  					"name": "color",
  					"match": {
  						"exact": "yellow"
  					}
  				}],
  			}
  		}
  	}
  }       
    ```
 

##Setup
For the Color App setup, we'll use an NLB to forward traffic to the Virtual Gateway (running a set of Envoys). We would configure 2 Gateway Routes - red and yellow pointing to 2 Virtual Services.

Let's now jump into the example.

## Step 1: Prerequisites

1. You'll need a keypair stored in AWS to access a bastion host. You can create a keypair using the command below if you don't have one. See [Amazon EC2 Key Pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html).

```bash
aws ec2 create-key-pair --key-name color-app-ingress-v2 | jq -r .KeyMaterial > ~/.ssh/color-app-ingress-v2.pem
chmod go-r ~/.ssh/color-app-ingress-v2.pem
```

This command creates an Amazon EC2 Key Pair with name `color-app-ingress-v2` and saves the private key at
`~/.ssh/color-app-ingress-v2.pem`.

2. Additionally, this walkthrough makes use of the unix command line utility `jq`. If you don't already have it, you can install it from [here](https://stedolan.github.io/jq/).

3. Install Docker. It is needed to build the demo application images.

## Step 2: Set Environment Variables
We need to set a few environment variables before provisioning the
infrastructure. Please change the value for `AWS_ACCOUNT_ID`, `KEY_PAIR_NAME`, and `ENVOY_IMAGE` below.

```bash
export AWS_ACCOUNT_ID=<your account id>
export ENVOY_IMAGE=<get the latest from https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html>
export KEY_PAIR_NAME=<color-app-ingress-v2 or your-keypair-name>
```

Set the following environment variables specific to the walkthrough:

```bash
export AWS_DEFAULT_REGION=us-west-2
export ENVIRONMENT_NAME=AppMeshIngressV2Example
export MESH_NAME=ColorApp-Ingress-V2
export SERVICES_DOMAIN="default.svc.cluster.local"
export COLOR_TELLER_IMAGE_NAME="howto-ingress-v2/colorteller"
export APPMESH_FRONTEND="https://frontend.us-west-2.gamma.lattice.aws.a2z.com"
export APPMESH_XDS_ENDPOINT="envoy-management.us-west-2.gamma.lattice.aws.a2z.com:443"
export APPMESH_SERVICE_MODEL=appmesh-ingress-v2
export ISENGARD_PROFILE=primary
```

## Step 3: Create Color App Infrastructure

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

## Step 4: Create a Mesh

This mesh is a variation of the original Color App Example, so we have two colorteller services all returning different colors (red and yellow). These VirtualNodes will be target for two VirtualServices which will be exposed to clients outside the mesh via colorgateway which is a VirtualGateway. Both the virtualServices will be routed from virtualGateway using two gatewayRoutes matching on different conditions. 

The spec for the VirtualGateway looks like this:

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
There are two HTTP GatewayRoutes attached to this VirtualGateway one for each VirtualService backend. One of the gatewayRoute will match on prefix `/red` and other will match on prefix `/yellow`. The spec for one of the GatewayRoutes is follows:

```json
{
"spec": {
    "httpRoute" : {
        "match" : {
            "prefix" : "red",
             "headers" : [{
                "name" : "Cache-Control",
                "match" : {
                    "exact" : "no-cache"
                 }
             }]
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
                        "virtualNode": "colorteller-red-vn",
                        "weight": 1
                    },
                    {
                        "virtualNode": "colorteller-yellow-vn",
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

## Step 5: Deploy and Verify (WIP FROM HERE)

###TODO from here
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

## Step 6: Clean Up

If you want to keep the application running, you can do so, but this is the end of this walkthrough.
Run the following commands to clean up and tear down the resources that we’ve created.

Delete the CloudFormation stacks:

```bash
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-service
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-cluster
aws ecr delete-repository --force --repository-name $COLOR_TELLER_IMAGE_NAME
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecr-repositories
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-vpc
```
Delete the Mesh:

```bash
./mesh/mesh.sh down
```
