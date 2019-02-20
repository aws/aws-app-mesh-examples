# Overview
Voting App

## Setup

### Prerequisites
Following steps assume you have a functional VPC, ECS-Cluster and Mesh. If not follow the steps under ***infrastructure***. And have the following environment variables set

```
export AWS_PROFILE=<...>
export AWS_REGION=<...>
export ENVIRONMENT_NAME=<...>
export MESH_NAME=<...>
```

### Steps

* Setup virtual-nodes, virtual-router and routes for app service mesh

```
$ ./servicemesh/deploy.sh
```

* Deploy app to ECS

```
$ ./ecs/ecs-voteapp.sh
```

* Verify by doing a curl on the web service

```
<ec2-bastion-host>$ curl -s http://web.default.svc.cluster.local:9080/results
```

* Configure Grafana (optional)

If you want to use Grafana to visualize metrics from Envoy run

```
$ ./ecs/update-targetgroups.sh 
```

This will register the IP address of the task running Grafana and Prometheus 
with their respective target groups.  When finished, you should be able to access 
Grafana from http://<load_balancer_dns_name>:3000.  To configure Grafana, follow 
the instructions in the [README](./metrics/README.md).

* Use X-Ray to trace requests between services (optional)

For further information about how to use X-Ray to trace requests as they are routed 
between different services, see the [README](../../../../observability/x-ray.md).
