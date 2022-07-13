# Configuring TLS with AWS Certificate Manager

In this walkthrough we'll show you how to allow your application to connect to external API outside of your mesh. This walkthrough will be a simplified version of the [Color App Example](https://github.com/aws/aws-app-mesh-examples/tree/main/examples/apps/colorapp).

## Introduction

When using a service mesh, some services within the mesh might need to connect to external or open API's.

In App Mesh, we have two ways of doing that.

### 1. Set egress filter to ``ALLOW_ALL``

The first option is to set the [egress filter](https://docs.aws.amazon.com/app-mesh/latest/APIReference/API_EgressFilter.html) on the mesh resource to ``ALLOW_ALL``. This setting will allow any service within the mesh to communicate with any destination IP address inside or outside of the mesh.

### 2. Model the external service as a virtual service backed up by a virtual node

We can keep the egress filter as ``DROP_ALL`` which is default for a mesh and we need to model the external service as a virtual service backed up by a virtual node. Then virtual node itself needs to set its service discovery method to DNS with the hostname as the actual hostname of the external service. Note that if the external service's hostname can be resolved as an IPv6 address while your setup, e.g. VPC, doesn't support that, you need to set IP preference to ``IPv4_ONLY`` to stop envoy from trying to make IPv6 requests.

Let's jump into a brief example of App Mesh external traffic in action.

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
./src/colorteller_with_external_traffic/deploy.sh
```

Note that the example apps use go modules. If you have trouble accessing <https://proxy.golang.org> during the deployment you can override the GOPROXY by setting `GO_PROXY=direct`

```bash
GO_PROXY=direct ./src/colorteller_with_external_traffic/deploy.sh
```

## Step 2: Create a Mesh with external traffic support

This mesh will be a simplified version of the original Color App Example, so we'll only be deploying the gateway and one color teller service (white).

The external service can be modelled by a virtual service with virtual node as provider. The spec for virtual service looks like this:

```yaml
ExternalServiceVirtualService:
    Type: AWS::AppMesh::VirtualService
    Properties:
      MeshName: !GetAtt Mesh.MeshName
      VirtualServiceName: github.com
      Spec:
        Provider:
          VirtualNode:
            VirtualNodeName: !GetAtt ExternalServiceVirtualNode.VirtualNodeName
```

The spec for virtual node looks like this:
```yaml
ExternalServiceVirtualNode:
    Type: AWS::AppMesh::VirtualNode
    Properties:
      MeshName: !GetAtt Mesh.MeshName
      VirtualNodeName: ExternalService
      Spec:
        Listeners:
          - PortMapping:
              Port: 443
              Protocol: tcp
        ServiceDiscovery:
          DNS:
            Hostname: github.com
            IpPreference: IPv4_ONLY
```

Additionally, the virtual nodes associated with the application that will make the external requests should use the newly created virtual service, in this example it is ``ExternalServiceVirtualService``, as a backend. The spec for the virtual node associated with the application looks like this:

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
        Backends:
          - VirtualService:
              VirtualServiceName: !GetAtt ExternalServiceVirtualService.VirtualServiceName
        ServiceDiscovery:
          DNS:
            Hostname: !Sub "colorteller.${ServicesDomain}"
```

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
curl "${COLORAPP_ENDPOINT}/external"
```

You should see a successful response with homepage of GitHub. You can also access the link through your browser.

## Step 5: Clean Up

If you want to keep the application running, you can do so, but this is the end of this walkthrough.
Run the following commands to clean up and tear down the resources that we've created.

```bash
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-service
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecs-cluster
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-mesh
aws ecr delete-repository --force --repository-name colorteller
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-ecr-repositories
aws cloudformation delete-stack --stack-name $ENVIRONMENT_NAME-vpc
```
