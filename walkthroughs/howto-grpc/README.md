## Overview

This example shows how we can route between gRPC clients and servers using App Mesh.

![System Diagram](./howto-grpc.png "System Diagram")

### Color Server

The Color Server is a gRPC server that implements [color.ColorService](./color.proto). Additionally, it implements the [gRPC Health Checking Protocol](https://github.com/grpc/grpc/blob/master/doc/health-checking.md) which we will configure App Mesh to use as the health check for the its virtual-nodes.

### Color Client

The Color Client is a HTTP/1.1 front-end webserver that maintains a persistent gRPC connection to the Color Server. The HTTP/1.1 webserver will be connected to an internet-facing ALB. It forwards requests to `/getColor` and `/setColor` to the same methods in [color.ColorService](./color.proto). Initially, the Envoy sidecar for the Color Client will be configured to only route the `GetColor` gRPC method, but we will update the route to forward all methods to the Color Server.

## Setup

1. This example uses features in the [App Mesh Preview Channel](https://docs.aws.amazon.com/app-mesh/latest/userguide/preview.html). You'll need to install the latest `appmesh-preview` model to deploy it
    ```
    aws configure add-model \
        --service-name appmesh-preview \
        --service-model https://raw.githubusercontent.com/aws/aws-app-mesh-roadmap/master/appmesh-preview/service-model.json
    ```
2. Clone this repository and navigate to the walkthrough/howto-grpc folder, all commands will be ran from this location
3. **Project Name** used to isolate resources created in this demo from other's in your account. e.g. howto-grpc
    ```
    export PROJECT_NAME=howto-grpc
    ```
4. **Your** account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```
5. **Region** e.g. us-west-2
    ```
    export AWS_DEFAULT_REGION=us-west-2
    ```
6. **ENVOY_IMAGE** environment variable is not set to App Mesh Envoy, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html
    ```
    export ENVOY_IMAGE=...
    ```
7. Setup using cloudformation
    ```
    ./deploy.sh
    ```
   Note that the example apps use go modules. If you have trouble accessing https://proxy.golang.org during the deployment you can override the GOPROXY by setting `GO_PROXY=direct`
   ```
   GO_PROXY=direct ./deploy.sh
   ```

## Verification

1. After a few minutes, the applications should be deployed and you will see an output such as:
    ```
    Successfully created/updated stack - howto-grpc-app
    Public endpoint:
    http://howto-Publi-5555555.us-west-2.elb.amazonaws.com
    ```
   This is the public endpoint to access the Color Client APIs. Export it.
    ```
    export COLOR_ENDPOINT=<your_public_endpoint>
    ```
2. Try curling the `/getColor` API
    ```
    curl $COLOR_ENDPOINT/getColor
    ```
   You should see `no color!`. The color returned by the Color Service via the Color Client can be configured using the `/setColor` API.
3. Attempt to change the color by curling the `/setColor` API
    ```
    curl -i -X POST -d "blue" $COLOR_ENDPOINT/setColor
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
   This is because our current mesh is only configured to route the gRPC Method `GetColor`:
   
   (from [mesh/route.json](./mesh/route.json))
    ```json
    {
      "grpcRoute": {
        "action": {
          "weightedTargets": [
            {
              "virtualNode": "color_server",
              "weight": 100
            }
          ]
        },
        "match": {
          "serviceName": "color.ColorService",
          "methodName": "GetColor"
        }
      }
    }
    ```
   We'll remove the `methodName` match condition in the gRPC route to match all methods for `color.ColorService`.
4. Update the route to [mesh/route-all-methods.json](./mesh/route-all-methods.json):
    ```
    aws appmesh-preview update-route --mesh-name $PROJECT_NAME-mesh --virtual-router-name virtual-router --route-name route --cli-input-json file://mesh/route-all-methods.json
    ```
5. Now try updating the color again
    ```
    curl -i -X POST -d "blue" $COLOR_ENDPOINT/setColor
    ```
   You'll see that we got a `HTTP/1.1 200 OK` response. You'll also see `no color!` in the response. But this is the previous color being returned after a successful color update.
6. You can verify that the color did, in fact, update
    ```
    curl $COLOR_ENDPOINT/getColor
    ```

### Teardown
When you are done with the example you can delete everything we created by running:
```
./deploy.sh delete
```
