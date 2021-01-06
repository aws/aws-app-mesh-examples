## Overview
This example shows how to configure App Mesh Route and VirtualNode listener timeouts. This feature allows us to specify a custom timeout value based on the application's need and when not specified a default timeout of 15 seconds will be applied to all the requests.

We use AWS Cloud Map based service discovery mechanism in this example walkthrough.

### Color
There are two deployments of colorapp, _blue_ and _red_. Pods of both these deployments are registered behind service colorapp.howto-k8s-timeout-policy.pvt.aws.local. Blue pods are registered with the mesh as colorapp-blue virtual-node and red pods as colorapp-red virtual-node. These virtual-nodes are configured to use AWS CloudMap as service-discovery, hence the IP addresses of these pods are registered with the CloudMap service with corresponding attributes. We specify a timeout value of 60 secs for all the VirtualNodes and VirtualRouters.

Additionally a colorapp virtual-service is defined that routes traffic to blue and red virtual-nodes.

### Front
Front app acts as a gateway that makes remote calls to colorapp. Front app has single deployment with pods registered with the mesh as _front_ virtual-node. This virtual-node uses colorapp virtual-service as backend. This configures Envoy injected into front pod to use App Mesh's EDS to discover colorapp endpoints.

Colorapp is configured to respond with a delay of 45 seconds to simulate an upstream request that takes more than the default Envoy timeout of 15 seconds. Since, the configured timeout value in _front_virtual-node is 60 seconds(along with route timeout of 60 secs in the backend virtual router), we can see that envoy will not timeout in this scenario.

## Prerequisites
1. [Walkthrough: App Mesh with EKS](../eks/)

2. v1beta2 example manifest requires aws-app-mesh-controller-for-k8s version >=v1.0.0. Run the following to check the version of controller you are running.

```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```
3. Install Docker. It is needed to build the demo application images.

## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-timeout-policy folder, all commands will be ran from this location
2. **Your** account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```
3. **Region** e.g. us-west-2
    ```
    export AWS_DEFAULT_REGION=us-west-2
    ```
4. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.
5. **VPC_ID** environment variable is set to the VPC where Kubernetes pods are launched. VPC will be used to setup private DNS namespace in AWS using create-private-dns-namespace API. To find out VPC of EKS cluster you can use `aws eks describe-cluster`. See [below](#1-how-can-i-use-cloud-map-namespaces-other-than-privatednsnamespace) for reason why Cloud Map PrivateDnsNamespace is required.
    ```
    export VPC_ID=...
    ```
6. Deploy
    ```. 
    ./deploy.sh
    ```

## Verify

1. Use AWS Cloud Map DiscoverInstances API to check that pods are getting registered
   ```
   $ kubectl get pod -n howto-k8s-timeout-policy -o wide
    NAME                             READY   STATUS    RESTARTS   AGE     IP               NODE                                           NOMINATED NODE   READINESS GATES
    colorapp-blue-6f99884fd4-2h4jt   2/2     Running   0          4m15s   192.168.10.38    ip-192-168-16-102.us-west-2.compute.internal   <none>           <none>
    colorapp-red-77d6565cc6-8btwz    2/2     Running   0          4m15s   192.168.34.225   ip-192-168-56-146.us-west-2.compute.internal   <none>           <none>
    front-5d96c9bfb6-d2zdx           2/2     Running   0          4m15s   192.168.59.249   ip-192-168-56-146.us-west-2.compute.internal   <none>           <none>

   $ aws servicediscovery discover-instances --namespace howto-k8s-timeout-policy.pvt.aws.local --service front
    {
        "Instances": [
            {
                "InstanceId": "192.168.59.249",
                "NamespaceName": "howto-k8s-timeout-policy.pvt.aws.local",
                "ServiceName": "front",
                "HealthStatus": "HEALTHY",
                "Attributes": {
                    "AWS_INIT_HEALTH_STATUS": "HEALTHY",
                    "AWS_INSTANCE_IPV4": "192.168.59.249",
                    "app": "front",
                    "k8s.io/namespace": "howto-k8s-timeout-policy",
                    "k8s.io/pod": "front-5d96c9bfb6-d2zdx",
                    "pod-template-hash": "5d96c9bfb6",
                    "version": "v1"
                }
            }
        ]
    }

   $ aws servicediscovery discover-instances --namespace howto-k8s-timeout-policy.pvt.aws.local --service colorapp --query-parameters "version=blue"
    {
        "Instances": [
            {
                "InstanceId": "192.168.10.38",
                "NamespaceName": "howto-k8s-timeout-policy.pvt.aws.local",
                "ServiceName": "colorapp",
                "HealthStatus": "HEALTHY",
                "Attributes": {
                    "AWS_INIT_HEALTH_STATUS": "HEALTHY",
                    "AWS_INSTANCE_IPV4": "192.168.10.38",
                    "app": "colorapp",
                    "k8s.io/namespace": "howto-k8s-timeout-policy",
                    "k8s.io/pod": "colorapp-blue-6f99884fd4-2h4jt",
                    "pod-template-hash": "6f99884fd4",
                    "version": "blue"
                }
            }
        ]
    }

   $ aws servicediscovery discover-instances --namespace howto-k8s-timeout-policy.pvt.aws.local --service colorapp --query-parameters "version=red"
    {
        "Instances": [
            {
                "InstanceId": "192.168.34.225",
                "NamespaceName": "howto-k8s-timeout-policy.pvt.aws.local",
                "ServiceName": "colorapp",
                "HealthStatus": "HEALTHY",
                "Attributes": {
                    "AWS_INIT_HEALTH_STATUS": "HEALTHY",
                    "AWS_INSTANCE_IPV4": "192.168.34.225",
                    "app": "colorapp",
                    "k8s.io/namespace": "howto-k8s-timeout-policy",
                    "k8s.io/pod": "colorapp-red-77d6565cc6-8btwz",
                    "pod-template-hash": "77d6565cc6",
                    "version": "red"
                }
            }
        ]
    }
   ```

2. You can now make a call to /color of front and you should see a delayed response that takes more than default envoy timeout of 15 seconds. You can try adjusting the timeout value around the simulated 45 seconds delay and observe the behavior change. Removing the timeout config from the VirtualNode and VirtualRouter specs will result in a timeout as expected.

## Troubleshooting
1. Check that aws-app-mesh-controller-for-k8s is >=v1.0.0 based on the API version. If not upgrade the controller using helm instructions [here](https://github.com/aws/eks-charts).
2. Check the logs of aws-app-mesh-controller-for-k8s for any errors. [stern](https://github.com/wercker/stern) is a great tool to use for this.
   ```
   $ kubectl logs -n appmesh-system appmesh-controller-manager-<pod-id>
   (or)
   $ stern -n appmesh-system appmesh-controller-manager
   ```
3. If you see AccessDeniedException in the logs when calling Cloud Map APIs, then update IAM role used by worker node to include AWSCloudMapRegisterInstanceAccess managed IAM policy.
