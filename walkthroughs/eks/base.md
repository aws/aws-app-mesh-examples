# App Mesh with EKS—Base Deployment

We will cover the base setup of AppMesh with EKS in this part.

## Prerequisites

In order to successfully carry out the base deployment:

- Make sure to have newest [AWS CLI](https://aws.amazon.com/cli/) installed, that is, version `1.16.124` or above.
- Make sure to have `kubectl` [installed](https://kubernetes.io/docs/tasks/tools/install-kubectl/), at least version `1.11` or above.
- Make sure to have `jq` [installed](https://stedolan.github.io/jq/download/).
- Make sure to have `aws-iam-authenticator` [installed](https://github.com/kubernetes-sigs/aws-iam-authenticator), required for eksctl
- Install [eksctl](https://eksctl.io/), for example, on macOS with `brew tap weaveworks/tap` and `brew install weaveworks/tap/eksctl`, and make sure it's on at least on version `0.1.26`.

Note that this walkthrough assumes throughout to operate in the `us-east-2` region.

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
```
>> git clone https://github.com/aws/aws-app-mesh-examples (https://github.com/aws/aws-app-mesh-examples).git
>> cd aws-app-mesh-examples/walkthroughs/eks/
```

*Install Helm*

```
>>brew install kubernetes-helm
```

*Install App Mesh Components*

Run the following set of commands to install the App Mesh controller and Injector components 

```
helm repo add eks https://aws.github.io/eks-charts
kubectl create ns appmesh-system
kubectl apply -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/appmesh-controller/crds/crds.yaml
helm upgrade -i appmesh-controller eks/appmesh-controller --namespace appmesh-system
helm upgrade -i appmesh-inject eks/appmesh-inject --namespace appmesh-system --set mesh.create=true --set mesh.name=color-mesh

Opitionally add tracing
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

We use the [colorapp](https://github.com/awslabs/aws-app-mesh-examples/tree/master/examples/apps/colorapp) to demonstrate the usage of App Mesh with EKS.

Install the example application from the location where you checked out the [AWS App Mesh Controller For Kubernetes](https://github.com/aws/aws-app-mesh-controller-for-k8s):

```sh
cd aws-app-mesh-controller-for-k8s
make example
```

Make sure all resources have been created, using the following command:

```sh
kubectl -n appmesh-demo \
          get deploy,po,svc,virtualnode.appmesh.k8s.aws,virtualservice.appmesh.k8s.aws

# NAME                                      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
# deployment.extensions/colorgateway        1         1         1            1           1m
# deployment.extensions/colorteller         1         1         1            1           1m
# deployment.extensions/colorteller-black   1         1         1            1           1m
# deployment.extensions/colorteller-blue    1         1         1            1           1m
# deployment.extensions/colorteller-red     1         1         1            1           1m
#
# NAME                                     READY   STATUS    RESTARTS   AGE
# pod/colorgateway-cc6464d75-qbznr         2/2     Running   0          1m
# pod/colorteller-86664b5956-zhb44         2/2     Running   0          1m
# pod/colorteller-black-6787756c7b-5sgfq   2/2     Running   0          1m
# pod/colorteller-blue-55d6f99dc6-wltdj    2/2     Running   0          1m
# pod/colorteller-red-578866ffb-rztfc      2/2     Running   0          1m
#
# NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
# service/colorgateway        ClusterIP   10.100.45.69    <none>        9080/TCP   1m
# service/colorteller         ClusterIP   10.100.186.86   <none>        9080/TCP   1m
# service/colorteller-black   ClusterIP   10.100.52.209   <none>        9080/TCP   1m
# service/colorteller-blue    ClusterIP   10.100.82.44    <none>        9080/TCP   1m
# service/colorteller-red     ClusterIP   10.100.19.144   <none>        9080/TCP   1m
#
# NAME                                            AGE
# virtualnode.appmesh.k8s.aws/colorgateway        1m
# virtualnode.appmesh.k8s.aws/colorteller         1m
# virtualnode.appmesh.k8s.aws/colorteller-black   1m
# virtualnode.appmesh.k8s.aws/colorteller-blue    1m
# virtualnode.appmesh.k8s.aws/colorteller-red     1m
#
# NAME                                                       AGE
# virtualservice.appmesh.k8s.aws/colorgateway.appmesh-demo   1m
# virtualservice.appmesh.k8s.aws/colorteller.appmesh-demo    1m
```

Now, validate the mesh creation using the `aws` CLI:

```sh
aws appmesh list-meshes --region us-east-2
# {
#     "meshes": [
#         {
#             "meshName": "color-mesh",
#             "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/color-mesh"
#         }
#     ]
# }

aws appmesh list-virtual-services \
      --mesh-name color-mesh \
      --region us-east-2
# {
#     "virtualServices": [
#         {
#             "meshName": "color-mesh",
#             "virtualServiceName": "colorteller.demo.svc.cluster.local",
#             "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/color-mesh/virtualService/colorteller.demo.svc.cluster.local"
#         },
#         {
#             "meshName": "color-mesh",
#             "virtualServiceName": "colorgateway.demo.svc.cluster.local",
#             "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/color-mesh/virtualService/colorgateway.demo.svc.cluster.local"
#         }
#     ]
# }

aws appmesh list-virtual-nodes \
      --mesh-name color-mesh \
      --region us-east-2
# {
#     "virtualNodes": [
#         {
#             "meshName": "color-mesh",
#             "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/color-mesh/virtualNode/colorteller-black",
#             "virtualNodeName": "colorteller-black"
#         },
#         {
#             "meshName": "color-mesh",
#             "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/color-mesh/virtualNode/colorteller-blue",
#             "virtualNodeName": "colorteller-blue"
#         },
#         {
#             "meshName": "color-mesh",
#             "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/color-mesh/virtualNode/colorteller",
#             "virtualNodeName": "colorteller"
#         },
#         {
#             "meshName": "color-mesh",
#             "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/color-mesh/virtualNode/colorgateway",
#             "virtualNodeName": "colorgateway"
#         },
#         {
#             "meshName": "color-mesh",
#             "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/color-mesh/virtualNode/colorteller-red",
#             "virtualNodeName": "colorteller-red"
#         }
#     ]
# }
```

You can access the `gateway` service of the color app in-cluster as follows:

```sh
kubectl -n appmesh-demo \
          run -it curler \
          --image=tutum/curl /bin/bash
# If you don't see a command prompt, try pressing enter.
# root@curler-5b467f98bb-lmwm9:/#
curl colorgateway:9080/color
# {"color":"black", "stats": {"black":1}}

# root@curler-5b467f98bb-lmwm9:/#
curl colorgateway:9080/color
# {"color":"white", "stats": {"black":0.67,"white":0.33}}
...
# root@curler-5b467f98bb-lmwm9:/#
curl colorgateway:9080/color
# {"color":"blue", "stats": {"black":0.5,"blue":0.2,"white":0.3}}
```

With this you're done concerning the base deployment. You can now move on to day 2 ops tasks such as using [CloudWatch](o11y-cloudwatch.md) with App Mesh on EKS.

## Clean-up

The AWS App Mesh Controller For Kubernetes performs clean-up of the mesh and its dependent resources (virtual nodes, services, etc.) when deleting the demo namespace and the mesh custom resource like so:

```sh
kubectl delete ns appmesh-demo && kubectl delete mesh color-mesh
```

Finally, get rid of the EKS cluster to free all compute, networking, and storage resources, using:

```sh
eksctl delete cluster \
         --name appmeshtest
```
