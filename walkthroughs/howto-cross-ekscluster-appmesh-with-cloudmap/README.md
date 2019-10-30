## Overview
In this article, we are going to start to explore how to use App Mesh across clusters. AppMesh is a service mesh that lets you control and monitor services spanning multiple AWS compute environments. We'll demonstrate this by using 2 EKS clusters within a VPC and a AppMesh that spans the clusters using CloudMap. This example shows how Kubernetes deployments can use AWS CloudMap for service-discovery when using App Mesh.

We will use two EKS clusters in a single VPC to explain the concept of cross cluster mesh using Cloud Map. The diagram below illustrates the big picture. This is intentionally meant to be a simple example for clarity, but in the real world the AppMesh can span multiple different compute types like ECS, fargate, Kubernetes on EC2 etc.

In this example there are two EKS clusters within a VPC and a mesh spanning both clusters . The setup CloudMap services and three EKS Deployments as described below. The front container will be deployed in Cluster 1 and the color containers will be deployed in Cluster 2 . The Goal is to have a single Mesh across the clusters works via DNS resolution using CloudMap


*CLUSTERS*

We will spin up two EKS clusters in the same VPC for simplicity and configure a Mesh as we deploy the clusters components.

*DEPLOYMENTS*

There are two deployments of colorapp, blue and red. Pods of both these deployments are registered behind service colorapp.appmesh-demo.pvt.aws.local. Blue pods are registered with the mesh as colorapp-blue virtual-node and red pods as colorapp-red virtual-node. These virtual-nodes are configured to use AWS CloudMap as service-discovery, hence the IP addresses of these pods are registered with the CloudMap service with corresponding attributes.
Additionally a colorapp virtual-service is defined that routes traffic to blue and red virtual-nodes.  

Front app acts as a gateway that makes remote calls to colorapp. Front app has single deployment with pods registered with the mesh as front virtual-node. This virtual-node uses colorapp virtual-service as backend. This configures Envoy injected into front pod to use App Mesh's EDS to discover colorapp endpoints.


*MESH*

AppMesh components will be deployed from one of the two clusters. It does not really matter where you deploy it from. It will have various components deployed . A virtual node per service and a Virtual Service which will have a router with routes tied (provider) to route traffic between red and blue equally. We will use a custom CRD, mesh controller and  mesh inject components that will handle the mesh creation using the standard kubectl. This will auto inject proxy sidecars on pod creation.

*CLOUDMAP*

As we create the mesh we will use service discovery attributes which will automatically create the DNS records in the namespace that we have pre-created. The front application in cluster one will leverage this DNS entry in Cloud Map to talk to the colorapp on the second cluster.  

So, Lets get started..

## Prerequisites

In order to successfully carry out the base deployment:

