## Overview
This example shows how to use [ALB Ingress Controller](https://github.com/kubernetes-sigs/aws-alb-ingress-controller) with targets registered as virtual-nodes under App Mesh.

## Prerequisites
- [Walkthrough: App Mesh with EKS](../eks/)
- [Walkthrough: ALB Ingress Controller](https://kubernetes-sigs.github.io/aws-alb-ingress-controller/guide/walkthrough/echoserver/)

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