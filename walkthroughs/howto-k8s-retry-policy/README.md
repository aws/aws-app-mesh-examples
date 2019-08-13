## Overview
This example shows how retry-policies can be used to for Kubernetes applications within the context of App Mesh.

### Color
Color app serves color with optionally return error status code if a statuscode-header is set in the request. This will allow us to verify retry behavior when using retry-policies.

### Front
Front app acts as a gateway that makes remote calls to colorapp. Front app has single deployment with pods registered with the mesh as _front_ virtual-node. This virtual-node uses colorapp virtual-service as backend.

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
5. Deploy
    ```.
    ./deploy.sh
    ```