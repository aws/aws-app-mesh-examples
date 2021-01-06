# HTTP Header based routing example

Clone this repository and navigate to the walkthrough/http-headers-and-priority folder, all commands will be ran from this location.

## Service Mesh Details
This mesh has the following resources:
* A Virtual Service named `color.header-mesh.local`. 
* A Virtual Router named `color-router` which serves as the provider for the virtual service above.
* 8 Virtual Nodes:
  1. `front-node`: Sends egress traffic to the `color.header-mesh.local` Virtual Service. It discovers instances via Cloud Map in the `front` service under the `howto-http-headers.local` namespace.
  1. `purple-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `purple`.
  1. `yellow-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `yellow`.
  1. `blue-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `blue`.
  1. `green-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `green`.
  1. `red-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `red`.
  1. `white-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `white`.
  1. `black-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `black`.
  
* 7 Routes: 
  1. `color-route-purple`: A route with a header match rule to match weather the header name `color_header` _does not_ exist.
  1. `color-route-yellow`: A route with a header match rule to match weather the header name `color_header` _does_ exist.
  1. `color-route-blue`: A route with a header match rule to match weather the header `color_header` has a value within the range `[100, 150)` (excludes 150).
  1. `color-route-green`: A route with a header match rule to match weather the header name `color_header` has a value that matches the regex `redor.*`.
  1. `color-route-red`: A route with a header match rule to match weather the header name `color_header` has a value that matches the prefix `redorgreen`.
  1. `color-route-white`: A route with a header match rule to match weather the pseudo header name `:method` has a value that matches `GET`.
  1. `color-route-black`: A route with a header match rule to match weather the pseudo header name `:scheme` has a value that matches the prefix `https`.

## Prerequisites
1. Install Docker. It is needed to build the demo application images.

## Setup

1. Your account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```
1. Your region:
    ```
    export AWS_DEFAULT_REGION=<i.e. us-west-2>
    ```
    
1. The latest envoy image, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html
   ```
   export ENVOY_IMAGE=<from_appmesh_user_guide_above>
   ```
    
1. Deploy the resources (this will take about 5-10 minutes to complete):
    ```
    ./deploy.sh
    ```
   
1. Once the script has executed there will be a public endpoint, save this for later.

## Update Route

1. Check the current route configuration by viewing your routes in the app mesh console, within the app.yaml, or by using the CLI.
For instance, to describe the blue route using the CLI:
  ```
  aws appmesh describe-route --mesh-name howto-http-headers --virtual-router-name color-router --route-name color-route-blue
  ```

1. For example routing a request with the _color_header_ header value set to _redorgreencolor_ will route to the green service (matching on regex _redor.*_) even though it also
applies to the red service (matching on the prefix _redorgreen_). This is because the route priority attribute for the green route has higher priority than the red route. 
To see this run the following command where endpoint refers to the output from the deploy script in the previous section:    
  ```
  curl --header "color_header: redorgreencolor" <endpoint>
  ```

1. Lets update the red route to have a higher priority than the green route. Run the following command to update the priority on the red route
then rerun the curl command above. You should be routing to red now.  
  ```
  aws appmesh update-route --mesh-name howto-http-headers --cli-input-json file://color-route.json
  ```
  
1. Feel free to update various routes in the json file above by changing the route name. Reference these docs to test the various
[header routing rules](https://docs.aws.amazon.com/app-mesh/latest/APIReference/API_HttpRouteMatch.html) and [priority](https://docs.aws.amazon.com/app-mesh/latest/APIReference/API_RouteSpec.html). 

## Clean up 

Run the following command to remove all resources created from this demo: 
    ```
    ./deploy.sh delete
    ```

Alternatively, to manually delete resources delete the two stacks this walkthrough created (named _howto-http-headers-app_ and _howto-http-headers-infra_). 
Also go to ECR in the console and remove all images associated to the two repositories created (_named howto-http-headers/colorapp_ and _howto-http-headers-feapp_) 
then you can delete the repositories once their images are removed. Go to the App Mesh console and remove the mesh once all mesh resources are deleted. 
The automatic deletion from the command above will do all of this for you. 
