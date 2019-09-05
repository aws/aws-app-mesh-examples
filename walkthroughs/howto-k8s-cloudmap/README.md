## Overview
This example shows how Kubernetes deployments can use AWS CloudMap for service-discovery when using App Mesh. 

In this example there are two CloudMap services and three K8s Deployments as described below.

### Color
There are two deployments of colorapp, _blue_ and _red_. Pods of both these deployments are registered behind service colorapp.howto-k8s-cloudmap.pvt.aws.local. Blue pods are registered with the mesh as colorapp-blue virtual-node and red pods as colorapp-red virtual-node. These virtual-nodes are configured to use AWS CloudMap as service-discovery, hence the IP addresses of these pods are registered with the CloudMap service with corresponding attributes.

Additionally a colorapp virtual-service is defined that routes traffic to blue and red virtual-nodes.

### Front
Front app acts as a gateway that makes remote calls to colorapp. Front app has single deployment with pods registered with the mesh as _front_ virtual-node. This virtual-node uses colorapp virtual-service as backend. This configures Envoy injected into front pod to use App Mesh's EDS to discover colorapp endpoints.

## Prerequisites
[Walkthrough: App Mesh with EKS](../eks/)

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
5. **VPC_ID** environment variable is set to the VPC where Kubernetes pods are launched. VPC will be used to setup private DNS namespace in AWS using create-private-dns-namespace API. To find out VPC of EKS cluster you can use `aws eks describe-cluster`
    ```
    export VPC_ID=...
    ```
6. Deploy
    ```. 
    ./deploy.sh
    ```