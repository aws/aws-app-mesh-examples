## Overview
In this walk through we'll be setting up applications with different IP version capabilities and configuring App Mesh resources.

## IP Preferences in Mesh
With the introduction of IPv6 support in App Mesh a new IP preference field has been added to mesh. IP preferences will impact how Envoy configuration gets generated. The possible values for IP preferences in Mesh are the following.

Since EKS is single stack, an EKS cluster can be either IPv6 or IPv4. The IpPreference of a Mesh can have two possible values:

- IPv4_ONLY: only use IPv4
- IPv6_ONLY: only use IPv6

This field is not a required setting for mesh. Users could have No Preference by not specifying the field. 

For an IPv6 cluster, the mesh ip preference is by default to IPv6. 

Meshes: Adding an IP preference to a mesh impacts how Envoy configuration will be generated for all virtual nodes and virtual gateways within the mesh. A sample mesh spec that includes an IP preference can be seen below.

```
"spec": {
   "serviceDiscovery": {
   "ipPreference": "IPv6_ONLY"
   }
}
```

## Prerequisites
1. To use the IPv6 feature create EKS cluster with ipFamily as IPv6. Sample IPv6 yaml file: [IPv6 EKS cluster](ipv6-cluster.yaml)
2. Install appmesh-controller.

Note: Run the following to check that cluster name is set.

       kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r '.spec.template.spec.containers[].args[] | select(contains("cluster-name"))'

   You should get as output:

   *--cluster-name=&lt;name-of-your-cluster&gt;*

   If cluster-name is not set, update the App Mesh controller to set it by running:

       helm upgrade -i appmesh-controller eks/appmesh-controller --namespace appmesh-system --set clusterName=<name-of-your-cluster>

2. v1beta2 example manifest requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```
2. Install Docker. It is needed to build the demo application images.


## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-ipv6 folder, all commands will be ran from this location
2. **Your** account id:

    export AWS_ACCOUNT_ID=<your_account_id>

3. **Region** e.g. us-west-2

    export AWS_DEFAULT_REGION=us-west-2

4. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.
5. VPC_ID environment variable is set to the VPC where Kubernetes pods are launched. VPC will be used to setup private DNS namespace in AWS using create-private-dns-namespace API. To find out VPC of EKS cluster you can use aws eks describe-cluster.
```
aws eks describe-cluster --name <name-of-you-cluster> | grep vpcId
```

```
export VPC_ID=...
```

*Note that the example apps use go modules. If you have trouble accessing https://proxy.golang.org during the deployment you can override the GOPROXY by setting GO_PROXY=direct*

```
GO_PROXY=direct ./deploy.sh (cloudmap | dns)
```

## CloudMap Service Discovery
1. Run the following command
 ```
 ./deploy.sh cloudmap
 ```
2. Add a curler on your cluster
```
kubectl run -i --tty curler --image=public.ecr.aws/k8m1l3p1/alpine/curler:latest --rm
```
3. Run the commands on curler to test by requesting color.

```
curl client.howto-k8s-ipv6.svc.cluster.local:8080/color; echo;
```
4. To clean example with CloudMap service discovery:

```
kubectl delete -f _output/cloud/manifest.yaml
```

## DNS Service Discovery
1. Run the following command
 ```
 ./deploy.sh dns
 ```
2. Add a curler on your cluster:
```
kubectl run -i --tty curler --image=public.ecr.aws/k8m1l3p1/alpine/curler:latest --rm
```
3. Run the commands on curler to test by requesting color.

```
curl front.howto-k8s-ipv6.svc.cluster.local:8080/color; echo;
```
4. To clean example with DNS service discovery:

```
kubectl delete -f _output/dns/manifest.yaml
```
