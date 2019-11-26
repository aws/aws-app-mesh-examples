## Overview
This example shows how Kubernetes deployments can use AWS CloudMap for service-discovery when using App Mesh. AWS Cloud Map is a cloud resource discovery service. With Cloud Map, you can define custom names for your application resources, and it maintains the updated location of these dynamically changing resources. This increases your application availability because your web service always discovers the most up-to-date locations of its resources.

In this example there are two CloudMap services and three K8s Deployments as described below.

### Color
There are two deployments of colorapp, _blue_ and _red_. Pods of both these deployments are registered behind service colorapp.howto-k8s-cloudmap.pvt.aws.local. Blue pods are registered with the mesh as colorapp-blue virtual-node and red pods as colorapp-red virtual-node. These virtual-nodes are configured to use AWS CloudMap as service-discovery, hence the IP addresses of these pods are registered with the CloudMap service with corresponding attributes.

Additionally a colorapp virtual-service is defined that routes traffic to blue and red virtual-nodes.

### Front
Front app acts as a gateway that makes remote calls to colorapp. Front app has single deployment with pods registered with the mesh as _front_ virtual-node. This virtual-node uses colorapp virtual-service as backend. This configures Envoy injected into front pod to use App Mesh's EDS to discover colorapp endpoints.

## Prerequisites
[Walkthrough: App Mesh with EKS](../eks/)

Note: This feature requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version >=0.1.2. Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json  | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'
```

## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-cloudmap folder, all commands will be ran from this location
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
   $ kubectl get pod -n howto-k8s-cloudmap -o wide
    NAME                             READY   STATUS    RESTARTS   AGE   IP               NODE                                           NOMINATED NODE   READINESS GATES
    colorapp-blue-558b8698b5-p98kb   2/2     Running   0          80m   192.168.50.137   ip-192-168-34-246.us-west-2.compute.internal   <none>           <none>
    colorapp-red-7997f7f687-t4k98    2/2     Running   0          80m   192.168.72.100   ip-192-168-94-59.us-west-2.compute.internal    <none>           <none>
    front-667ff84fd-g85p8            2/2     Running   0          80m   192.168.84.178   ip-192-168-94-59.us-west-2.compute.internal    <none>           <none>

   $ aws servicediscovery discover-instances --namespace howto-k8s-cloudmap.pvt.aws.local --service front
    {
        "Instances": [
            {
                "InstanceId": "192.168.84.178",
                "NamespaceName": "howto-k8s-cloudmap.pvt.aws.local",
                "ServiceName": "front",
                "HealthStatus": "UNKNOWN",
                "Attributes": {
                    "AWS_INSTANCE_IPV4": "192.168.84.178",
                    "app": "front",
                    "appmesh.k8s.aws/mesh": "howto-k8s-cloudmap",
                    "appmesh.k8s.aws/virtualNode": "front-howto-k8s-cloudmap",
                    "date": "1574731550",
                    "k8s.io/namespace": "howto-k8s-cloudmap",
                    "k8s.io/pod": "front-667ff84fd-g85p8",
                    "pod-template-hash": "667ff84fd",
                    "version": "v1"
                }
            }
        ]
    }

   $ aws servicediscovery discover-instances --namespace howto-k8s-cloudmap.pvt.aws.local --service colorapp --query-parameters "version=blue"
    {
        "Instances": [
            {
                "InstanceId": "192.168.50.137",
                "NamespaceName": "howto-k8s-cloudmap.pvt.aws.local",
                "ServiceName": "colorapp",
                "HealthStatus": "UNKNOWN",
                "Attributes": {
                    "AWS_INSTANCE_IPV4": "192.168.50.137",
                    "app": "colorapp",
                    "appmesh.k8s.aws/mesh": "howto-k8s-cloudmap",
                    "appmesh.k8s.aws/virtualNode": "colorapp-blue-howto-k8s-cloudmap",
                    "date": "1574731553",
                    "k8s.io/namespace": "howto-k8s-cloudmap",
                    "k8s.io/pod": "colorapp-blue-558b8698b5-p98kb",
                    "pod-template-hash": "558b8698b5",
                    "version": "blue"
                }
            }
        ]
    }

    $ aws servicediscovery discover-instances --namespace howto-k8s-cloudmap.pvt.aws.local --service colorapp --query-parameters "version=red"
    {
        "Instances": [
            {
                "InstanceId": "192.168.72.100",
                "NamespaceName": "howto-k8s-cloudmap.pvt.aws.local",
                "ServiceName": "colorapp",
                "HealthStatus": "UNKNOWN",
                "Attributes": {
                    "AWS_INSTANCE_IPV4": "192.168.72.100",
                    "app": "colorapp",
                    "appmesh.k8s.aws/mesh": "howto-k8s-cloudmap",
                    "appmesh.k8s.aws/virtualNode": "colorapp-red-howto-k8s-cloudmap",
                    "date": "1574731555",
                    "k8s.io/namespace": "howto-k8s-cloudmap",
                    "k8s.io/pod": "colorapp-red-7997f7f687-t4k98",
                    "pod-template-hash": "7997f7f687",
                    "version": "red"
                }
            }
        ]
    }
   ```

## FAQ
### 1. How can I use Cloud Map namespaces other than PrivateDnsNamespace?
AWS Cloud Map supports three types of namespaces;
1. [PublicDnsNamespace](https://docs.aws.amazon.com/cloud-map/latest/api/API_CreatePublicDnsNamespace.html): Namespace that is visible to the internet.
2. [PrivateDnsNamespace](https://docs.aws.amazon.com/cloud-map/latest/api/API_CreatePrivateDnsNamespace.html): Namespace that is visible only in the specified VPC.
3. [HttpNamespace](https://docs.aws.amazon.com/cloud-map/latest/api/API_CreateHttpNamespace.html): Namespace that supports only HTTP discovery using DiscoverInstances. This namespace does not support DNS resolution.

Currently App Mesh only supports backend applications running within VPC boundaries and that are not directly reachable from internet. So this rules out PublicDnsNamespace support. Both PrivateDnsNamespace and HttpNamespace can be supported but given that most applications still use DNS resolution before making a connection to remote service (via Envoy), HttpNamespace cannot be readily used. In future, we plan on leveraging [Envoy's DNS filter](https://github.com/envoyproxy/envoy/issues/6748) to support both PrivateDnsNamespace and HttpNamespace seamlessly. For now it is required to create PrivateDnsNamespace to get both DNS resolution and App Mesh's EDS support. Note that both PrivateDnsNamespace and HttpNamespace services support custom attributes that can be used with DiscoverInstances API.

## Troubleshooting
### 1. My deployments and corresponding pods are running successfully, but I don't see the instances when calling Cloud Map DiscoverInstances API. What is the reason?
Following are some of the reasons why instances are not getting registered with Cloud Map.
1. Check that aws-app-mesh-controller-for-k8s is >=v0.1.2. If not upgrade the controller using helm instructions [here](https://github.com/aws/eks-charts).
2. Check the logs of aws-app-mesh-controller-for-k8s for any errors. [stern](https://github.com/wercker/stern) is a great tool to use for this.
   ```
   $ kubectl logs -n appmesh-system appmesh-controller-<pod-id>
   (or)
   $ stern -n appmesh-system appmesh-controller
   ```
3. If you see AccessDeniedException in the logs when calling Cloud Map APIs, then update IAM role used by worker node to include AWSCloudMapRegisterInstanceAccess managed IAM policy. 