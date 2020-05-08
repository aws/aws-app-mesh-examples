## Overview
This example shows how retry-policies can be used to for Kubernetes applications within the context of App Mesh.

### Color
Color app serves color with optionally return error status code if a statuscode-header is set in the request. This will allow us to verify retry behavior when using retry-policies.

### Front
Front app acts as a gateway that makes remote calls to colorapp. Front app has single deployment with pods registered with the mesh as _front_ virtual-node. This virtual-node uses colorapp virtual-service as backend.

## Prerequisites
[Walkthrough: App Mesh with EKS](../eks/)

Note: v1beta2 example manifest requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/CHANGELOG.md). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json  | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'
```

You can use v1beta1 example manifest with [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v0.3.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/CHANGELOG.md#v030)

## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-retry-policy folder, all commands will be ran from this location
2. **Your** account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```
3. **Region** e.g. us-west-2
    ```
    export AWS_DEFAULT_REGION=us-west-2
    ```
4. **ENVOY_IMAGE** environment variable is set to App Mesh Envoy, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html
    ```
    export ENVOY_IMAGE=...
    ```
5. Deploy
    ```.
    ./deploy.sh
    ```

## Verify
1. Port-forward front pod
   ```
   kubectl get pod -n howto-k8s-retry-policy
   NAME                     READY   STATUS    RESTARTS   AGE
   blue-55d5bf6bb9-4n7hc    3/3     Running   0          11s
   front-5dbdcbc896-l8bnz   3/3     Running   0          11s
   ...

   kubectl -n howto-k8s-retry-policy port-forward deployment/front 8080:8080
   ```

2. In a new terminal, use curl to send a bunch of requests to the front service. You should see almost equal number of 200 (OK) and 503 (Server Error) responses.
    ```
    while true; do curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 ; sleep 0.5; echo ; done
    ```

3. Back in the original terminal, uncomment retryPolicy in manifest.yaml.template and run `./deploy.sh`
   ```
      # UNCOMMENT below to enable retries
        retryPolicy:
          maxRetries: 4
          perRetryTimeoutMillis: 2000
          httpRetryEvents:
            - server-error
   ```

4. You should now see more 200 OK responses due to retries.

No go to https://www.envoyproxy.io/docs/envoy/v1.8.0/api-v1/route_config/route#config-http-conn-man-route-table-route-retry and https://www.envoyproxy.io/learn/automatic-retries for details on how retries work in Envoy.
