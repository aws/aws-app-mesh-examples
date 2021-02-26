
## Overview

In this walkthrough, we'll demonstrate the use of outlier detection in AWS App Mesh with EKS.

Outlier detection is a form of passive health check that temporarily ejects an endpoint/host of a given service (represented by a Virtual Node) from the load balancing set when it meets failure threshold (hence considered an *outlier*). Outlier detection is supported as configuration in Virtual Nodes listeners.

## Prerequisites

1. [Walkthrough: App Mesh with EKS](../eks/)
2. Run the following to check the version of controller you are running.
```
kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1

v1.2.0
```

3. Install Docker. It is needed to build the demo application images.


## Step 1: Setup environment
1. Clone this repository and navigate to the walkthrough/howto-k8s-outlier-detection folder, all commands will be ran from this location
2. **Your** account id:

```
    export AWS_ACCOUNT_ID=<your_account_id>
```

3. **Region** e.g. us-west-2

```
    export AWS_DEFAULT_REGION=us-west-2
```

## Step 2: Create a Mesh with outlier detection enabled

Let's deploy the sample applications and mesh with outlier detection. This will deploy two Virtual Nodes (and applications): `front` and `colorapp`, where `front`->`colorapp` and `colorapp` is the backend with four replicas.

```
./deploy.sh
```

```
kubectl get virtualnodes,pod -n howto-k8s-outlier-detection
NAME                                   ARN                                                                                                                                AGE
virtualnode.appmesh.k8s.aws/colorapp   arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-outlier-detection/virtualNode/colorapp_howto-k8s-outlier-detection   55s
virtualnode.appmesh.k8s.aws/front      arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-outlier-detection/virtualNode/front_howto-k8s-outlier-detection      55s

NAME                           READY   STATUS    RESTARTS   AGE
pod/colorapp-cbfb668dc-6v5sm   2/2     Running   0          55s
pod/colorapp-cbfb668dc-fdt2n   2/2     Running   0          55s
pod/colorapp-cbfb668dc-h2whw   2/2     Running   0          55s
pod/colorapp-cbfb668dc-xzqbd   2/2     Running   0          55s
pod/front-57bfb8f966-8n9rh     2/2     Running   0          55s
```

Outlier detection is configured on the `colorapp` listener:

```
kubectl describe virtualnode colorapp -n howto-k8s-outlier-detection

..
Spec:
  Aws Name:  colorapp_howto-k8s-outlier-detection
  Listeners:
    Outlier Detection:
      Base Ejection Duration:
        Unit:   s
        Value:  10
      Interval:
        Unit:                s
        Value:               10
      Max Ejection Percent:  50
      Max Server Errors:     5
    Port Mapping:
      Port:      8080
      Protocol:  http
...

```

Let's check the outlier detection configuration in AWS App Mesh
```
aws appmesh describe-virtual-node --virtual-node-name colorapp_howto-k8s-outlier-detection --mesh-name howto-k8s-outlier-detection

{
    "virtualNode": {
        "meshName": "howto-k8s-outlier-detection",
        "metadata": {
            "arn": "arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-outlier-detection/virtualNode/colorapp_howto-k8s-outlier-detection",
            "createdAt": 1603467992.872,
            "lastUpdatedAt": 1603468186.926,
            "meshOwner": "1234567890",
            "resourceOwner": "1234567890",
            "uid": "b41a6cd3-40e3-4182-aafe-53b943241221",
            "version": 2
        },
        "spec": {
            "backends": [],
            "listeners": [
                {
                    "outlierDetection": {
                        "baseEjectionDuration": {
                            "unit": "s",
                            "value": 10
                        },
                        "interval": {
                            "unit": "s",
                            "value": 10
                        },
                        "maxEjectionPercent": 50,
                        "maxServerErrors": 5
                    },
                    "portMapping": {
                        "port": 8080,
                        "protocol": "http"
                    }
                }
            ],
            "serviceDiscovery": {
                "awsCloudMap": {
                    "namespaceName": "howto-k8s-outlier-detection.pvt.aws.local",
                    "serviceName": "colorapp"
                }
            }
        },
        "status": {
            "status": "ACTIVE"
        },
        "virtualNodeName": "colorapp_howto-k8s-outlier-detection"
    }
}
```

