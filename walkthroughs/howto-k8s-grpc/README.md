## Overview
This example shows how to manage gRPC routes in App Mesh using Kubernetes deployments.

## Prerequisites
1. [Walkthrough: App Mesh with EKS](../eks/)

2. v1beta2 example manifest requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

You can use v1beta1 example manifest with [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [=v0.3.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/legacy-controller/CHANGELOG.md)

3. Install Docker. It is needed to build the demo application images.

## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-grpc folder, all commands will be ran from this location
1. **Your** account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```
1. **Region** e.g. us-west-2
    ```
    export AWS_DEFAULT_REGION=us-west-2
    ```
1. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.
1. **VPC_ID** environment variable is set to the VPC where Kubernetes pods are launched. VPC will be used to setup private DNS namespace in AWS using create-private-dns-namespace API. To find out VPC of EKS cluster you can use `aws eks describe-cluster`.
    ```
    export VPC_ID=...
    ```
1. Deploy
    ```
    ./deploy.sh
    ```
1. Note that the example apps use go modules. If you have trouble accessing https://proxy.golang.org during the deployment you can override the GOPROXY by setting `GO_PROXY=direct`
   ```
   GO_PROXY=direct ./deploy.sh
   ```
      
1. Set up [port forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/) to route requests from your local computer to the **client** pod. The local port is up to you but we will assume the local port is **7000** for this walkthrough.
    
## gRPC Routing

1. In order to view app logs you must find your client pod by running the following passing your namespace name:
    ```
    kubectl get pod -n <namespace>
    ```  
    
1. Using the name of the client pod run the following command to tail the client app logs:
    ```
    kubectl logs -f -n <namespace> <pod_name> app
    ```
    
1. Try curling the `/getColor` API
    ```
    curl localhost:7000/getColor
    ```
   You should see `no_color`. The color returned by the Color Service via the Color Client can be configured using the `/setColor` API.

1. Attempt to change the color by curling the `/setColor` API
    ```
    curl -i -X POST -d "blue" localhost:7000/setColor
    ```
   We passed the `-i` flag to see any error information in the response. You should see something like:
    ```
    HTTP/1.1 404 Not Found
    Date: Fri, 27 Sep 2019 01:27:42 GMT
    Content-Type: text/plain; charset=utf-8
    Content-Length: 40
    Connection: keep-alive
    x-content-type-options: nosniff
    x-envoy-upstream-service-time: 1
    server: envoy

    rpc error: code = Unimplemented desc =
    ```
   This is because our current mesh is only configured to route the gRPC Method `GetColor`. 

   We'll remove the `methodName` match condition in the gRPC route to match all methods for `color.ColorService`. 
1. To do this remove the methodName specification in the [manifest](./manifest.yaml.template) and rerun the deploy script

1. Now try updating the color again
    ```
    curl -i -X POST -d "blue" localhost:7000/setColor
    ```
   You'll see that we got a `HTTP/1.1 200 OK` response. You'll also see `no_color` in the response. But this is the previous color being returned after a successful color update.

1. You can verify that the color did, in fact, update
    ```
    curl localhost:7000/getColor
    ```
