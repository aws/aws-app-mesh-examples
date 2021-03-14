## Configure Frontend and Backend Account Profiles

```
cat ~/.aws/credentials

[frontend]
aws_access_key_id =  ...
aws_secret_access_key = ...
[backend]
aws_access_key_id = ...
aws_secret_access_key = ...

cat ~/.aws/config

[profile frontend]
region = us-west-2
[profile backend]
region = us-west-2
```

## Deploy the Infrastructure

```
./infrasctucture/setup.sh
```

## Deploy EKS

```
./eks/setup.sh
```

## Deploy the App Mesh Controller on our Frontend Cluster

```
kubectl config use-context <iam_user>@am-multi-account-1.<region>.eksctl.io
```

```
helm repo add eks https://aws.github.io/eks-charts
```

```
kubectl create ns appmesh-system
helm upgrade -i appmesh-controller eks/appmesh-controller \
--namespace appmesh-system

kubectl -n appmesh-system get pods
```

## Deploy and Share Mesh

```
kubectl create ns yelb
kubectl label namespace yelb mesh=am-multi-account-mesh
kubectl label namespace yelb "appmesh.k8s.aws/sidecarInjectorWebhook"=enabled
```

```
./mesh/create_mesh.sh
```

```
aws --profile frontend cloudformation deploy \
--template-file shared_resources/shared_mesh.yaml \
--parameter-overrides \
"BackendAccountId=$(aws --profile backend sts get-caller-identity | jq -r .Account)" \
--stack-name am-multi-account-shared-mesh \
--capabilities CAPABILITY_IAM
```

## Accept the invitation

```
aws --profile backend ram get-resource-share-invitations 

aws --profile backend ram accept-resource-share-invitation \
--resource-share-invitation-arn <value from previous command>
```

## Deploy the App Mesh Controller on our Backend Cluster

```
kubectl config use-context <iam_user@am-multi-account-2.<region>.eksctl.io
```

```
helm repo add eks https://aws.github.io/eks-charts
```

```
kubectl create ns appmesh-system
helm upgrade -i appmesh-controller eks/appmesh-controller \
--namespace appmesh-system

kubectl -n appmesh-system get pods
```

## Create the App Mesh Service Role on our Backend Account

```
aws --profile backend iam create-service-linked-role --aws-service-name appmesh.amazonaws.com
```

## Deploy Mesh Resources on our Backend Cluster

```
kubectl create ns yelb

kubectl label namespace yelb mesh=am-multi-account-mesh
kubectl label namespace yelb "appmesh.k8s.aws/sidecarInjectorWebhook"=enabled
```

```
./mesh/create_mesh.sh

kubectl apply -f mesh/yelb-redis.yaml
kubectl apply -f mesh/yelb-db.yaml
kubectl apply -f mesh/yelb-appserver.yaml
```

## Deploy Yelb Resources on our Backend Cluster

```
kubectl apply -f yelb/resources_backend.yaml
```

## Deploy Mesh Resources on our Primary Cluster

```
kubectl config use-context <iam_user>@am-multi-account-1.<region>.eksctl.io
```

**Get the ```yelb-appserver``` VirtualService ARN value using below command and update ```mesh/yelb-ui.yaml``` accordingly**. 

```
kubectl --context=<iam_user>@am-multi-account-2.<region>.eksctl.io \
-n yelb get virtualservice yelb-appserver
```

```
kubectl apply -f mesh/yelb-ui.yaml
```

## Deploy Yelb Resources on our Frontend Cluster

```
kubectl apply -f yelb/resources_frontend.yaml
```

## Cleanup

```
./cleanup.sh
```