# App Mesh with EKS—Base Deployment

We will cover the base setup of AppMesh with EKS in this part.

## Prerequisites

In order to successfully carry out the base deployment:

- Make sure to have newest [AWS CLI](https://aws.amazon.com/cli/) installed, that is, version `1.18.82` or above.
- Make sure to have `kubectl` [installed](https://kubernetes.io/docs/tasks/tools/install-kubectl/), at least version `1.13` or above.
- Make sure to have `jq` [installed](https://stedolan.github.io/jq/download/).
- Make sure to have `aws-iam-authenticator` [installed](https://github.com/kubernetes-sigs/aws-iam-authenticator), required for eksctl
- Make sure to have `helm` [installed](https://helm.sh/docs/intro/install/).
- Install [eksctl](https://eksctl.io/). See [appendix](#appendix) for eksctl install instructions. Please make you have version `0.21.0` or above installed

Note that this walkthrough assumes throughout to operate in the `us-west-2` region.

```sh
export AWS_DEFAULT_REGION=us-west-2
```

## Cluster provisioning

Create an EKS cluster with `eksctl` using the following command:

```sh
eksctl create cluster \
--name appmeshtest \
--nodes-min 2 \
--nodes-max 3 \
--nodes 2 \
--auto-kubeconfig \
--full-ecr-access \
--appmesh-access
# ...
# [✔]  EKS cluster "appmeshtest" in "us-west-2" region is ready
```

When completed, update the `KUBECONFIG` environment variable according to the `eksctl` output:

```sh
export KUBECONFIG=~/.kube/eksctl/clusters/appmeshtest
```

## Install App Mesh  Kubernetes components

In order to automatically inject App Mesh components and proxies on pod creation we need to create some custom resources on the clusters. We will use *helm* for that.

**Code base**

Clone the repo and cd into the appropriate directory. We will be running all commands from this path.
```sh
git clone https://github.com/aws/aws-app-mesh-examples.git
cd aws-app-mesh-examples/walkthroughs/eks/
```

**Install App Mesh Components**

Run the following set of commands to install the App Mesh controller 

```sh
helm repo add eks https://aws.github.io/eks-charts
helm repo update
kubectl create ns appmesh-system
kubectl apply -k "https://github.com/aws/eks-charts/stable/appmesh-controller/crds?ref=master"
helm upgrade -i appmesh-controller eks/appmesh-controller --namespace appmesh-system

```

Now you're all set, you've provisioned the EKS cluster and set up App Mesh components that automate injection of Envoy and take care of the life cycle management of the App Mesh resources such as meshes, virtual nodes, virtual services, and virtual routers.

At this point, you also might want to check the custom resources the App Mesh Controller uses:

```sh
kubectl api-resources --api-group=appmesh.k8s.aws
# NAME              SHORTNAMES   APIGROUP          NAMESPACED   KIND
# meshes                         appmesh.k8s.aws   false        Mesh
# virtualnodes                   appmesh.k8s.aws   true         VirtualNode
# virtualrouters                 appmesh.k8s.aws   true         VirtualRouter
# virtualservices                appmesh.k8s.aws   true         VirtualService
```

## The application

We use the [howto-k8s-http2](https://github.com/aws/aws-app-mesh-examples/tree/main/walkthroughs/howto-k8s-http2) to demonstrate the usage of App Mesh with EKS.

Make sure all resources have been created, using the following command:

```sh
kubectl -n appmesh-system get deploy,po,svc

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/appmesh-controller   1/1     1            1           19h

NAME                                      READY   STATUS    RESTARTS   AGE
pod/appmesh-controller-5954995557-tsnf9   1/1     Running   0          19h

NAME                                         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)              AGE
service/appmesh-controller-webhook-service   ClusterIP   10.100.18.188    <none>        443/TCP              19h
```

```sh
kubectl get pod -n howto-k8s-http2 -o wide

NAME                      READY   STATUS    RESTARTS   AGE     IP               NODE                                          NOMINATED NODE   READINESS GATES
blue-64885d7dd6-bjlx5     2/2     Running   0          3m48s   192.168.83.144   ip-192-168-70-3.us-west-2.compute.internal    <none>           1/1
client-6ddfdd884d-l9nvv   2/2     Running   0          3m49s   192.168.87.223   ip-192-168-70-3.us-west-2.compute.internal    <none>           1/1
green-5674cfb556-65qch    2/2     Running   0          3m48s   192.168.1.139    ip-192-168-4-114.us-west-2.compute.internal   <none>           1/1
red-5bf7f49fbd-86f54      2/2     Running   0          3m49s   192.168.82.36    ip-192-168-70-3.us-west-2.compute.internal    <none>           1/1
```

Now, validate the mesh creation using the `aws` CLI:

```sh
aws appmesh list-meshes

# {
#    "meshes": [
#        {
#            "arn": "arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-http2",
#            "createdAt": 1592578534.868,
#            "lastUpdatedAt": 1592578534.868,
#            "meshName": "howto-k8s-http2",
#            "meshOwner": "1234567890",
#            "resourceOwner": "1234567890",
#            "version": 1
#        }
#    ]
# }

aws appmesh list-virtual-services --mesh-name howto-k8s-http2

# {
#    "virtualServices": [
#        {
#            "arn": "arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-http2/virtualService/color.howto-k8s-http2.svc.cluster.local",
#            "createdAt": 1592578534.971,
#            "lastUpdatedAt": 1592578535.237,
#            "meshName": "howto-k8s-http2",
#            "meshOwner": "1234567890",
#            "resourceOwner": "1234567890",
#            "version": 2,
#            "virtualServiceName": "color.howto-k8s-http2.svc.cluster.local"
#        }
#    ]
# }

aws appmesh list-virtual-nodes --mesh-name howto-k8s-http2

# {
#    "virtualNodes": [
#        {
#            "arn": "arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-http2/virtualNode/green_howto-k8s-http2",
#            "createdAt": 1592578534.934,
#            "lastUpdatedAt": 1592578534.934,
#            "meshName": "howto-k8s-http2",
#            "meshOwner": "1234567890",
#            "resourceOwner": "1234567890",
#            "version": 1,
#            "virtualNodeName": "green_howto-k8s-http2"
#        },
#        {
#            "arn": "arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-http2/virtualNode/client_howto-k8s-http2",
#            "createdAt": 1592578534.965,
#            "lastUpdatedAt": 1592578534.965,
#            "meshName": "howto-k8s-http2",
#            "meshOwner": "1234567890",
#            "resourceOwner": "1234567890",
#            "version": 1,
#            "virtualNodeName": "client_howto-k8s-http2"
#        },
#        {
#            "arn": "arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-http2/virtualNode/blue_howto-k8s-http2",
#            "createdAt": 1592578534.929,
#            "lastUpdatedAt": 1592578534.929,
#            "meshName": "howto-k8s-http2",
#            "meshOwner": "1234567890",
#            "resourceOwner": "1234567890",
#            "version": 1,
#            "virtualNodeName": "blue_howto-k8s-http2"
#        },
#        {
#            "arn": "arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-http2/virtualNode/red_howto-k8s-http2",
#            "createdAt": 1592578534.91,
#            "lastUpdatedAt": 1592578534.91,
#            "meshName": "howto-k8s-http2",
#            "meshOwner": "1234567890",
#            "resourceOwner": "1234567890",
#            "version": 1,
#            "virtualNodeName": "red_howto-k8s-http2"
#        }
#    ]
# }

aws appmesh list-virtual-routers --mesh-name howto-k8s-http2

# {
#     "virtualRouters": [
#        {
#            "arn": "arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-http2/virtualRouter/color_howto-k8s-http2",
#            "createdAt": 1592578535.039,
#            "lastUpdatedAt": 1592578535.039,
#            "meshName": "howto-k8s-http2",
#            "meshOwner": "1234567890",
#            "resourceOwner": "1234567890",
#            "version": 1,
#            "virtualRouterName": "color_howto-k8s-http2"
#        }
#    ]
# }

```

You can access the `color` service of the app in-cluster as follows:

```sh
kubectl -n howto-k8s-http2 port-forward deployment/client 7000:8080 &

# Color virtual service uses the color virtual router with even distribution to 3 virtual nodes (red, blue, and green) over HTTP/2. Prove this by running the following command a few times:

curl localhost:7000/color ; echo;
red

curl localhost:7000/color ; echo;
green

curl localhost:7000/color ; echo;
blue
```

With this you're done concerning the base deployment. You can now move on to day 2 ops tasks such as using [CloudWatch](o11y-cloudwatch.md) with App Mesh on EKS.

## Clean-up

The AWS App Mesh Controller For Kubernetes performs clean-up of the mesh and its dependent resources (virtual nodes, services, virtual routers etc.) when deleting the demo namespace and the mesh custom resource like so:

```sh
kubectl delete ns howto-k8s-http2 && kubectl delete mesh howto-k8s-http2
```

```sh
helm delete appmesh-controller -n appmesh-system
```


Finally, get rid of the EKS cluster to free all compute, networking, and storage resources, using:

```sh
eksctl delete cluster --name appmeshtest
```


## Appendix

### eksctl Installation

```sh
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

sudo mv -v /tmp/eksctl /usr/local/bin
```

```sh
eksctl version
0.21.0
```
