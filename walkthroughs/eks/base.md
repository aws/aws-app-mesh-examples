# App Mesh with EKS—Base Deployment

We will cover the base setup of AppMesh with EKS in this part.

## Prerequisites

In order to successfully carry out the base deployment:

- Make sure to have newest [AWS CLI](https://aws.amazon.com/cli/) installed, that is, version `1.16.124` or above.
- Make sure to have `kubectl` [installed](https://kubernetes.io/docs/tasks/tools/install-kubectl/), at least version `1.11` or above.
- Make sure to have `jq` [installed](https://stedolan.github.io/jq/download/).
- Make sure to have `aws-iam-authenticator` [installed](https://github.com/kubernetes-sigs/aws-iam-authenticator), required for eksctl
- Make sure to have `helm` [installed](https://helm.sh/docs/intro/install/).
- Install [eksctl](https://eksctl.io/), for example, on macOS with `brew tap weaveworks/tap` and `brew install weaveworks/tap/eksctl`, and make sure it's on at least on version `0.1.26`.

Note that this walkthrough assumes throughout to operate in the `us-east-2` region.

```sh
export AWS_DEFAULT_REGION=us-east-2
```

## Cluster provisioning

Create an EKS cluster with `eksctl` using the following command:

```sh
eksctl create cluster \
--name appmeshtest \
--version 1.12 \
--nodes-min 2 \
--nodes-max 3 \
--nodes 2 \
--auto-kubeconfig \
--full-ecr-access \
--appmesh-access
# ...
# [✔]  EKS cluster "appmeshtest" in "us-east-2" region is ready
```

When completed, update the `KUBECONFIG` environment variable according to the `eksctl` output:

```sh
export KUBECONFIG=~/.kube/eksctl/clusters/appmeshtest
```

## Install App Mesh  Kubernetes components

In order to automatically inject App Mesh components and proxies on pod creation we need to create some custom resources on the clusters. We will use *helm* for that.

*Code base*

Clone the repo and cd into the appropriate directory. We will be running all commands from this path.
```sh
git clone https://github.com/aws/aws-app-mesh-examples (https://github.com/aws/aws-app-mesh-examples).git
cd aws-app-mesh-examples/walkthroughs/eks/
```

*Install App Mesh Components*

Run the following set of commands to install the App Mesh controller and Injector components 

```sh
helm repo add eks https://aws.github.io/eks-charts
kubectl create ns appmesh-system
kubectl apply -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/appmesh-controller/crds/crds.yaml
helm upgrade -i appmesh-controller eks/appmesh-controller --namespace appmesh-system
helm upgrade -i appmesh-inject eks/appmesh-inject --namespace appmesh-system --set mesh.create=true --set mesh.name=color-mesh

# Optionally add tracing
helm upgrade -i appmesh-inject eks/appmesh-inject --namespace appmesh-system --set tracing.enabled=true --set tracing.provider=x-ray
```

Now you're all set, you've provisioned the EKS cluster and set up App Mesh components that automate injection of Envoy and take care of the life cycle management of the mesh resources such as virtual nodes, virtual services, and virtual routes.

At this point, you also might want to check the custom resources the App Mesh Controller uses:

```sh
kubectl api-resources --api-group=appmesh.k8s.aws
# NAME              SHORTNAMES   APIGROUP          NAMESPACED   KIND
# meshes                         appmesh.k8s.aws   false        Mesh
# virtualnodes                   appmesh.k8s.aws   true         VirtualNode
# virtualservices                appmesh.k8s.aws   true         VirtualService
```

## The application

We use the [howto-k8s-cloudmap](https://github.com/aws/aws-app-mesh-examples/tree/master/walkthroughs/howto-k8s-cloudmap) to demonstrate the usage of App Mesh with EKS.

Make sure all resources have been created, using the following command:

```sh
kubectl -n appmesh-system \
          get deploy,po,svc,virtualnode.appmesh.k8s.aws,virtualservice.appmesh.k8s.aws

NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.extensions/appmesh-controller   1/1     1            1           72m
deployment.extensions/appmesh-inject       1/1     1            1           72m

NAME                                      READY   STATUS    RESTARTS   AGE
pod/appmesh-controller-5977c4b87d-68vb6   1/1     Running   1          72m
pod/appmesh-inject-767d8c8f7c-dk4fk       1/1     Running   0          72m

NAME                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/appmesh-inject   ClusterIP   10.100.192.220   <none>        443/TCP   72m
```

```sh
kubectl get pod -n howto-k8s-cloudmap -o wide

NAME                             READY   STATUS    RESTARTS   AGE   IP               NODE                                           NOMINATED NODE   READINESS GATES
colorapp-blue-768d5c96b9-jdbqg   2/2     Running   0          11m   192.168.33.13    ip-192-168-56-114.us-east-2.compute.internal   <none>           <none>
colorapp-red-9c8c4cbfc-z4k22     2/2     Running   0          11m   192.168.15.43    ip-192-168-12-143.us-east-2.compute.internal   <none>           <none>
front-7d559c8949-qqwmb           2/2     Running   0          11m   192.168.12.218   ip-192-168-12-143.us-east-2.compute.internal   <none>           <none>
```

Now, validate the mesh creation using the `aws` CLI:

```sh
aws appmesh list-meshes
# {
#     "meshes": [
#         {
#             "meshName": "howto-k8s-cloudmap",
#             "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/howto-k8s-cloudmap"
#         }
#     ]
# }

aws appmesh list-virtual-services --mesh-name howto-k8s-cloudmap
# {
#     "virtualServices": [
#         {
#             "meshName": "howto-k8s-cloudmap",
#             "virtualServiceName": "colorteller.demo.svc.cluster.local",
#             "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/howto-k8s-cloudmap/virtualService/front.howto-k8s-cloudmap.pvt.aws.local"
#         },
#         {
#             "meshName": "howto-k8s-cloudmap",
#             "virtualServiceName": "colorgateway.demo.svc.cluster.local",
#             "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/howto-k8s-cloudmap/virtualService/colorapp.howto-k8s-cloudmap.pvt.aws.local"
#         }
#     ]
# }

aws appmesh list-virtual-nodes --mesh-name howto-k8s-cloudmap
#{
#    "virtualNodes": [
#        {
#            "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/howto-k8s-cloudmap/virtualNode/colorapp-blue-howto-k8s-cloudmap",
#            "meshName": "howto-k8s-cloudmap",
#            "virtualNodeName": "colorapp-blue-howto-k8s-cloudmap"
#        },
#        {
#            "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/howto-k8s-cloudmap/virtualNode/colorapp-red-howto-k8s-cloudmap",
#            "meshName": "howto-k8s-cloudmap",
#            "virtualNodeName": "colorapp-red-howto-k8s-cloudmap"
#        },
#        {
#            "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/howto-k8s-cloudmap/virtualNode/front-howto-k8s-cloudmap",
#            "meshName": "howto-k8s-cloudmap",
#            "virtualNodeName": "front-howto-k8s-cloudmap"
#        }
#    ]
}

```

You can access the `front` service of the app in-cluster as follows:

```sh
kubectl -n howto-k8s-cloudmap \                              
          run -it curler \                                                            
          --image=tutum/curl /bin/bash
# If you don't see a command prompt, try pressing enter.
# root@curler:/#
curl front.howto-k8s-cloudmap:8080/color
# blue

# root@curler:/#
curl front.howto-k8s-cloudmap:8080/color
# red
```

With this you're done concerning the base deployment. You can now move on to day 2 ops tasks such as using [CloudWatch](o11y-cloudwatch.md) with App Mesh on EKS.

## Clean-up

The AWS App Mesh Controller For Kubernetes performs clean-up of the mesh and its dependent resources (virtual nodes, services, etc.) when deleting the demo namespace and the mesh custom resource like so:

```sh
kubectl delete ns appmesh-system && kubectl delete ns howto-k8s-cloudmap && kubectl delete mesh howto-k8s-cloudmap
```

Finally, get rid of the EKS cluster to free all compute, networking, and storage resources, using:

```sh
eksctl delete cluster --name appmeshtest
```
