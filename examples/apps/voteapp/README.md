# Vote App

The Vote App is a simple application to demonstrate microservices running under App Mesh.
It is based on the original Docker version (see [ATTRIBUTION]).

![Vote App architecture]

To learn more about the project repo, see this [orientation].

## Quick Start

### Prerequisites

Before deploying the Vote App, you will need a functional VPC,
ECS cluster, and service mesh.

Bash scripts and CloudFormation stack templates are provided under the
`config` directory to create the necessary resources to run the
Vote App.

The following environment variables must be exported before running the
scripts:

```
# The prefix to use for created stack resources
export ENVIRONMENT_NAME=mesh-demo

# The AWS CLI profile (can specify "default")
export AWS_PROFILE="tony"

# The AWS region to deploy to; valid regions during preview:
# us-west-2 | us-east-1 | us-east-2 | eu-west-1
export AWS_REGION="us-west-2"
export KEY_PAIR_NAME="my-key-pair"

# The name to use for your app mesh 
export MESH_NAME="default"

# The domain to use for service discovery
export SERVICES_DOMAIN="${MESH_NAME}.svc.cluster.local"

# Optional: the number of physical nodes (EC2 instances) to join the
# ECS cluster (the default is 5)
export CLUSTER_SIZE=5
```


#### 1. Deploy VPC

```
$ .config/infrastructure/vpc.sh
```


#### 2. Deploy Mesh

This step will set up the necessary app mesh resources (virtual nodes,
virtual routers, and routes)..

To perform this step, you will first need to install the latest version of
the [AWS CLI].


```
$ .config/appmesh/deploy-mesh.sh 
```


#### 3. Deploy ECS Cluster

```
$ ./infrastructure/ecs-cluster.sh
```


### Deploy the Vote App


```
$ .config/ecs/ecs-voteapp.sh
```

* Verify by doing a curl on the web service

```
<ec2-bastion-host>$ curl -s http://web.default.svc.cluster.local:9080/results
```

#### CloudWatch

#### X-Ray

Use X-Ray to trace requests between services (optional).

For further information about how to use X-Ray to trace requests as they are routed 
between different services, see the [README](./observability/x-ray.md).


#### Configure Grafana for Prometheus (optional).

If you want to use Grafana to visualize metrics from Envoy run

```
$ .config/ecs/update-targetgroups.sh 
```

This will register the IP address of the task running Grafana and Prometheus 
with their respective target groups.  When finished, you should be able to access 
Grafana from http://<load_balancer_dns_name>:3000.  To configure Grafana, follow 
the instructions in the [README](./config/metrics/README.md).


[ATTRIBUTION]:            ../../../ATTRIBUTION
[orientation]:            http://bit.ly/vote-app-orientation
[AWS CLI]:                https://docs.aws.amazon.com/cli/latest/userguide/installing.html
[deploy with Fargate]:    https://read.acloud.guru/deploy-the-voting-app-to-aws-ecs-with-fargate-cb75f226408f
[Vote App architecture]:  ./images/voting-app-arch-3.png
[LICENSE]:                ../../../LICENSE

