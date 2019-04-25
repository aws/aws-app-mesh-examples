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
export ENVOY_IMAGE="111345817488.dkr.ecr.us-west-2.amazonaws.com/aws-appmesh-envoy:v1.9.0.0-prod"
export CLUSTER_SIZE=<number of ec2 instances to spin up to join cluster
export SERVICES_DOMAIN=<domain under which services will be discovered, e.g. "default.svc.cluster.local">
export COLOR_GATEWAY_IMAGE=<image location for colorapp's gateway, e.g. "<youraccountnumber>.dkr.ecr.amazonaws.com/gateway:latest" - you need to build this image and use your own ECR repository, see below>
export COLOR_TELLER_IMAGE=<image location for colorapp's teller, e.g. "<youraccountnumber>.dkr.ecr.amazonaws.com/colorteller:latest" - you need to build this image and use your own ECR repository, see below>
export STATSD_IMAGE=<image location for statsd sidecar, e.g. "<youraccountnumber>.dkr.ecr.amazonaws.com/statsd:latest" - you need to build this image and use your own ECR repository, see below>
```

## Infrastructure
Before we can start playing with mesh examples we need to setup infrastructure pieces. Following steps will setup a VPC, Mesh, and ECS or EKS.

* Setup VPC

```
$ ./infrastructure/vpc.sh
```

* Setup Mesh

```
$ ./infrastructure/appmesh-mesh.sh
```

* Setup ECS Cluster (Optional if using ECS)

```
$ ./infrastructure/ecs-cluster.sh
```

* Setup EKS Cluster (Optional if using EKS). Note that there are more steps to use Kubernetes cluster that are not covered here. Please follow [EKS Getting Started Guide](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html). See also the [Walkthrough: App Mesh with EKS](../walkthroughs/eks/) for other options.

```
$ ./infrastructure/eks-cluster.sh
```

## Apps
Once infrastructure is in place you can deploy applications and configure mesh. Go to corresponding application directory under ***apps/*** and follow the directions, e.g. *apps/colorapp*.

To add new app, create a directory under apps and follow the setup as in colorapp

## Building Docker Images

In Elastic Container Registry, created two new repositories:
 - colorteller
 - gateway

Build the docker images as follow:
```
cd apps/colorapp/src/statsd
./deploy.sh
cd -
cd apps/colorapp/src/colorteller/
./deploy.sh
cd -
cd apps/colorapp/src/gateway
./deploy.sh
cd -
```
