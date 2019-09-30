## Overview

This example shows how we can route between HTTP2 clients and servers using App Mesh.

![System Diagram](./howto-http2.png "System Diagram")

### Color Server

The Color Server is a simple go HTTP2 server returns a color. In this example, we have 3 types of the Color Server running: `red`, `green`, and `blue` each returning a different color. All service instances are registered under the `color_server.http2.local` DNS namespace. But we will be able to route between them by registering their color metadata in [AWS Cloud Map](https://docs.aws.amazon.com/cloud-map/latest/dg/what-is-cloud-map.html) and configuring our virtual-nodes to use AWS Cloud Map [Service Discovery](https://docs.aws.amazon.com/app-mesh/latest/userguide/virtual_nodes.html#create-virtual-node).

### Color Client

The Color Client is a HTTP/1.1 front-end webserver that communicates to the Color Server over HTTP2. The HTTP/1.1 webserver will be connected to an internet-facing ALB. It forwards requests for `/color` to a Color Server backend. Initially, the Envoy sidecar for the Color Client will be configured to only route the `red`-type virtual-nodes, but we will update the route to load-balance across all three types.

## Setup

1. This example uses features in the [App Mesh Preview Channel](https://docs.aws.amazon.com/app-mesh/latest/userguide/preview.html). You'll need to install the latest `appmesh-preview` model to deploy it
    ```
    aws configure add-model \
        --service-name appmesh-preview \
        --service-model https://raw.githubusercontent.com/aws/aws-app-mesh-roadmap/master/appmesh-preview/service-model.json
    ```
2. Clone this repository and navigate to the walkthrough/howto-http2 folder, all commands will be ran from this location
3. **Project Name** used to isolate resources created in this demo from other's in your account. e.g. howto-http2
    ```
    export PROJECT_NAME=howto-http2
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
2. Try curling the `/color` API
    ```
    curl $COLOR_ENDPOINT/color
    ```
   You should see `red`. This is because our current mesh is only configured to route http2 requests to the `color_server-red` virtual-node:
   
   (from [mesh/route.json](./mesh/route-red.json))
    ```json
    {
      "http2Route": {
        "action": {
          "weightedTargets": [
            {
              "virtualNode": "color_server-red",
              "weight": 1
            }
          ]
        },
        "match": {
          "prefix": "/"
        }
      }
    }
    ```
   We'll first update our route to send traffic equally to the `color_server-red` and `color_server-blue` virtual-nodes
4. Update the route to [mesh/route-red-blue.json](./mesh/route-red-blue.json):
    ```
    aws appmesh-preview update-route --mesh-name $PROJECT_NAME-mesh --virtual-router-name virtual-router --route-name route --cli-input-json file://mesh/route-red-blue.json
    ```
5. Now try curling the color again
    ```
    curl $COLOR_ENDPOINT/color
    ```
   If you run that a few times, you should get an about 50-50 mix of red and blue virtual-nodes
6. Next update the route to remove the red node, and you'll see `blue` from now on
    ```
    aws appmesh-preview update-route --mesh-name $PROJECT_NAME-mesh --virtual-router-name virtual-router --route-name route --cli-input-json file://mesh/route-blue.json
    ```
7. Finally update the routes to balance across all virtual-nodes
    ```
    aws appmesh-preview update-route --mesh-name $PROJECT_NAME-mesh --virtual-router-name virtual-router --route-name route --cli-input-json file://mesh/route-red-blue-green.json
    ```

### Teardown
When you are done with the example you can delete everything we created by running:
```
./deploy.sh delete
```
