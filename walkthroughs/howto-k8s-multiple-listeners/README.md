## Overview
This example illustrates usage of multiple listeners using AppMesh on EKS. This walkthrough will create two NLBs that we will route requests to a Virtual Gateway with two listeners on port 8080 and 8090. The Virtual Gateway will route these requests through a Virtual Router that ports those over to a Virtual Node. We should be able to receive "hello world" responses on both ports 8080 and 8090.

## Prerequisites
1. [Walkthrough: App Mesh with EKS](../eks/)

2. The manifest in this walkthrough requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

3. Install Docker

## Setup
1. Clone this repository and navigate to the walkthrough/howto-k8s-egress folder, all commands will be ran from this location

2. Your AWS account id:

```
export AWS_ACCOUNT_ID=<your_account_id>
```

3. Region e.g. us-west-2

```
export AWS_DEFAULT_REGION=us-west-2
```

4. Deploy the application and Mesh

```
kubectl apply -f manifest.yaml
```

## Verify

Validate port 8080 and port 8090 are accepted

```
export EXTERNAL_IP1=$(kubectl get svc/colors-gw-1 -n colors -o go-template='{{(index .status.loadBalancer.ingress 0).hostname}}'
export EXTERNAL_IP2=$(kubectl get svc/colors-gw-2 -n colors -o go-template='{{(index .status.loadBalancer.ingress 0).hostname}}'

curl $EXTERNAL_IP1
curl $EXTERNAL_IP2
```

* using two load balancers because it requires manual setup to create two listeners (see https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2234)
