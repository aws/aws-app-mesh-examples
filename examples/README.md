# Getting Started

## Prerequisites
* Install latest [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/installing.html).

* Configure aws-cli to support Appmesh APIs. Download latest [model](https://devcentral.amazon.com/ac/brazil/package-master/package/view/AWSAppmeshFrontendServiceModel%3B1.0.179.0%3BAL2012%3BDEV.STD.PTHREAD%3Bmodel/appmesh-2018-10-01.json).

```
$ curl https://devcentral.amazon.com/ac/brazil/package-master/package/view/AWSAppmeshFrontendServiceModel%3B1.0.179.0%3BAL2012%3BDEV.STD.PTHREAD%3Bmodel/appmesh-2018-10-01.json -o appmesh-2018-10-01.json -s
$ aws configure add-model --service-name appmesh --service-model file://./appmesh-2018-10-01.json
```

* Export the following environment variables

```
export AWS_PROFILE=<aws-profile for aws-cli>
export AWS_REGION=<aws-region for aws-cli>
export AWS_DEFAULT_REGION="$AWS_REGION"
export APPMESH_FRONTEND=https://frontend.us-west-2.gamma.appmesh.aws.a2z.com/
export ENVIRONMENT_NAME=<friendlyname-for-stack e.g. AppmeshSample>
export MESH_NAME=<your-choice-of-mesh-name, e.g. default>
export KEY_PAIR_NAME=<key-pair to access ec2 instances where apps are running>
export APPMESH_XDS_ENDPOINT=<optional if you want to use a different endpoint for EMS>
export ENVOY_IMAGE="111345817488.dkr.ecr.us-west-2.amazonaws.com/aws-appmesh-envoy:v1.8.0.2-beta"
export CLUSTER_SIZE=<number of ec2 instances to spin up to join cluster
export SERVICES_DOMAIN=<domain under which services will be discovered, e.g. "default.svc.cluster.local">
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
