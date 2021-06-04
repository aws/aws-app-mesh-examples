
# Configuring Outlier Detection

This walkthrough demonstrates the usage of App Mesh's Outlier Detection feature. Clone this repo and navigate to `aws-app-mesh-examples/walkthroughs/howto-outlier-detection` to get started!

## Introduction

Outlier Detection is a form of passive health check that temporarily ejects an endpoint/host of a given service (represented by a Virtual Node) from the load balancing set when it meets some failure threshold (hence considered an *outlier*). App Mesh currently supports the definition of an outlier using the number of server errors (any 5xx Http response- or the equivalent for gRPC and TCP connections) a given endpoint has returned within a given time interval. With Outlier Detection, intermittent failures caused by degraded hosts can be mitigated as the degraded host is no longer a candidate during load balancing- some may also recognize this design pattern under the term circuit breaking. An ejected endpoint is eventually returned to the load balancing set, and each time the same endpoint gets ejected, the longer it stays ejected.

In the App Mesh API, we define Outlier Detection on the server side; that is, the service defines the criteria for its hosts to be considered an outlier. Therefore, Outlier Detection should be defined in the Virtual Node representing the service alongside active health checks. The current implementation of App Mesh's Outlier Detection is based on Envoy's [Outlier Detection](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/outlier#arch-overview-outlier-detection).

Here are the necessary fields to configure Outlier Detection:

- **Interval**: the time between each Outlier Detection sweep. During the sweep is when hosts get ejected or returned to the load balancing set (un-ejected).

- **MaxServerErrors**: the threshold for the number of server errors returned by a given endpoint during an outlier detection interval. If the server error count is greater than or equal to this threshold the host is ejected. A server error is defined as any HTTP 5xx response (or the equivalent for gRPC and TCP connections).

- **BaseEjectionDuration**: The amount of time an outlier host is ejected for is `baseEjectionDuration * number of times this specific host has been ejected`. For example, if baseEjectionDuration is 30 seconds, an outlier host A would first be ejected for 30 seconds and returned to the load balancing set on the next following sweep. If host A later gets ejected again, it will be removed from the load balancing set for `30 seconds * 2 (this host is being ejected the second time) = 1 minute`.

- **MaxEjectionPercent**: The threshold for the max percentage of outlier hosts that can be ejected from the load balancing set. maxEjectionPercent=100 means outlier detection can potentially eject all of the hosts from the upstream service if they are all considered outliers, leaving the load balancing set with zero hosts. In reality, due to a default panic behavior in Envoy, if more than 50% of the endpoints behind a service are considered outliers or are failing health checks, the outlier detection ejection is overturned and traffic will be served to these degraded endpoints. We will cover this in [Panic and Ignore Outlier Detection](https://github.com/rexnp/aws-app-mesh-examples/tree/preview-outlier-detection/walkthroughs/howto-outlier-detection#panic-and-ignore-outlier-detection).

## Step 1: Prerequisites

1. You have version 1.18.172 or higher of the [AWS CLI v1](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv1.html) installed or you have version 2.0.62 or higher of the [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) installed.

2. To take a closer look at the related Envoy statistics for outlier detection, we will launch and SSH into a bastion host within the same VPC as the mesh to access the Envoy admin endpoint. Therefore we need an EC2 keypair for the bastion instance.
You can create a keypair using the command below if you don't already have one. Otherwise follow export the key pair name instruction with the name of your key pair.

```bash
aws ec2 create-key-pair --key-name od-bastion | jq -r .KeyMaterial > ~/.ssh/od-bastion.pem
chmod 400 ~/.ssh/od-bastion.pem
```

export the key pair name: ```bash export KEY_PAIR_NAME=od-bastion```

3. In addition, this walkthrough makes use of the unix command line utility `jq`. If you don't already have it, you can install it from [here](https://stedolan.github.io/jq/).

4. Install Docker. It is needed to build the demo application images.

5. Finally, to generate traffic and observe the server responses, we will leverage the open source Http load testing tool [vegeta](https://github.com/tsenart/vegeta). You can choose to install it locally or run the commands we will use later in a Docker container using this [image](https://hub.docker.com/r/peterevans/vegeta/).

## Step 2: Set Environment Variables

We need to set a few environment variables before provisioning the infrastructure.

```bash
export AWS_ACCOUNT_ID=<account id>

export AWS_DEFAULT_REGION=us-west-2

export ENVOY_IMAGE=<get the latest from https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html> #remember to replace the region-code!

export KEY_PAIR_NAME=<key pair name> # if not already done in the prerequisite section
```

## Step 3: Set up our Service Mesh

The mesh configuration for this walkthrough is rather straightforward:
our mesh contains two virtual nodes, `front-node` and `color-node`. The `front-node` is backed by a virtual service `color.howto-outlier-detection.local` that is provided by the `color-node`.
The actual services mirror this setup with a frontend service calling a color service backend. There is a single frontend service task and four color service tasks. We will send requests through an ALB pointing to the frontend service.

```bash
./mesh.sh up
```

## Step 4: Deploy Infrastructure and Service

  We'll build the frontend and color applications under `src` into Docker images, create and push to the ECR repo under the account `AWS_ACCOUNT_ID`, then deploy CloudFormation stacks for network infrastructure, the bastion host, and the ECS services.
  
```bash
./deploy.sh
```

The output of the application CloudFormation stack should print two values-

```bash
...
Successfully created/updated stack - howto-outlier-detection-app
Public ALB endpoint:
http://howto-Publi-6M2UI5BLY4UO-1032081974.us-west-2.elb.amazonaws.com
Public bastion endpoint:
54.190.143.11
```

The ALB endpoint is used to reach our frontend application, whereas the bastion endpoint is the public ip address of the bastion Ec2 instance that we will use to SSH into to inspect Envoy stats.
Export these two variables.

```bash
export ALB_ENDPOINT=<>
export BASTION_IP=<>
```

*Note*: The applications use go modules. If you have trouble accessing <https://proxy.golang.org> during the deployment you can override the `GOPROXY` by setting `GO_PROXY=direct`, i.e. run

```bash
GO_PROXY=direct ./deploy.sh
```

instead.

## Step 5: Before Enabling Outlier Detection

In this walkthrough, the frontend service calls the color service to get a color via `/get`. Under normal circumstances, the color service always responds with the color purple.

In addition, the frontend service is able to inject faults to the color service by making a request to `/fault`. When a color service server receives this request, it will start returning 500 Internal Service Error on `/get`. The fault can be recovered via `/recover` .

Finally, the frontend service keeps track of each unique host behind the color service and a counter of the response statuses they've returned. These stats can be retrieved via `/stats` and reset with `reset_stats` on the frontend service.

Let's start by issuing a simple get color request:

```bash
$ curl -i $ALB_ENDPOINT/color/get
HTTP/1.1 200 OK
Date: Fri, 25 Sep 2020 22:13:44 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 7
Connection: keep-alive
x-envoy-upstream-service-time: 43
server: envoy

purple
```

Let's check out the stats recorded in the frontend service:

```bash
$ curl $ALB_ENDPOINT/stats
[{"HostUID":"c624a8ac-ff80-44db-8560-7930c05974ee","Counter":{"StatusOk":1,"StatusError":0,"Total":1}}]
```

We see a single entry consisting of a HostUID and counter for its StatusOk (200), StatusError (500), and Total responses.

Now, let's generate more traffic to frontend service using vegeta. By default the request rate is 50/sec, so with duration=4s we'd be sending 200 requests.

```bash
$ echo "GET $ALB_ENDPOINT/color/get" | vegeta attack -duration=4s | tee results.bin | vegeta report
Requests      [total, rate, throughput]         200, 50.32, 49.59
Duration      [total, attack, wait]             4.033s, 3.975s, 58.337ms
Latencies     [min, mean, 50, 90, 95, 99, max]  54.263ms, 74.595ms, 60.179ms, 120.026ms, 136.811ms, 169.38ms, 194.739ms
Bytes In      [total, mean]                     1400, 7.00
Bytes Out     [total, mean]                     0, 0.00
Success       [ratio]                           100.00%
Status Codes  [code:count]                      200:200
Error Set:
```

In this walk through we are particularly interested in the `Status Codes` row. We can see that we received 200 http status codes out of 200 requests.

Now let's observe the frontend stats again; we can see that there are four HostUIDs representing the four color service tasks and each host should be serving ~50 requests. This is because we have four endpoints in the load balancing set and by default a round-robin load balancing strategy is employed:

```bash
$ curl $ALB_ENDPOINT/stats | jq .
[
  {
    "HostUID": "c624a8ac-ff80-44db-8560-7930c05974ee",
    "Counter": {
      "StatusOk": 50,
      "StatusError": 0,
      "Total": 50
    }
  },
  {
    "HostUID": "57eaa3cc-6dec-472c-ac16-e71f3cd6ee37",
    "Counter": {
      "StatusOk": 50,
      "StatusError": 0,
      "Total": 50
    }
  },
  {
    "HostUID": "dfb847e5-3134-45a4-bfef-94559ae0dc61",
    "Counter": {
      "StatusOk": 51,
      "StatusError": 0,
      "Total": 51
    }
  },
  {
    "HostUID": "ea1edc5b-a830-43c9-b91a-916406bcb6bc",
    "Counter": {
      "StatusOk": 50,
      "StatusError": 0,
      "Total": 50
    }
  }
]
```

Finally, let us inject a fault to one of the color service hosts. We want one of the four to be returning 500. Note that the response also includes the hostUID identifying the host.

```bash
$ curl $ALB_ENDPOINT/color/fault
host: e0d83188-d74c-4408-8fa0-04164faf5978 will now respond with 500 on /get.
```

Now let us issue 200 requests to the frontend service again:

```bash
echo "GET $ALB_ENDPOINT/color/get" | vegeta attack -duration=4s | tee results.bin | vegeta report
```

The status code distribution should now look something like `200:150 500:50`. If we check the frontend stats again, we should see that one of the four hosts now have non-zero StatusError and all the math should add up:

```bash
$ curl $ALB_ENDPOINT/stats | jq .
[
  {
    "HostUID": "c624a8ac-ff80-44db-8560-7930c05974ee",
    "Counter": {
      "StatusOk": 100,
      "StatusError": 0,
      "Total": 100
    }
  },
  {
    "HostUID": "57eaa3cc-6dec-472c-ac16-e71f3cd6ee37",
    "Counter": {
      "StatusOk": 100,
      "StatusError": 0,
      "Total": 100
    }
  },
  {
    "HostUID": "dfb847e5-3134-45a4-bfef-94559ae0dc61",
    "Counter": {
      "StatusOk": 101,
      "StatusError": 0,
      "Total": 101
    }
  },
  {
    "HostUID": "ea1edc5b-a830-43c9-b91a-916406bcb6bc",
    "Counter": {
      "StatusOk": 50,
      "StatusError": 50,
      "Total": 100
    }
  }
]
```

## Step 6: Outlier Detection in Action

Let's see how Outlier Detection can help us reduce the number of server errors given that one of the color hosts is degraded. Update the `color-node` virtual node with the spec `mesh/color-vn-with-outlier-detection.json`:

```bash
./mesh.sh add-outlier-detection
```

Once this update is propagated all the way down to the front-node's Envoy (give it a minute or so), let's try to issue 200 requests again:

```bash
$ echo "GET $ALB_ENDPOINT/color/get" | vegeta attack -duration=4s | tee results.bin | vegeta report | grep "Status Codes"
Status Codes  [code:count]                      200:195  500:5
```

The Status Codes row should now look something like `200:195  500:5` (500 responses could be more than that but definitely less than 50, depending on when the outlier detection configuration is taken into affect).
Compare this to when we didn't have Outlier Detection: a fourth of the requests were routed to the degraded host, whereas in this instance after five server errors were returned by the degraded host, Outlier Detection ejected the host from the load balancing set and traffic is no longer routed to that host. You can verify this via the frontend stats:

```bash
$ curl $ALB_ENDPOINT/stats | jq .
[
  {
    "HostUID": "c624a8ac-ff80-44db-8560-7930c05974ee",
    "Counter": {
      "StatusOk": 165,
      "StatusError": 0,
      "Total": 165
    }
  },
  {
    "HostUID": "57eaa3cc-6dec-472c-ac16-e71f3cd6ee37",
    "Counter": {
      "StatusOk": 165,
      "StatusError": 0,
      "Total": 165
    }
  },
  {
    "HostUID": "dfb847e5-3134-45a4-bfef-94559ae0dc61",
    "Counter": {
      "StatusOk": 166,
      "StatusError": 0,
      "Total": 166
    }
  },
  {
    "HostUID": "ea1edc5b-a830-43c9-b91a-916406bcb6bc",
    "Counter": {
      "StatusOk": 50,
      "StatusError": 55,
      "Total": 105
    }
  }
]
```

The `baseEjectionDuration` is configured as 10 seconds for the `color-node`, which is a relatively short amount of time. Try sending another 200 requests. If that yielded another `Status Codes  [code:count]                      200:195  500:5`, then it's likely the degraded host has already been un-ejected. Immediately send another 200 requests and you should see all requests returning 200.
If this degraded host continues to behave like how it is, the ejection time will continue to multiply and it becomes less likely that the host would be available in the load balancing set.

The basic walkthrough ends here and albeit the example somewhat contrived (having a host *always* return 500), should have demonstrated how Outlier Detection can help mitigate intermittent server errors caused by degraded hosts and improve service availability.

The following section is optional and serves to demonstrate a default Envoy behavior that may affect Outlier Detection.

### Panic and Ignore Outlier Detection

So what happens if all of the hosts were ejected? There wouldn't be any valid endpoints to route traffic to and the service would be 0% available. This is where Envoy's [panic threshold](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/load_balancing/panic_threshold#arch-overview-load-balancing-panic-threshold) configuration comes to play- this value defines when to place a service into **panic mode** where requests will be routed to all of the hosts regardless of their health or outlier detection statuses. This value is set to 50 by default; in other words if more than 50 percent of the hosts were to be ejected as an outlier, then outlier detection loses its affects. In most cases this behavior is more preferable over not trying to route requests to the service at all. Let's walk through this situation.

Remember that we currently have one host that continues to return 500 on `/get`. Let's fault another host:

```bash
$ curl $ALB_ENDPOINT/color/fault
host: dfb847e5-3134-45a4-bfef-94559ae0dc61 will now respond with 500 on /get. # this is a different host than the existing one ea1edc5b-a830-43c9-b91a-916406bcb6bc
```

Since we can't target this request to a specific host, observe the response that includes the HostUID to ensure the request reached a different host than the existing one. You can also check the host stats through the frontend service and compare if the returned HostUID doesn't already have non-zero `StatusErrors`. If it's the same host just send the request again.

Before we generate more traffic, it might be helpful to reset the frontend stats:

```bash
$ curl $ALB_ENDPOINT/reset_stats
stats cleared.
```

Now let's generate traffic:

```bash
$ echo "GET $ALB_ENDPOINT/color/get" | vegeta attack -duration=4s | tee results.bin | vegeta report | grep "Status Codes"
Status Codes  [code:count]                      200:172  500:28
```

We expect the newly degraded host to trigger Outlier Detection, while the existing one should also be ejected again if it has been un-ejected. Because ejections take place on intervals and each degraded host has a different ejection time, we see that 28 requests still made it to the two degraded hosts. Liberately send subsequent batches of 200 requests and we should expect only 200 responses:

```bash
$ echo "GET $ALB_ENDPOINT/color/get" | vegeta attack -duration=4s | tee results.bin | vegeta report | grep "Status Codes"
Status Codes  [code:count]                      200:200
```

Finally, let's breach the panic threshold by faulting a third host using the same approach above:

```bash
$ curl $ALB_ENDPOINT/color/fault
host: dfb847e5-3134-45a4-bfef-94559ae0dc61 will now respond with 500 on /get. #this host is already faulted, so sending the fault request again
$ curl $ALB_ENDPOINT/color/fault
host: c624a8ac-ff80-44db-8560-7930c05974ee will now respond with 500 on /get. #now we have 3 degraded hsots
```

Observe that when we now send 200 requests to the service, which has 75% of its hosts returning 500 errors, panic mode should kick in:

```bash
$ echo "GET $ALB_ENDPOINT/color/get" | vegeta attack -duration=4s | tee results.bin | vegeta report
Requests      [total, rate, throughput]         200, 50.25, 13.07
Duration      [total, attack, wait]             4.208s, 3.98s, 228.435ms
Latencies     [min, mean, 50, 90, 95, 99, max]  52.543ms, 77.82ms, 57.887ms, 136.119ms, 178.732ms, 274.415ms, 461.284ms
Bytes In      [total, mean]                     2415, 12.07
Bytes Out     [total, mean]                     0, 0.00
Success       [ratio]                           27.50%
Status Codes  [code:count]                      200:52  500:148
Error Set:
500 Internal Server Error
```

As expected, the distribution is roughly `200:50 500:150` since all four hosts are now serving traffic again regardless of their outlier status.

We can optionally examine some of the Envoy stats to observe the behaviors between outlier detection and panic threshold.
SSH into the bastion instance (use your own pem file if you specified your own keypair earlier):

```bash
ssh -i ~/.ssh/od-bastion.pem ec2-user@$BASTION_IP
```

Access the admin endpoint of the frontend service's Envoy via port 9901 (the default Envoy admin port) and check out the outlier detection-relate stats. In particular we will examine `outlier_detection.ejections_active`:

```bash
$ curl http://front.howto-outlier-detection.local:9901/stats | grep outlier_detection.ejections_active
cluster.cds_egress_howto-outlier-detection_color-node_http_8080.outlier_detection.ejections_active: 0
```

This statistic represents the count of [currently ejected outlier hosts](https://www.envoyproxy.io/docs/envoy/latest/configuration/upstream/cluster_manager/cluster_stats#outlier-detection-statistics). You may get a different number between 0-3 depending on whether your hosts are currently ejected or not. If you got 0, simply send another 200 requests to trigger outlier detection and check again:

```bash
cluster.cds_egress_howto-outlier-detection_color-node_http_8080.outlier_detection.ejections_active: 3
```

Furthermore, we can check out the statistics around the panic mode behavior:

```bash
$ curl http://front.howto-outlier-detection.local:9901/stats | grep lb_healthy_panic
cluster.cds_egress_howto-outlier-detection_amazonaws.lb_healthy_panic: 0
cluster.cds_egress_howto-outlier-detection_color-node_http_8080.lb_healthy_panic: 771
cluster.cds_ingress_howto-outlier-detection_front-node_http_8080.lb_healthy_panic: 0
```

The [lb_healthy_panic](https://www.envoyproxy.io/docs/envoy/latest/configuration/upstream/cluster_manager/cluster_stats#load-balancer-statistics) represents the total number of requests the frontend service's Envoy has had to load balance while the given cluster is in panic mode. The cluster `cluster.cds_egress_howto-outlier-detection_color-node_http_8080` represents the color service.

## Step 8: Clean Up

All resources created in this walkthrough can be deleted via:

```bash
./deploy.sh delete && ./mesh.sh down
```