## Step 3: Verify outlier detection

`front` calls the `colorapp` to get a color via `/get`. `front` can inject faults to the `colorapp` by making a request to `/fault`. When an instance of `colorapp` receives this request, it will start returning 500 Internal Service Error on `/get`. The fault can be recovered via /recover .

`front` also keeps tracks of the backend `colorapp` hosts and stats of the response statuses for each `colorapp` instance. The stats can be retrieved via `/stats` and reset with `/reset_stats`.

Let's exec into the traffic generator Vegeta to call the `front` service.

```
VEGETA_POD=$(kubectl get pod -l "app=vegeta-trafficgen" --output=jsonpath={.items..metadata.name})
kubectl exec -it $VEGETA_POD -- /bin/sh
```

Let's verify `colorapp` is responsive via `front`
```
curl -i front.howto-k8s-outlier-detection:8080/color/get

HTTP/1.1 200 OK
date: Fri, 23 Oct 2020 15:58:45 GMT
content-length: 7
content-type: text/plain; charset=utf-8
x-envoy-upstream-service-time: 1
server: envoy

purple
```

Let's verify the stats and the four `colorapp` hosts
```
curl front.howto-k8s-outlier-detection:8080/stats | jq .

[
  {
    "HostUID": "8f04b1c8-af29-4345-8a0d-34cb5c981e38",
    "Counter": {
      "StatusOk": 3,
      "StatusError": 0,
      "Total": 3
    }
  },
  {
    "HostUID": "34bb223d-1e6c-4423-898e-372d30a638b2",
    "Counter": {
      "StatusOk": 3,
      "StatusError": 0,
      "Total": 3
    }
  },
  {
    "HostUID": "c87a6e70-c9a2-4343-a453-81808bec9d2d",
    "Counter": {
      "StatusOk": 2,
      "StatusError": 0,
      "Total": 2
    }
  },
  {
    "HostUID": "c3338a28-8590-48e6-9c53-77c4e15100dc",
    "Counter": {
      "StatusOk": 2,
      "StatusError": 0,
      "Total": 2
    }
  }

```

Let's generate traffic without any faults and see all the instances responding with HTTP 200 responses:

```
echo "GET http://front.howto-k8s-outlier-detection:8080/color/get" | vegeta attack -duration=4s | tee results.bin | vegeta report

Requests      [total, rate, throughput]         200, 50.25, 50.23
Duration      [total, attack, wait]             3.982s, 3.98s, 1.628ms
Latencies     [min, mean, 50, 90, 95, 99, max]  1.59ms, 2.043ms, 1.93ms, 2.29ms, 2.464ms, 5.555ms, 12.771ms
Bytes In      [total, mean]                     1400, 7.00
Bytes Out     [total, mean]                     0, 0.00
Success       [ratio]                           100.00%
Status Codes  [code:count]                      200:200
Error Set:
```

See the `Status Codes` row and all the response codes are `200`.

Let's look at the stats. Notice the even distribution of traffic to all the backends and all responses show `StatusOk`

```
curl front.howto-k8s-outlier-detection:8080/stats | jq .

[
  {
    "HostUID": "8f04b1c8-af29-4345-8a0d-34cb5c981e38",
    "Counter": {
      "StatusOk": 53,
      "StatusError": 0,
      "Total": 53
    }
  },
  {
    "HostUID": "34bb223d-1e6c-4423-898e-372d30a638b2",
    "Counter": {
      "StatusOk": 53,
      "StatusError": 0,
      "Total": 53
    }
  },
  {
    "HostUID": "c87a6e70-c9a2-4343-a453-81808bec9d2d",
    "Counter": {
      "StatusOk": 52,
      "StatusError": 0,
      "Total": 52
    }
  },
  {
    "HostUID": "c3338a28-8590-48e6-9c53-77c4e15100dc",
    "Counter": {
      "StatusOk": 52,
      "StatusError": 0,
      "Total": 52
    }
  }
]
```

Let's inject fault into one of the backends
```
curl -i front.howto-k8s-outlier-detection:8080/color/fault

host: c87a6e70-c9a2-4343-a453-81808bec9d2d will now respond with 500 on /get.
```

Host `c87a6e70-c9a2-4343-a453-81808bec9d2d` will respond with HTTP 500 response and we will see how App Mesh automatically detects the faulty host and ejects it based on the outlier detection configuration on the `colorapp` virtual node.

