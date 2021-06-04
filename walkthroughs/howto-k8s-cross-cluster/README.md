## Overview
In this article, we are going to start to explore how to use App Mesh across kubernetes clusters. App Mesh is a service mesh that lets you control and monitor services spanning multiple AWS compute environments. We'll demonstrate this by using 2 kubernetes clusters(EKS) within a VPC and a App Mesh that spans the clusters using Cloud Map. This example shows how Kubernetes deployments can use AWS Cloud Map for service-discovery when using App Mesh.

We will use two EKS clusters in a single VPC to explain the concept of cross cluster mesh using Cloud Map. This is intentionally meant to be a simple example for clarity, but in the real world the App Mesh can span multiple different compute types like ECS, fargate, Kubernetes on EC2 etc.

In this example there are two EKS clusters within a VPC and a mesh spanning both clusters . The setup Cloud Map services and three EKS Deployments as described below. The front container will be deployed in Cluster 1 and the color containers will be deployed in Cluster 2 . The Goal is to have a single Mesh across the clusters works via DNS resolution using Cloud Map.


*CLUSTERS*

We will spin up two EKS clusters in the same VPC for simplicity and configure a Mesh as we deploy the clusters components.

*DEPLOYMENTS*

There are two deployments of colorapp, blue and red. Pods of both these deployments are registered behind service colorapp.howto-k8s-cross-cluster.pvt.aws.local. Blue pods are registered with the mesh as colorapp-blue virtual-node and red pods as colorapp-red virtual-node. These virtual-nodes are configured to use AWS Cloud Map as service-discovery, hence the IP addresses of these pods are registered with the Cloud Map service with corresponding attributes.
Additionally a colorapp virtual-service is defined that routes traffic to blue and red virtual-nodes.  

Front app acts as a gateway that makes remote calls to colorapp. Front app has single deployment with pods registered with the mesh as front virtual-node. This virtual-node uses colorapp virtual-service as backend. This configures Envoy injected into front pod to use App Mesh's EDS to discover colorapp endpoints.


*MESH*

App Mesh components will be deployed from one of the two clusters. It does not really matter where you deploy them from. It will have various components deployed . A Virtual Node per service and a Virtual Service which will have a Virtualrouter with routes tied (provider) to route traffic between red and blue equally.

Note: If your clusters are across two different accounts then add "meshOwner: AccountId" to the mesh spec in the second cluster. If the field isn't specified it assumes the account id of the current cluster is the owner of the mesh and will create a new mesh against that account.

*CLOUD MAP*

As we create the mesh we will use service discovery attributes which will automatically create the DNS records in the namespace that we have pre-created. The front application in cluster one will leverage this DNS entry in Cloud Map to talk to the colorapp on the second cluster.  

So, Lets get started..

## Prerequisites

In order to successfully carry out the base deployment:

