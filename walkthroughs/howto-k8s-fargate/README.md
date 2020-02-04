## Prerequisites
- Setup following environment variables
  - **Your** account id:
    ```
    export AWS_ACCOUNT_ID=<your_account_id>
    ```
  - **Region** e.g. us-east-2
    ```
    export AWS_DEFAULT_REGION=us-east-2
    ```
  - **ENVOY_IMAGE** set to the location of the App Mesh Envoy container image, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html
    ```
    export ENVOY_IMAGE=...
    ```
- Setup EKS cluster with Fargate support.
  - You can use [clusterconfig.yaml](./clusterconfig.yaml) with [eksctl](https://eksctl.io). Update `metadata.region` to AWS_DEFAULT_REGION. 

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
   $ while true; do  curl -s http://localhost:8080; sleep 0.1; echo ; done

    {"color":"green", "stats": {"blue":0.54,"green":0.46}}
    {"color":"green", "stats": {"blue":0.54,"green":0.46}}
   ```
4. Update the routes to your liking to see the responses changing.