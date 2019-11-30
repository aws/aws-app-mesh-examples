## Overview
This example shows how to manage HTTP/2 routes in App Mesh using Kubernetes deployments

## Prerequisites
[Walkthrough: App Mesh with EKS](../eks/)

Note: This feature requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=0.3.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/CHANGELOG.md#v030). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json  | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'

## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-http2 folder, all commands will be ran from this location
1. **Your** account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```
1. **Region** e.g. us-west-2
    ```
    export AWS_DEFAULT_REGION=us-west-2
    ```
1. **ENVOY_IMAGE** environment variable is set to App Mesh Envoy, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html
    ```
    export ENVOY_IMAGE=...
    ```
1. Deploy
    ```.
    ./deploy.sh
    ```   
    
1. Note that the example apps use go modules. If you have trouble accessing https://proxy.golang.org during the deployment you can override the GOPROXY by setting `GO_PROXY=direct`
   ```
   GO_PROXY=direct ./deploy.sh
   ``` 
       
1. Set up [port forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/) to route requests from your local computer to the **client** pod. The local port is up to you but we will assume the local port is **7000** for this walkthrough.

    
## HTTP/2 Routing
1. In order to view app logs you must find your client pod by running the following passing your namespace name:
    ```
    kubectl get pod -n <namespace>
    ```  
    
1. Using the name of the client pod run the following command to tail the client app logs:
    ```
    kubectl logs -f -n <namespace> <pod_name> app
    ```

1. Initially the state of your mesh is a client node with an even distribution to 3 color services (red, blue, and green) over HTTP/2. Prove this by running the following command a few times:
    ```
    localhost:7000/color
    ```
   
1. You can edit these specifications in the manifest.yaml.template [here](./manifest.yaml.template). Run ./deploy.sh after any changes you make. For instance you can remove one of the weighted targets and trigger the curl command above to confirm that color route no longer appears.

