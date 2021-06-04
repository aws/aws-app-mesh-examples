## Overview
This example shows how retry-policies can be used to for Kubernetes applications within the context of App Mesh.

### Color
Color app serves color with optionally return error status code if a statuscode-header is set in the request. This will allow us to verify retry behavior when using retry-policies.

### Front
Front app acts as a gateway that makes remote calls to colorapp. Front app has single deployment with pods registered with the mesh as _front_ virtual-node. This virtual-node uses colorapp virtual-service as backend.

## Prerequisites
1. [Walkthrough: App Mesh with EKS](../eks/)

2. v1beta2 example manifest requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

You can use v1beta1 example manifest with [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [=v0.3.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/legacy-controller/CHANGELOG.md)

3. Install Docker. It is needed to build the demo application images.

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
4. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.
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

Now go to https://www.envoyproxy.io/docs/envoy/v1.8.0/api-v1/route_config/route#config-http-conn-man-route-table-route-retry and https://www.envoyproxy.io/learn/automatic-retries for details on how retries work in Envoy.

## Default Retry Policy
App Mesh provides customers with a default retry policy when an explicit retry policy is not set on a route. However, this is not currently available to all customers. If default retry policies are not currently available to you then you will not be able to run this upcoming section and can skip this section. To learn more about the default retry policy you can read about it here: https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html#default-retry-policy

1. Let's swap back to a route that has no explicit retry policy to have the default retry policy get applied. Update your route configuration to not include retries by commenting out or removing the retryPolicy that you uncommented earlier in manifest.yaml.template and run `./deploy.sh`:
   ```
      # COMMENT back out or remove below to disable explicit retries
        retryPolicy:
          maxRetries: 4
          perRetryTimeoutMillis: 2000
          httpRetryEvents:
            - server-error
   ``` 
2. Send requests to the front service again in a seperate terminal to observe that we are once again getting back 503s for some of the requests
    ```
    while true; do curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 ; sleep 0.5; echo ; done
    ```

3. In order to better see the default retry policy in action let's lower the fault rate on our application. Currently at a 50% fault rate we are likely going to exhaust all of our retries for some requests resulting in the 503s that we see getting returned. Let's make a change to the `serve.py` in the `colorapp` folder by reducing the fault rate from 50% to 10% by making a changing the fault rate variable at the top of the file from 50 to 10.
    ```
    # Change this value to 10
    FAULT_RATE = 50
    ```

4. With this change let's redeploy the application to use this new fault rate by running the following
    ```
    REDEPLOY=true ./deploy.sh
    ```

5. Now let's again send requests to the front service again to observe that we are now should be getting almost exclusively 200s at this point from all of our requests despite 10% of them failing.
    ```
    while true; do curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 ; sleep 0.5; echo ; done
    ```

This showcases that the App Mesh default retry policy can help prevent failed requests in some cases. However, there may be cases where you will want to set an explicit retry strategy depending on your application and use case. To read more about what recommendations we give for retry policies you can read more here: https://docs.aws.amazon.com/app-mesh/latest/userguide/best-practices.html#route-retries