Let's generate traffic to verify the behavior

```
echo "GET http://front.howto-k8s-outlier-detection:8080/color/get" | vegeta attack -duration=4s | tee results.bin | vegeta report

Requests      [total, rate, throughput]         200, 50.25, 48.97
Duration      [total, attack, wait]             3.982s, 3.98s, 2.281ms
Latencies     [min, mean, 50, 90, 95, 99, max]  1.649ms, 2.178ms, 2.062ms, 2.378ms, 2.467ms, 8.118ms, 12.213ms
Bytes In      [total, mean]                     1435, 7.17
Bytes Out     [total, mean]                     0, 0.00
Success       [ratio]                           97.50%
Status Codes  [code:count]                      200:195  500:5
Error Set:
500 Internal Server Error
```

Notice that there are 5 requests that returned HTTP 500 response in the `Status Codes` row. App Mesh should detect this and eject the host for 10s. For next 10s, you should see all requests return HTTP 200 responses as the faulty host will no longer be serving traffic.

Let's look at the stats to verify this:

```
curl front.howto-k8s-outlier-detection:8080/stats | jq .

[
  {
    "HostUID": "8f04b1c8-af29-4345-8a0d-34cb5c981e38",
    "Counter": {
      "StatusOk": 118,
      "StatusError": 0,
      "Total": 118
    }
  },
  {
    "HostUID": "34bb223d-1e6c-4423-898e-372d30a638b2",
    "Counter": {
      "StatusOk": 118,
      "StatusError": 0,
      "Total": 118
    }
  },
  {
    "HostUID": "c87a6e70-c9a2-4343-a453-81808bec9d2d",
    "Counter": {
      "StatusOk": 52,
      "StatusError": 5,
      "Total": 57
    }
  },
  {
    "HostUID": "c3338a28-8590-48e6-9c53-77c4e15100dc",
    "Counter": {
      "StatusOk": 117,
      "StatusError": 0,
      "Total": 117
    }
  }
]
```

Notice that host `c87a6e70-c9a2-4343-a453-81808bec9d2d` returned 5 errors and no traffic was sent to this host. All the traffic was distributed between the other three hosts.

If we send more traffic during the ejection duration, we will see that all the requests will return `HTTP 200` responses since only the healthy hosts will be serving traffic:

```
echo "GET http://front.howto-k8s-outlier-detection:8080/color/get" | vegeta attack -duration=4s | tee results.bin | vegeta report

Requests      [total, rate, throughput]         200, 50.25, 50.23
Duration      [total, attack, wait]             3.982s, 3.98s, 1.945ms
Latencies     [min, mean, 50, 90, 95, 99, max]  1.605ms, 1.995ms, 1.962ms, 2.267ms, 2.318ms, 2.441ms, 5.114ms
Bytes In      [total, mean]                     1400, 7.00
Bytes Out     [total, mean]                     0, 0.00
Success       [ratio]                           100.00%
Status Codes  [code:count]                      200:200
Error Set:
```

The request above was made while the host `c87a6e70-c9a2-4343-a453-81808bec9d2d` was ejected and we got 100% successful responses.

Wait for the ejection duration to pass and generate traffic again. You will see the faulty host is back in the cluster until ejected again:

```
echo "GET http://front.howto-k8s-outlier-detection:8080/color/get" | vegeta attack -duration=4s | tee results.bin | vegeta report

Requests      [total, rate, throughput]         200, 50.25, 48.98
Duration      [total, attack, wait]             3.982s, 3.98s, 1.657ms
Latencies     [min, mean, 50, 90, 95, 99, max]  1.42ms, 1.794ms, 1.766ms, 1.969ms, 2.019ms, 2.78ms, 5.082ms
Bytes In      [total, mean]                     1435, 7.17
Bytes Out     [total, mean]                     0, 0.00
Success       [ratio]                           97.50%
Status Codes  [code:count]                      200:195  500:5
Error Set:
500 Internal Server Error
```

## Step 4: Cleanup

If you want to keep the application running, you can do so, but this is the end of this walkthrough. Run the following commands to clean up and tear down the resources that we’ve created.

```bash
kubectl delete -f _output/manifest.yaml
```
