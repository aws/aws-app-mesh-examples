# Getting Started

## Prerequisites
* Install latest [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/installing.html).

* Build and push the colorteller and gateway images using deploy.sh from within /examples/apps/colorapp/src/
* Configure aws-cli to support Appmesh APIs

```
export AWS_PROFILE=<aws-profile for aws-cli>
export AWS_DEFAULT_REGION=<aws-region for aws-cli>
```

* Export the following environment variables

```
export ENVIRONMENT_NAME=<friendlyname-for-stack e.g. AppMeshSample>
export MESH_NAME=<your-choice-of-mesh-name, e.g. default>
export KEY_PAIR_NAME=<key-pair to access ec2 instances where apps are running>
export ENVOY_IMAGE=<the latest recommended envoy image, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html>
export CLUSTER_SIZE=<number of ec2 instances to spin up to join cluster
export SERVICES_DOMAIN=<domain under which services will be discovered, e.g. "default.svc.cluster.local">
export COLOR_GATEWAY_IMAGE=<image location for colorapp's gateway, e.g. "<youraccountnumber>.dkr.ecr.amazonaws.com/gateway:latest" - you need to build this image and use your own ECR repository, see below>
export COLOR_TELLER_IMAGE=<image location for colorapp's teller, e.g. "<youraccountnumber>.dkr.ecr.amazonaws.com/colorteller:latest" - you need to build this image and use your own ECR repository, see below>
```

## ECS
Following steps will setup a VPC, Mesh, and ECS.

* Setup VPC

```
$ ./infrastructure/vpc.sh
```

* Setup Mesh

```
$ ./infrastructure/appmesh-mesh.sh
```

* Setup ECS Cluster (Optional if using EKS)

```
$ ./infrastructure/ecs-cluster.sh
```

## EKS
* See [Walkthrough: App Mesh with EKS](../walkthroughs/eks/).

## Apps
Once infrastructure is in place you can deploy applications and configure mesh. Go to corresponding application directory under ***apps/*** and follow the directions, e.g. *apps/colorapp*.

To add new app, create a directory under apps and follow the setup as in colorapp

## Building Docker Images

In Elastic Container Registry, created two new repositories:
 - colorteller
 - gateway

Build the docker images as follow:
```
cd apps/colorapp/src/colorteller/
./deploy.sh
cd -
cd apps/colorapp/src/gateway
./deploy.sh
cd -
```
NOTE: If you run into issues with certificate because GO PROXY server is not reachable, you can turn it off by setting the environment variable `GO_PROXY` as below and then build the docker images
```
export GO_PROXY=direct
```
