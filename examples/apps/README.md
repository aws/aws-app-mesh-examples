# Overview
A simple app to show case traffic-routing when used with AWS App Mesh. This app has two services *color-gateway* and *color-teller*. Though below we talk about ECS, it works similarly in EKS.

### ColorGateway
__color-gateway__ is a simple http service written in go that is exposed to external clients and responds to http://service-name:port/color that responds with color retrieved from color-teller and histogram of colors observed at the server that responded so far. For e.g.

```
$ curl -s http://colorgateway.default.svc.cluster.local:9080/color
{"color":"blue", "stats": {"blue":"1"}}

... after many such calls ...
$ curl -s http://colorgateway.default.svc.cluster.local:9080/color
{"color":"blue", "stats": {"black":494,"blue":2480,"red":36}}
```

color-gateway app runs as a service in ECS, optionally exposed via external load-balancer (ALB). Each task in gateway is configured with the endpoint of color-teller service that it communicates with via Envoy that is configured by AWS App Mesh.

### ColorTeller
__color-teller__ is a simple http service written in go that is configured to return a color. This configuration is provided as environment variable and is run within a task along with Envoy. Multiple versions of this service are deployed each configured to return a specific color. 

## Setup

### Prerequisites
Following steps assume you have a functional VPC, ECS-Cluster and Mesh. If not follow the steps under ***infrastructure***. And have the following environment variables set

```
export AWS_PROFILE=<aws-profile for aws-cli>
export AWS_REGION=<aws-region for aws-cli>
export AWS_DEFAULT_REGION="$AWS_REGION"
export APPMESH_FRONTEND=<...>
export ENVIRONMENT_NAME=<friendlyname-for-stack e.g. AppmeshSample>
export MESH_NAME=<your-choice-of-mesh-name, e.g. default>
export KEY_PAIR_NAME=<key-pair to access ec2 instances where apps are running>
export ENVOY_IMAGE=<...>
export CLUSTER_SIZE=<number of ec2 instances to spin up to join cluster
export SERVICES_DOMAIN=<domain under which services will be discovered, e.g. "default.svc.cluster.local">
```

### Steps

* Setup virtual-nodes, virtual-router and routes for color-app

```
$ ./servicemesh/deploy.sh
```

* Deploy color-teller and color-gateway to ECS

```
$ ./ecs/ecs-colorapp.sh
```

* Verify by doing a curl on color-gateway

```
<ec2-bastion-host>$ curl -s http://colorgateway.${SERVICES_DOMAIN}:9080/color
```

### Development

To change the app code please look into ***src***
