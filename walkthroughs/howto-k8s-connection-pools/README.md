
## Overview

In this walkthrough, we'll demonstrate the use of connection pools (circuit breaking) in AWS App Mesh with EKS.

Circuit breaking is a pattern designed to minimize the impact of failures, to prevent them from cascading and compounding, and to ensure end-to-end performance. Envoy provides a set of circuit breaking features by providing knobs to control quality of service. Connection Pool in App Mesh directly translates to the [Envoy's circuit breaking configuration](https://www.envoyproxy.io/docs/envoy/latest/api-v2/api/v2/cluster/circuit_breaker.proto). Connection pool limits the number of connections that an Envoy can concurrently establish with all the hosts in the upstream cluster. Connection pool in App Mesh is supported at the listener level and it is intended protect your local application from being overwhelmed with connections. Hence, this connection pool configuration is directly applied as circuit_breaker config to the local Envoy's ingress cluster that is talking to the local app.


## Prerequisites

1. [Walkthrough: App Mesh with EKS](../eks/)
2. Run the following to check the version of controller you are running.
```
kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1

v1.2.0
```

3. Install Docker. It is needed to build the demo application images.


## Step 1: Setup environment
1. Clone this repository and navigate to the walkthrough/howto-k8s-connection-pools folder, all commands will be ran from this location
2. **Your** account id:

```
    export AWS_ACCOUNT_ID=<your_account_id>
```

3. **Region** e.g. us-west-2

```
    export AWS_DEFAULT_REGION=us-west-2
```

## Step 2: Create a Mesh with connection pool enabled

Let's deploy the sample applications and mesh with connection pool at virtual gateway and virtual node. This will deploy one virtual gateway (`ingress-gw`) and two Virtual Nodes (and applications): `green` and `red`.

```

                                                                       +---------+
                                                                   +-->+  Green  |
                                                                   |   +---------+
+-----------+       +------------------+      +-----------------+  |
|  ingress  +------>+  virtualservice  +----->+  virtualrouter  +--+
+-----------+       +------------------+      +-----------------+  |
                                                                   |   +---------+
                                                                   +-->+   Red   |
                                                                       +---------+
```


```
./deploy.sh
```

```
kubectl get virtualnodes,virtualgateway,virtualrouter,virtualservice,pod -n howto-k8s-connection-pools

NAME                                ARN                                                                                                                           AGE
virtualnode.appmesh.k8s.aws/green   arn:aws:appmesh:us-west-2:123456789:mesh/howto-k8s-connection-pools/virtualNode/green_howto-k8s-connection-pools   49m
virtualnode.appmesh.k8s.aws/red     arn:aws:appmesh:us-west-2:123456789:mesh/howto-k8s-connection-pools/virtualNode/red_howto-k8s-connection-pools     49m

NAME                                        ARN                                                                                                                                   AGE
virtualgateway.appmesh.k8s.aws/ingress-gw   arn:aws:appmesh:us-west-2:123456789:mesh/howto-k8s-connection-pools/virtualGateway/ingress-gw_howto-k8s-connection-pools   49m

NAME                                        ARN                                                                                                                                   AGE
virtualrouter.appmesh.k8s.aws/color-paths   arn:aws:appmesh:us-west-2:123456789:mesh/howto-k8s-connection-pools/virtualRouter/color-paths_howto-k8s-connection-pools   49m

NAME                                         ARN                                                                                                                                                      AGE
virtualservice.appmesh.k8s.aws/color-paths   arn:aws:appmesh:us-west-2:123456789:mesh/howto-k8s-connection-pools/virtualService/color-paths.howto-k8s-connection-pools.svc.cluster.local   49m

NAME                              READY   STATUS    RESTARTS   AGE
pod/green-88f8c9c55-6grxc         2/2     Running   0          49m
pod/ingress-gw-8577b5d688-lg7vr   1/1     Running   0          49m
pod/red-847878f495-w7d9f          2/2     Running   0          49m
```

Connection pool circuit breaker is configured on the `green` virtual node and ingress-gw virtual gateway listeners:

```
kubectl describe virtualnode green -n howto-k8s-connection-pools

..
Spec:
  Aws Name:  green_howto-k8s-connection-pools
  Listeners:
    Connection Pool:
      Http:
        Max Connections:       10
        Max Pending Requests:  10
...


kubectl describe virtualgateway ingress-gw -n howto-k8s-connection-pools

...
Spec:
  Aws Name:  ingress-gw_howto-k8s-connection-pools
  Listeners:
    Connection Pool:
      Http:
        Max Connections:       5
        Max Pending Requests:  5
...

```

Let's check the connection pool configuration in AWS App Mesh
```
aws appmesh describe-virtual-node --virtual-node-name green_howto-k8s-connection-pools --mesh-name howto-k8s-connection-pools

{
    "virtualNode": {
        "meshName": "howto-k8s-connection-pools",
        "metadata": {
            "arn": "arn:aws:appmesh:us-west-2:123456789:mesh/howto-k8s-connection-pools/virtualNode/green_howto-k8s-connection-pools",
            "createdAt": 1603667107.741,
            "lastUpdatedAt": 1603668330.257,
            "meshOwner": "123456789",
            "resourceOwner": "123456789",
            "uid": "8d7708cc-609d-44ff-9568-e5bbe2d6f744",
            "version": 4
        },
        "spec": {
            "backends": [],
            "listeners": [
                {
                    "connectionPool": {
                        "http": {
                            "maxConnections": 10,
                            "maxPendingRequests": 10
                        }
                    },
                    "healthCheck": {
                        "healthyThreshold": 2,
                        "intervalMillis": 5000,
                        "path": "/ping",
                        "port": 8080,
                        "protocol": "http",
                        "timeoutMillis": 2000,
                        "unhealthyThreshold": 2
                    },
                    "portMapping": {
                        "port": 8080,
                        "protocol": "http"
                    }
                }
            ],
            "serviceDiscovery": {
                "dns": {
                    "hostname": "color-green.howto-k8s-connection-pools.svc.cluster.local"
                }
            }
        },
        "status": {
            "status": "ACTIVE"
        },
        "virtualNodeName": "green_howto-k8s-connection-pools"
    }
}


aws appmesh describe-virtual-gateway --virtual-gateway-name ingress-gw_howto-k8s-connection-pools --mesh-name howto-k8s-connection-pools

{
    "virtualGateway": {
        "meshName": "howto-k8s-connection-pools",
        "metadata": {
            "arn": "arn:aws:appmesh:us-west-2:123456789:mesh/howto-k8s-connection-pools/virtualGateway/ingress-gw_howto-k8s-connection-pools",
            "createdAt": 1603667107.705,
            "lastUpdatedAt": 1603668330.25,
            "meshOwner": "123456789",
            "resourceOwner": "123456789",
            "uid": "aa8a206e-aaa5-4980-8224-fca8416e0006",
            "version": 3
        },
        "spec": {
            "listeners": [
                {
                    "connectionPool": {
                        "http": {
                            "maxConnections": 5,
                            "maxPendingRequests": 5
                        }
                    },
                    "portMapping": {
                        "port": 8088,
                        "protocol": "http"
                    }
                }
            ]
        },
        "status": {
            "status": "ACTIVE"
        },
        "virtualGatewayName": "ingress-gw_howto-k8s-connection-pools"
    }
}

```

## Step 3: Verify connection pools and circuit breaking

Run fortio load in parallel and notice circuit breaker on the ingress-gw Envoy stats
```
FORTIO=$(kubectl get pod -l "app=fortio" --output=jsonpath={.items..metadata.name})
kubectl exec -it $FORTIO -- fortio load -c 10 -qps 100 -t 100s http://ingress-gw.howto-k8s-connection-pools/paths/red
```


Check the stats while fortio is sending requests
```
INGRESS_POD=$(kubectl get pod -l "app=ingress-gw" -n howto-k8s-connection-pools --output=jsonpath={.items..metadata.name})
kubectl exec -it $INGRESS_POD -n howto-k8s-connection-pools -- curl localhost:9901/stats | grep -E '(http.ingress.downstream_cx_active|upstream_cx_active|cx_open|upstream_cx_http1_total)'


cluster.cds_egress_howto-k8s-connection-pools_green_howto-k8s-connection-pools_http_8080.circuit_breakers.default.cx_open: 0
cluster.cds_egress_howto-k8s-connection-pools_green_howto-k8s-connection-pools_http_8080.circuit_breakers.high.cx_open: 0
cluster.cds_egress_howto-k8s-connection-pools_green_howto-k8s-connection-pools_http_8080.upstream_cx_active: 0
cluster.cds_egress_howto-k8s-connection-pools_green_howto-k8s-connection-pools_http_8080.upstream_cx_http1_total: 0
cluster.cds_egress_howto-k8s-connection-pools_red_howto-k8s-connection-pools_http_8080.circuit_breakers.default.cx_open: 0
cluster.cds_egress_howto-k8s-connection-pools_red_howto-k8s-connection-pools_http_8080.circuit_breakers.high.cx_open: 0
cluster.cds_egress_howto-k8s-connection-pools_red_howto-k8s-connection-pools_http_8080.upstream_cx_active: 5
cluster.cds_egress_howto-k8s-connection-pools_red_howto-k8s-connection-pools_http_8080.upstream_cx_http1_total: 5
cluster.cds_ingress_howto-k8s-connection-pools_ingress-gw_howto-k8s-connection-pools_self_redirect_http_15001.circuit_breakers.default.cx_open: 1
cluster.cds_ingress_howto-k8s-connection-pools_ingress-gw_howto-k8s-connection-pools_self_redirect_http_15001.circuit_breakers.high.cx_open: 0
cluster.cds_ingress_howto-k8s-connection-pools_ingress-gw_howto-k8s-connection-pools_self_redirect_http_15001.upstream_cx_active: 5
cluster.cds_ingress_howto-k8s-connection-pools_ingress-gw_howto-k8s-connection-pools_self_redirect_http_15001.upstream_cx_http1_total: 5
http.ingress.downstream_cx_active: 10

```

Notice that `downstream_cx_active` is 10, which matches the incoming connections from fortio. The `upstream_cx_active` connections for `ingress-gw` are 5 (max connections) and `cx_open` is 1, which means connection circuit breaker is open.
 


Now, let's send traffic to the virtual node `green` and notice similar behavior.

```
FORTIO=$(kubectl get pod -l "app=fortio" --output=jsonpath={.items..metadata.name})
kubectl exec -it $FORTIO -- fortio load -c 20 -qps 500 -t 100s http://color-green.howto-k8s-connection-pools:8080
```

Check the stats while fortio is sending requests
```
GREEN_POD=$(kubectl get pod -l "version=green" -n howto-k8s-connection-pools --output=jsonpath={.items..metadata.name})
kubectl exec -it $GREEN_POD -n howto-k8s-connection-pools -c app -- curl localhost:9901/stats | grep -E '(http.ingress.downstream_cx_active|upstream_cx_active|cx_open|upstream_cx_http1_total)'

cluster.cds_egress_howto-k8s-connection-pools_amazonaws.circuit_breakers.default.cx_open: 0
cluster.cds_egress_howto-k8s-connection-pools_amazonaws.circuit_breakers.high.cx_open: 0
cluster.cds_egress_howto-k8s-connection-pools_amazonaws.upstream_cx_active: 0
cluster.cds_egress_howto-k8s-connection-pools_amazonaws.upstream_cx_http1_total: 0
cluster.cds_ingress_howto-k8s-connection-pools_green_howto-k8s-connection-pools_http_8080.circuit_breakers.default.cx_open: 1
cluster.cds_ingress_howto-k8s-connection-pools_green_howto-k8s-connection-pools_http_8080.circuit_breakers.high.cx_open: 0
cluster.cds_ingress_howto-k8s-connection-pools_green_howto-k8s-connection-pools_http_8080.upstream_cx_active: 10
cluster.cds_ingress_howto-k8s-connection-pools_green_howto-k8s-connection-pools_http_8080.upstream_cx_http1_total: 663
http.ingress.downstream_cx_active: 20

```

Notice that `downstream_cx_active` is 20, which matches the incoming connections from fortio. The `upstream_cx_active` connections for `green` are 10 (max connections) and `cx_open` is 1, which means connection circuit breaker is open.

Also, we’ve set the maxConnection setting to an artificially low number to illustrate App Mesh connection pools and circuit breaking functionality. This is not a realistic setting but hopefully serves to illustrate the point.

## Step 4: Cleanup

If you want to keep the application running, you can do so, but this is the end of this walkthrough. Run the following commands to clean up and tear down the resources that we’ve created.

```bash
kubectl delete -f _output/manifest.yaml
```