* Make sure to have newest AWS CLI (https://aws.amazon.com/cli/) installed, that is, version 1.16.268 or above.
* Make sure to have kubectl installed (https://kubernetes.io/docs/tasks/tools/install-kubectl/), at least version 1.11 or above.
* Make sure to have jq installed (https://stedolan.github.io/jq/download/).
* Make sure to have aws-iam-authenticator installed (https://github.com/kubernetes-sigs/aws-iam-authenticator), required for eksctl
* Install eksctl (https://eksctl.io/), for example, on macOS with brew tap weaveworks/tap and brew install weaveworks/tap/eksctl, and make sure it's on at least on version 0.1.26.

Note that this walkthrough assumes throughout to operate in the us-east-1 region.

### Cluster provisioning

Create an EKS cluster with eksctl using the following command:
```
eksctl create cluster --name=eksc2 --nodes=3 --alb-ingress-access 
--region=us-east-1 --ssh-access --asg-access  --full-ecr-access  
--external-dns-access --appmesh-access --vpc-cidr 172.16.0.0/16
--auto-kubeconfig
#[✔]  EKS cluster "eksc2-useast1" in "us-east-1" region is ready
```

Once cluster creation is complete open an other tab and create an other EKS cluster with eksctl using the following command:
Note: Use the public and private subnets created as part of cluster1 in this command. See this (https://eksctl.io/usage/vpc-networking/) for more details.
```
eksctl create cluster --name=eksc1 --nodes=2 --alb-ingress-access 
--region=us-east-1 --ssh-access --asg-access  --full-ecr-access  
--external-dns-access --appmesh-access  --auto-kubeconfig 
--vpc-private-subnets=<comma seperated private subnets>
--vpc-public-subnets=<comma seperated public subnets>
#[✔]  EKS cluster "eksc1" in "us-east-1" region is ready
```

When completed, update the KUBECONFIG environment variable in each tab according to the eksctl output, repectively:
```
export KUBECONFIG=~/.kube/eksctl/clusters/eksc2
export KUBECONFIG=~/.kube/eksctl/clusters/eksc1 
Note: Do this respective tabs
```

You have now setup the two clusters and pointing kubectl to respective clusters. Congratulations.

### Deploy AppMesh Custom Components

In order to automatically inject AppMesh components and proxies on pod creation we need to create some custom resources on the clusters. We will use *helm* for that. We need install tiller on both the clusters and run the following commands on both clusters for that.

*Install tiller*

Run the following series of commands in order
```
kubectl create -f helm/tiller-rbac.yml --record --save-config
helm init --service-account tiller
kubectl -n kube-system rollout status deploy tiller-deploy

Note: The last command will tell you if the rollout is finished
```

*Install AppMesh Components*

Run the following set of commands to install the AppMesh controller and Injector components 

```
helm repo add eks https://aws.github.io/eks-charts
helm upgrade -i appmesh-controller eks/appmesh-controller --namespace appmesh-system
helm upgrade -i appmesh-inject eks/appmesh-inject --namespace appmesh-system --set mesh.create=true --set mesh.name=global

Opitionally add tracing
helm upgrade -i appmesh-inject eks/appmesh-inject --namespace appmesh-system --set tracing.enabled=true --set tracing.provider=x-ray
```

We are now ready to deploy our front and colorapp applications to respective clusters along with the appmesh which will span both clusters.


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
6. **CLUSTER** environment variables are set
    ```
    export CLUSTER1=<cluster name>
    export CLUSTER2=<cluster name>
    ```
7. Deploy
    ```. 
    ./deploy.sh
    ```

## FAQ
### 1. My front app is unable to talk to colorapp on the seond cluster?
You need to open the port 8080 on second cluster's nodegroup SG, so the front app can talk to it.

### 2. How can I use Cloud Map namespaces other than PrivateDnsNamespace?
AWS Cloud Map supports three types of namespaces;
1. [PublicDnsNamespace](https://docs.aws.amazon.com/cloud-map/latest/api/API_CreatePublicDnsNamespace.html): Namespace that is visible to the internet.
2. [PrivateDnsNamespace](https://docs.aws.amazon.com/cloud-map/latest/api/API_CreatePrivateDnsNamespace.html): Namespace that is visible only in the specified VPC.
3. [HttpNamespace](https://docs.aws.amazon.com/cloud-map/latest/api/API_CreateHttpNamespace.html): Namespace that supports only HTTP discovery using DiscoverInstances. This namespace does not support DNS resolution.

Currently App Mesh only supports backend applications running within VPC boundaries and that are not directly reachable from internet. So this rules out PublicDnsNamespace support. Both PrivateDnsNamespace and HttpNamespace can be supported but given that most applications still use DNS resolution before making a connection to remote service (via Envoy), HttpNamespace cannot be readily used. In future, we plan on leveraging [Envoy's DNS filter](https://github.com/envoyproxy/envoy/issues/6748) to support both PrivateDnsNamespace and HttpNamespace seamlessly. For now it is required to create PrivateDnsNamespace to get both DNS resolution and App Mesh's EDS support. Note that both PrivateDnsNamespace and HttpNamespace services support custom attributes that can be used with DiscoverInstances API.