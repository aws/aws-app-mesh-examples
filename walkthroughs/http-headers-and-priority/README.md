# HTTP Header based routing example

1. Clone this repository and navigate to the walkthrough/http-headers-and-priority folder, all commands will be ran from this location


## Set Environment Variables

1. **Your** account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```

3. Preview is only in us-west-2
    ```
    export AWS_DEFAULT_REGION=us-west-2
    ```

## Create a VPC
This is the virtual network for everything to run in. It is *pretty much* just the VPC from our official colorapp demo on github. It supports DNS, has a couple public and private subnets (1 per AZ), and an internet gateway so we can reach it and it can reach EMS. You can check it out in `vpc.yaml`:
```
aws cloudformation create-stack --stack-name header-vpc --template-body file://vpc.yaml
```
And check the status until it is completed:
```
aws cloudformation describe-stacks --stack-name header-vpc
```

## Upload Apps to ECR

1. First we'll need to create 2 ECR repositories for our apps:
    ```
    aws ecr create-repository --repository-name header-ecr-colorapp
    ```
    ```
    aws ecr create-repository --repository-name header-ecr-feapp
    ```
2. Build the colorapp Docker image: a http server that just returns the value of its `COLOR` environment variable. This command also tags the image with the ECR repo we created earlier:
    ```
    docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/header-ecr-colorapp colorapp
    ```
3. Now build the feapp: a "frontend" http server that makes a GET request to whatever host is pointed to by its `COLOR_HOST` environment variable and returns the result to the requester:
    ```
    docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/header-ecr-feapp feapp
    ```
4. To upload our apps, we'll need to log Docker onto ECR:
    ```
    eval $(aws ecr get-login --no-include-email)
    ```
5. Finally, we can push them 🚀:
    ```
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/header-ecr-colorapp
    ```
    ```
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/header-ecr-feapp
    ```

## Use Preview Model

To access these features use the preview model. Run the following command:

```
    aws configure add-model \
        --service-name appmesh-preview \
        --service-model https://raw.githubusercontent.com/aws/aws-app-mesh-roadmap/master/appmesh-preview/service-model.json
```


## Create your Service Mesh
This Mesh has a bunch of cool things:
* A Virtual Service named `color.header-mesh.local`. Provided by a Virtual Router named `color-router`.
* 5 Virtual Nodes:
  1. `front-node`: Sends egress traffic to the `color.header-mesh.local` Virtual Service. It discovers instances via Cloud Map in the `front` service under the `header-mesh.local` namespace. i.e. the DNS name `front.$STACK_PREFIX-mesh.local`.
  2. `blue-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `blue`.
  3. `green-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `green`.
  4. `red-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `red`.
  5. `yellow-node`: A Cloud Map Node for `color.header-mesh.local` that discovers instances with the attribute `ECS_TASK_DEFINITION_FAMILY` set to `yellow`.

Check out the template in `header-mesh.yaml` if you want.

1. Go ahead and create the Mesh with the command below. The output is each mesh component as json. You should not see any errors.
    ```
     sh ./build-mesh.sh 
    ```
    
2. Once the Mesh is created, verify that a Service-Linked Role was automatically created in your account:
    ```
    aws iam get-role --role-name AWSServiceRoleForAppMeshPreview
    ```

## Deploy the Rest
This creates the ECS Tasks to run our apps on Fargate along with config to have ECS automatically register our Task instances with Cloud Map. Feel free to look at header.yml for the stack details. This stack will take a few minutes to deploy.

```
aws cloudformation create-stack --capabilities CAPABILITY_IAM --stack-name header --template-body file://header.yaml
```
And check the status until it is completed:
```
aws cloudformation describe-stacks --stack-name header
```

## Verification

1. Once the stack above have successfully deployed, get the public address of the frontend service. Look for an http address under `FrontendEndpoint`:
  ```
  aws cloudformation describe-stacks --stack-name header
  ```
  
2. In our demo we will use this endpoint in postman to pass header values to the header "color_header" and observe our routes in action.

## Update Route

1. Check the current route configurations by calling describe-route on each of them by name. For instance, to describe the blue route:
  ```
  aws appmesh-preview describe-route --mesh-name header-mesh --virtual-router-name color-router --route-name color-route-blue
  ```

2. Update various routes with the json files in this package in order to see headers and priority updates. For instance in the demo video we change the priority of color-route-red by updating the *priority* value from 5 to 1 then running the following command 
  ```
  aws appmesh-preview update-route --mesh-name header-mesh --cli-input-json file://components/red-route.json
  ```

3. You will see the updated priority in the response json from the update-route command above to confirm your updates to the route. Try updating various color nodes with different headers and repeat the steps above to apply changes.

## Clean up 

Feel free to delete this mesh by running the following 
  ```
  sh ./teardown-mesh.sh
  ```

You can also delete the 2 stack we created with: 
  ```
  aws cloudformation delete-stack --stack-name header
  ```
  
 once this stack is deleted you can then delete the next one:
  
  ```
  aws cloudformation delete-stack --stack-name vpc
  ```
  
 delete the colorapp and feapp repositories in ECR through the console. Select each one and select delete.