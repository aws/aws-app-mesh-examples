## Overview
This example shows how to custom format Envoy access logs using either json or custom string. 

## Prerequisites
1. [Walkthrough: App Mesh with EKS](../eks/)

2. v1beta2 example manifest requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

You can use v1beta1 example manifest with [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [=v0.3.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/legacy-controller/CHANGELOG.md)

3. Install Docker. It is needed to build the demo application images.


## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-http-headers folder, all commands will be ran from this location
2. **Your** account id:

    export AWS_ACCOUNT_ID=<your_account_id>

3. **Region** e.g. us-west-2

    export AWS_REGION=us-west-2

4. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.

5. Deploy
    ```
    ./deploy.sh
    ```

## Test

Port-forward pod to simulating requests

```
kubectl port-forward deployment/front -n howto-k8s-envoy-logging-custom-format 8080:8080
```

Simulate requests

```
curl locahost:8080/color
```

Validate logs

```
kubectl logs deployment/front -n howto-k8s-envoy-logging-custom-format envoy | grep "texttestingtesting"
kubectl logs deployment/blue -n howto-k8s-envoy-logging-custom-format envoy | grep "jsontestingtesting"
```
