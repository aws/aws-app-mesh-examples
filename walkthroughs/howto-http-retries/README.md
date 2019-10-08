# HTTP Retry Policy Example

This example shows how we can set retry duration and attempts within route configurations. In this mesh we have a frontend service and a color service. When a request is made, the frontend service will create a header to denote the current time and send that request to the color service. The color service will respond with a 503 if the time of the original request (passed through the header) and the current time is less than 1 second. Initially without retry in place this error will be thrown consistently. After we introduce retries, we will begin to see the time of the original request and the current time will eventually be greater than 1 second (depending on the retry policy configuration you want to set but the example configuration will work once the route is updated during the walkthrough). At this point the color service will return a 200 and send back the color. 

## Setup

1. Clone this repository and navigate to the walkthrough/http-retry-policy folder, all commands will be ran from this location

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
   
1. Once the script has executed there will be a public endpoint, save this for later. We will use this endpoint in curl to pass header values to the header _statuscode-header_ to observe retry policy in action.

## Update Route

1. Check the current route configuration by calling describe-route. For instance, to describe the blue route:
    ```
    aws appmesh describe-route --mesh-name howto-http-retries --virtual-router-name color-router --route-name color-route-blue
    ```
    
1. Use curl to send a request to the frontend service. The frontend service will route the request to the backend blue service. The blue service will experience a failure and return a 503. 
    ```
    curl <endpoint>
    ``` 
    
1. Now let's introduce retries and watch our service return a 200 by returning "blue". The backend service will return a 200 only after 1 second has passed since the initial request from the frontend service. Update your route configuration to include retries by running the following command:
    ```
    aws appmesh update-route --mesh-name howto-http-retries --cli-input-json file://blue-route.json
    ```       
    
1. Describe your route again using step 1 to see the retry policy within the route spec this time. 

1. Open up the logs in the console which can be found at _Cloudwatch -> Logs -> howto-http-retries-log-group -> blue/app/task_id_. Filter out the ping requests by searching _-"ping"_

1. Curl the endpoint again and this time you should receive a 200. Verify this by checking the logs and confirming that despite sending a single request from the frontend, the envoy sidecar on the blue service attempted to retry the request based on the route spec. 

## Clean up 

Run the following command to remove all resources created from this demo (will take 5-10 minutes): 
```
./deploy.sh delete
```

Alternatively, to manually delete resources delete the two stacks this walkthrough created (named _howto-http-retries-app_ and _howto-http-retries-infra_). Also go to ECR in the console and remove all images associated to the two repositories created (_named howto-http-retries/colorapp_ and _howto-http-retries/feapp_) then you can delete the repositories once their images are removed. Go to the App Mesh console and remove the mesh once all mesh resources are deleted. The automatic deletion from the command above will do all of this for you. 