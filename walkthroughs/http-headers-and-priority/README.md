# HTTP Header based routing example

Clone this repository and navigate to the walkthrough/http-headers-and-priority folder, all commands will be ran from this location.

## Service Mesh Details
This mesh has the following resources:
* A Virtual Service named `color.header-mesh.local`. 
* A Virtual Router named `color-router` which serves as the provider for the virtual service above.
* 8 Virtual Nodes:
  1. `front-node`: Sends egress traffic to the `color.header-mesh.local` Virtual Service. It discovers instances via Cloud Map in the `front` service under the `header-mesh.local` namespace. i.e. the DNS name `front.$STACK_PREFIX-mesh.local`.
  2. `purple-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `purple`.
  3. `yellow-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `yellow`.
  4. `blue-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `blue`.
  5. `green-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `green`.
  6. `red-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `red`.
  7. `white-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `white`.
  8. `black-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `black`.
  
* 7 Routes: 
  1. `color-route-purple`: A route with a header match rule to match weather the header name `color_header` _does not_ exist.
  2. `color-route-yellow`: A route with a header match rule to match weather the header name `color_header` _does_ exist.
  3. `color-route-blue`: A route with a header match rule to match weather the header `color_header` has a value within the range `[100, 150)` (excludes 150).
  4. `color-route-green`: A route with a header match rule to match weather the header name `color_header` has a value that matches the regex `redor.*`.
  5. `color-route-red`: A route with a header match rule to match weather the header name `color_header` has a value that matches the prefix `redorgreen`.
  6. `color-route-white`: A route with a header match rule to match weather the pseudo header name `:method` has a value that matches `GET`.
  7. `color-route-black`: A route with a header match rule to match weather the pseudo header name `:scheme` has a value that matches the prefix `https`.

## Setup

1. Your account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```
2. Your region:
    ```
    export AWS_DEFAULT_REGION=<i.e. us-west-2>
    ```
    
3. The latest envoy image, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html
   ```
   export ENVOY_IMAGE=<i.e. 111345817488.dkr.ecr.us-west-2.amazonaws.com/aws-appmesh-envoy:v1.11.1.1-prod>
   ```
    
4. Deploy the resources, save the public endpoint output for later (this will take about 5-10 minutes to complete):
    ```
    ./deploy.sh
    ```

## Update Route

1. Check the current route configuration by viewing your routes in the app mesh console, within the app.yaml, or by using the CLI.
For instance, to describe the blue route using the CLI:
  ```
  aws appmesh describe-route --mesh-name header-mesh --virtual-router-name color-router --route-name color-route-blue
  ```

2. For example routing a request with the _color_header_ header value set to _redorgreencolor_ will route to the green service (matching on regex _redor.*_) even though it also
applies to the red service (matching on the prefix _redorgreen_). This is because the route priority attribute for the green route has higher priority than the red route. 
To see this run the following command where endpoint refers to the output from the deploy script in the previous section:    
  ```
  curl --header "color_header: redorgreencolor" <endpoint>
  ```

2. You can update any route by updating the corresponding header match resources within the app.yaml file within the ColorRoute[Color] resources. 
For instance you can update the route priority of color-route-red (resource name is ColorRouteRed) from 5 to 1. 
Now the same request with the previous header value _redorgreencolor_
should route to the red service. Execute the deploy script again to update any changes you make in the cloudformation template: 
  ```
  ./deploy.sh
  ```


## Clean up 

Run the following command to remove all resources created from this demo: 
```
./deploy.sh delete
```

To manually delete resources delete the two stacks this walkthrough created (named _howto-http-headers-app_ and _howto-http-headers-infra_). 
Also go to ECR and remove all images associated
to the two repositories created (named __ and __) then you can delete the repositories once their images are removed. 