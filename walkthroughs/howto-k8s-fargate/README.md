## Prerequisites

1. v1beta2 example manifest requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

You can use v1beta1 example manifest with [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [=v0.3.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/legacy-controller/CHANGELOG.md)

2. Install Docker. It is needed to build the demo application images.

## Setup environment
- Setup following environment variables
  - **Your** account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```
  - **Region** e.g. us-east-2
    ```
    export AWS_DEFAULT_REGION=us-east-2
    ```

- Setup EKS cluster with Fargate support.
  - You can use [clusterconfig.yaml](./v1beta2/clusterconfig.yaml) with [eksctl](https://eksctl.io). Update `metadata.region` to AWS_DEFAULT_REGION.
    ```
    eksctl create cluster -f v1beta2/clusterconfig.yaml
    ```

- (Optional) Override the default Helm chart App Mesh Envoy Image version.
  - If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.

## Deploy
1. Clone this repository and navigate to the walkthrough/howto-k8s-fargate folder, all commands will be run from this location
2. Deploy
    ```.
    ./deploy.sh
    ```

## Verify

1. Confirm that envoy containers are receiving configuration
   ```
   $ greenpod=$(kubectl get pod -n howto-k8s-fargate -o name | grep green | cut -f2 -d'/')

   $ kubectl exec -it -n howto-k8s-fargate $greenpod -c envoy curl http://localhost:9901/clusters | grep 'added_via_api::true'

    cds_ingress_howto-k8s-fargate_green-howto-k8s-fargate_http_8080::added_via_api::true
    cds_egress_howto-k8s-fargate_amazonaws::added_via_api::true

   $ kubectl exec -it -n howto-k8s-fargate $greenpod -c envoy curl http://localhost:9901/listeners

    lds_ingress_0.0.0.0_15000::0.0.0.0:15000
    lds_egress_0.0.0.0_15001::0.0.0.0:15001
   ```
2. Port-forward front application deployment
   ```
   $ kubectl -n howto-k8s-fargate port-forward deployment/front 8080:8080
   ```
3. Curl front-app
   ```
   $ while true; do  curl -s http://localhost:8080/color; sleep 0.1; echo ; done

    {"color":"green", "stats": {"blue":0.54,"green":0.46}}
    {"color":"green", "stats": {"blue":0.54,"green":0.46}}
   ```
4. Update the routes to your liking to see the responses changing.
