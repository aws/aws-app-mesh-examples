# Getting Started

## Prerequisites
* Install latest [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/installing.html).

* Build and push the colorteller and gateway images using deploy.sh from within /examples/apps/colorapp/src/
* Configure aws-cli to support Appmesh APIs

```
export AWS_PROFILE=<aws-profile for aws-cli>
export AWS_REGION=<aws-region for aws-cli>
export AWS_DEFAULT_REGION="$AWS_REGION"
```

* Export the following environment variables

```
export ENVIRONMENT_NAME=<friendlyname-for-stack e.g. AppMeshSample>
export MESH_NAME=<your-choice-of-mesh-name, e.g. default>
export KEY_PAIR_NAME=<key-pair to access ec2 instances where apps are running>
export ENVOY_IMAGE="111345817488.dkr.ecr.us-west-2.amazonaws.com/aws-appmesh-envoy:v1.8.0.2-beta"
export CLUSTER_SIZE=<number of ec2 instances to spin up to join cluster
export SERVICES_DOMAIN=<domain under which services will be discovered, e.g. "default.svc.cluster.local">
export COLOR_GATEWAY_IMAGE=<image location for colorapp's gateway, e.g. "123.dkr.ecr.amazonaws.com/gateway:latest">
export COLOR_TELLER_IMAGE=<image location for colorapp's teller, e.g. "123.dkr.ecr.amazonaws.com/colorteller:latest">
```

## Infrastructure
Before we can start playing with mesh examples we need to setup infrastructure pieces. Following steps will setup a VPC, Mesh, and ECS or EKS. 

* Setup VPC

```
$ ./infrastructure/vpc.sh create-stack
```

* Setup Mesh

```
$ ./infrastructure/mesh.sh create-mesh
```

* Setup ECS Cluster (Optional if using ECS)

```
$ ./infrastructure/ecs-cluster.sh create-stack
```

* Setup EKS Cluster (Optional if using EKS). Note that there are more steps to use Kubernetes cluster that are not covered here. Please follow [EKS Getting Started Guide](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html).

```
$ ./infrastructure/eks-cluster.sh create-stack
```

## Apps
Once infrastructure is in place you can deploy applications and configure mesh. Go to corresponding application directory under ***apps/*** and follow the directions, e.g. *apps/colorapp*.

To add new app, create a directory under apps and follow the setup as in colorapp
