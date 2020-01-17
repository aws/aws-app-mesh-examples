# Timeout Policy Example
The current feature implementation lets you only decrease the current default request timeout(15 secs). You can set the timeout to higher values but the request will still timeout because of upstream configurations. We are working on this and will support it in later releases.

The mesh in this example has the following resources:
* A Virtual Service named `color.http.local`. 
* A Virtual Router named `virtual-router` which serves as the provider for the virtual service above.
* 2 Virtual Nodes:
  1. `front-node`: Sends egress traffic to the `color.http.local` Virtual Service. It discovers instances via Cloud Map in the `front` service under the `http.local` namespace.
  1. `color-node`: A Cloud Map Node for `color.http.local`.
* 1 Route: 
  1. `color-route`: A route with a header match rule to match all traffic and direct to `color-node`.


When front service receives a request containing a header "latency", it includes the latency header in the request made to color service.
If the color service receives latency value in header it waits for that many seconds and then returns the response back.

## Setup
1. This example uses features in the [App Mesh Preview Channel](https://docs.aws.amazon.com/app-mesh/latest/userguide/preview.html). You'll need to install the latest `appmesh-preview` model to deploy it
    ```
    aws configure add-model \
        --service-name appmesh-preview \
        --service-model https://raw.githubusercontent.com/aws/aws-app-mesh-roadmap/master/appmesh-preview/service-model.json
    ```

1. Clone this repository and navigate to the walkthrough/howto-timeout-policy folder, all commands will be run from this location

1. Your account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```

1. Your region
    ```
    export AWS_DEFAULT_REGION=us-west-2
    
    ```
1. The latest envoy image, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html
   ```
   export ENVOY_IMAGE=<from_appmesh_user_guide_above>
   ```
    
1. Deploy the resources (this will take about 5-10 minutes to complete):
    ```
    ./deploy.sh
    ```
   
1. Once the script has executed there will be a public endpoint. Export the public endpoint to access the Color Client APIs.
    ```
    export COLOR_ENDPOINT=<your_public_endpoint e.g. http://howto-Publi-55555555.us-west-2.elb.amazonaws.com>
    ```
 

## Timeouts

1. Check the current route configuration by calling describe-route.
    ```
    aws appmesh-preview describe-route --mesh-name howto-timeout-policy --virtual-router-name color-router --route-name color-route
    ```
    
1. Use curl to send a request to the front service. The front service will route the request to the backend color service. The color service will wait for 10 seconds and send the response.
    ```
    curl --header "latency:10" $COLOR_ENDPOINT
    ``` 
    
1. Update your route configuration to configure perRequest timeout as 5 seconds by running the following command:
    ```
    aws appmesh-preview update-route --mesh-name howto-timeout-policy --cli-input-json file://mesh/colorRouteWithTimeout.json
    ```       
    
1. Describe your route again using step 1 to see the timeout policy within the route spec. 

1. Curl the endpoint again with latency as 10, and this time you should see a 504 Gateway timeout message.
    ```
    curl --header "latency:10" $COLOR_ENDPOINT
    ``` 

## Clean up 

Run the following command to remove all resources created from this demo (will take 5-10 minutes): 
```
./deploy.sh delete
```