* Make sure to have newest AWS CLI (https://aws.amazon.com/cli/) installed.
* Make sure to have kubectl installed (https://kubernetes.io/docs/tasks/tools/install-kubectl/), at least version 1.11 or above.
* Make sure to have jq installed (https://stedolan.github.io/jq/download/).
* Make sure to have aws-iam-authenticator installed (https://github.com/kubernetes-sigs/aws-iam-authenticator), required for eksctl
* Install eksctl (https://eksctl.io/), for example, on macOS with brew tap weaveworks/tap and brew install weaveworks/tap/eksctl, and make sure it's on at least on version 0.23.0.
* Install Docker. It is needed to build the demo application images.

v1beta2 example manifest requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

You can use v1beta1 example manifest with [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [=v0.3.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/legacy-controller/CHANGELOG.md)

### Cluster provisioning

Setup region
```
export AWS_DEFAULT_REGION=<enter AWS region>
```

Create an EKS cluster with eksctl using the following command:
```
eksctl create cluster --name=eksc2 --nodes=3 --alb-ingress-access \
--region=$AWS_DEFAULT_REGION --ssh-access --asg-access  --full-ecr-access \
--external-dns-access --appmesh-access --vpc-cidr 172.16.0.0/16 \
--auto-kubeconfig
#[✔]  EKS cluster "eksc2" is ready
```

Once cluster creation is complete open an other tab and create an other EKS cluster with eksctl using the following command:
Note: Use the public and private subnets created as part of cluster1 in this command. See this (https://eksctl.io/usage/vpc-networking/) for more details.
```
eksctl create cluster --name=eksc1 --nodes=2 --alb-ingress-access \
--region=$AWS_DEFAULT_REGION --ssh-access --asg-access  --full-ecr-access \
--external-dns-access --appmesh-access  --auto-kubeconfig \
--vpc-private-subnets=<comma seperated private subnets> \
--vpc-public-subnets=<comma seperated public subnets> 
#[✔]  EKS cluster "eksc1" is ready
```

When completed, update the KUBECONFIG environment variable in each tab according to the eksctl output, repectively:
```
export KUBECONFIG=~/.kube/eksctl/clusters/eksc2
export KUBECONFIG=~/.kube/eksctl/clusters/eksc1 
Note: Do this respective tabs
```

You have now setup the two clusters and pointing kubectl to respective clusters. Congratulations.

### Deploy App Mesh Custom Components

In order to automatically inject App Mesh components and proxies on pod creation we need to create some custom resources on the clusters. 

Follow the instructions provided [here](../eks/base.md#install-app-mesh--kubernetes-components) to install the App Mesh components in both the clusters.

We are now ready to deploy our front and colorapp applications to respective clusters along with the App Mesh which will span both clusters.

## Setup

1. You can run all commands from this location
   ```
   git clone https://github.com/aws/aws-app-mesh-examples
   cd aws-app-mesh-examples/walkthroughs/howto-k8s-cross-cluster
   ```
2. **Your** account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```
3. **ENVOY_IMAGE** environment variable is set to App Mesh Envoy, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html
    ```
    export ENVOY_IMAGE=...
    ```
4. **VPC_ID** environment variable is set to the VPC where Kubernetes pods are launched. VPC will be used to setup private DNS namespace in AWS using create-private-dns-namespace API. To find out VPC of EKS cluster you can use `aws eks describe-cluster`. See [below](#1-how-can-i-use-cloud-map-namespaces-other-than-privatednsnamespace) for reason why Cloud Map PrivateDnsNamespace is required.
    ```
    export VPC_ID=...
    ```
5. **CLUSTER** environment variables are set
    ```
    export CLUSTER1=eksc1
    export CLUSTER2=eksc2
    ```
6. Deploy
    ```. 
    ./deploy.sh
    ```

## Verify Cloud Map and App Mesh

As a part of deploy command we have pushed the images to ECR, created a namespace in Cloud Map and created the mesh and the DNS entries by virtue of adding the service discovery attributes.

You may verify this, with the following command:
```
aws servicediscovery discover-instances --namespace howto-k8s-cross-cluster.pvt.aws.local \
 --service-name colorapp
```
This should resolve to the backend service.

You can verify under App Mesh console to verify that the virtual nodes, virtual services, virtual router and routes are indeed created.

## Enable network ingress from eksc2 to eksc1

Open port 8080 on security group applied on eksc1 Node group to the eksc2 Security group.

## Test the application

The front service in cluster1 has been exposed as a loadbalancer and can be used directly 
```
>>kubectl get svc -n howto-k8s-cross-cluster
NAME    TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)        AGE
front   LoadBalancer   10.100.145.29   af3c595c8fb3b11e987a30ab4de89fc8-1707174071.us-east-1.elb.amazonaws.com   80:31646/TCP   5h47m

>>curl af3c595c8fb3b11e987a30ab4de89fc8-1707174071.us-east-1.elb.amazonaws.com/color
blue
```

You can also test it using a simple curler pod, like so:
```
>>kubectl -n default run -it curler --image=tutum/curl /bin/bash
root@curler-5bd7c8d767-x657t:/#curl front.howto-k8s-cross-cluster.svc.cluster.local/color
blue
```

Great! You have successfully tested the service communication across clusters using the App Mesh and Cloud Map.

## FAQ
### 1. My front app is unable to talk to colorapp on the seond cluster?
You need to open the port 8080 on second cluster's nodegroup SG, so the front app can talk to it.

### 2. How can I use Cloud Map namespaces other than PrivateDnsNamespace?
AWS Cloud Map supports three types of namespaces;
1. [PublicDnsNamespace](https://docs.aws.amazon.com/cloud-map/latest/api/API_CreatePublicDnsNamespace.html): Namespace that is visible to the internet.
2. [PrivateDnsNamespace](https://docs.aws.amazon.com/cloud-map/latest/api/API_CreatePrivateDnsNamespace.html): Namespace that is visible only in the specified VPC.
3. [HttpNamespace](https://docs.aws.amazon.com/cloud-map/latest/api/API_CreateHttpNamespace.html): Namespace that supports only HTTP discovery using DiscoverInstances. This namespace does not support DNS resolution.

Currently App Mesh only supports backend applications running within VPC boundaries and that are not directly reachable from internet. So this rules out PublicDnsNamespace support. Both PrivateDnsNamespace and HttpNamespace can be supported but given that most applications still use DNS resolution before making a connection to remote service (via Envoy), HttpNamespace cannot be readily used. In future, we plan on leveraging [Envoy's DNS filter](https://github.com/envoyproxy/envoy/issues/6748) to support both PrivateDnsNamespace and HttpNamespace seamlessly. For now it is required to create PrivateDnsNamespace to get both DNS resolution and App Mesh's EDS support. Note that both PrivateDnsNamespace and HttpNamespace services support custom attributes that can be used with DiscoverInstances API.
