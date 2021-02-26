## Overview
This example shows how to manage HTTP/2 routes in App Mesh using Kubernetes deployments

## Prerequisites
1. [Walkthrough: App Mesh with EKS](../eks/)

2. v1beta2 example manifest requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

You can use v1beta1 example manifest with [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [=v0.3.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/legacy-controller/CHANGELOG.md)

3. Install Docker. It is needed to build the demo application images.

```
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
1. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields, e.g.
    ```
    helm upgrade -i appmesh-controller eks/appmesh-controller --namespace appmesh-system --set sidecar.image.repository=840364872350.dkr.ecr.us-west-2.amazonaws.com/aws-appmesh-envoy --set sidecar.image.tag=<VERSION>
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
    curl localhost:7000/color
    ```
   
1. You can edit these specifications in the manifest.yaml.template [here](./manifest.yaml.template). Run ./deploy.sh after any changes you make. For instance you can remove one of the weighted targets and trigger the curl command above to confirm that color route no longer appears.

