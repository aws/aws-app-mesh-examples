# HTTP Retry Policy Example

This example shows how we can set retry duration and attempts within route configurations. In this mesh we have a frontend service and a color service. When a request is made, the frontend service will create a header to denote the current time and send that request to the color service. The color service will respond with a 503 if the time of the original request (passed through the header) and the current time is less than 1 second. Initially without retry in place this error will be thrown consistently. After we introduce retries, we will begin to see the time of the original request and the current time will eventually be greater than 1 second (depending on the retry policy configuration you want to set but the example configuration will work once the route is updated during the walkthrough). At this point the color service will return a 200 and send back the color. 

## Prerequisites
1. Install Docker. It is needed to build the demo application images.

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

## Default Retry Policy
App Mesh provides customers with a default retry policy when an explicit retry policy is not set on a route. However, this is not currently available to all customers. If default retry policies are not currently available to you then you will not be able to run this upcoming section and can skip ahead to the clean up section. To learn more about the default retry policy you can read about it here: https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html#default-retry-policy

1. Let's swap back to a route that has no explicit retry policy to have the default retry policy get applied. Update your route configuration to not include retries by running the following command:
    ```
    aws appmesh update-route --mesh-name howto-http-retries --cli-input-json file://blue-route-no-retry.json
    ```       

1. Curl the endpoint again and this time you should receive a 503. This is due to the fact that our application is currently configured to consectively send back 503s until 1 second has passed since the initial request. Although the default retry policy is present and we are retying the request, we are unable to get back a successful request due to the application returning faults for a period of time that will likely exhaust all retries. In order to better observe the default retry policy in action let's make a change to the application.

1. Open the `serve.py` file found in the `colorapp` folder in an editor. Look for the `FAULT_TIME` variable towards the top of the file. This should be currently set to `1` and we will now change this value to be `.02`. Save this change and you can now close this file.

1. To apply this change to our application we must update our application image and redeploy our application. You can do this by running the following command:
```
./deploy.sh update-blue-service
```
The effect of running this command will not be immediate because it will task some time for the application to get redeployed with our change to track the status we can run the following command and take a look at the runningCount and pendingCount:
```
aws ecs describe-services --cluster howto-http-retries --services BlueService
```
We want the runningCount to be 1 and the pendingCount to be 0. This will indicate that an ECS task with our change is now running and that the previous task running the old version of the application has been torn down. Once this state has been reached then we can move on to making a request.

5. Curl the endpoint again and this time you should receive a 200. Verify this by checking the logs and confirming that despite sending a single request from the frontend, the envoy sidecar on the blue service attempted to retry the request based on the route spec. This should look similar to when we set an explicit retry policy on our route except we are now retrying a fewer amount of times when compared to the explicit strategy. 

This showcases that the App Mesh default retry policy can help prevent failed requests in some cases. However, there may be cases where you will want to set an explicit retry strategy depending on your application and use case. To read more about what recommendations we give for retry policies you can read more here: https://docs.aws.amazon.com/app-mesh/latest/userguide/best-practices.html#route-retries

## Clean up 

Run the following command to remove all resources created from this demo (will take 5-10 minutes): 
```
./deploy.sh delete
```

Alternatively, to manually delete resources delete the two stacks this walkthrough created (named _howto-http-retries-app_ and _howto-http-retries-infra_). Also go to ECR in the console and remove all images associated to the two repositories created (_named howto-http-retries/colorapp_ and _howto-http-retries/feapp_) then you can delete the repositories once their images are removed. Go to the App Mesh console and remove the mesh once all mesh resources are deleted. The automatic deletion from the command above will do all of this for you. 
