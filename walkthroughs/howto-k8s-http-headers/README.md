## Overview
This example shows how http routes can use headers for matching incoming requests.

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
   
## Using curl to test

Requesting blue color -
```
curl -H "color_header: blue" front.howto-k8s-http-headers.svc.cluster.local:8080/; echo;
```

Requesting red color -
```
curl -H "color_header: red" front.howto-k8s-http-headers.svc.cluster.local:8080/; echo;
```

Requesting green color -
```
curl -H "color_header: requesting.green.color" front.howto-k8s-http-headers.svc.cluster.local:8080/; echo;
```

Getting yellow color -
```
curl -H "color_header: rainbow" front.howto-k8s-http-headers.svc.cluster.local:8080/; echo;
```

Getting white color -
```
curl front.howto-k8s-http-headers.svc.cluster.local:8080/; echo;
```