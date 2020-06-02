## Overview
This example shows how http routes can use headers for matching incoming requests.

## Prerequisites
[Walkthrough: App Mesh with EKS](../eks/)

Note: v1beta1 example manifest requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v0.3.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/CHANGELOG.md). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'
```
You can use v1beta2 example manifest with [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version >=v1.0.0

```
## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-cloudmap folder, all commands will be ran from this location
2. **Your** account id:

    export AWS_ACCOUNT_ID=<your_account_id>

3. **Region** e.g. us-west-2

    export AWS_DEFAULT_REGION=us-west-2

4. **ENVOY_IMAGE** environment variable is set to App Mesh Envoy, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html

    export ENVOY_IMAGE=...

5. Deploy
    ```.
    ./deploy.sh
```
   
## Using curl to test

Add a curler to the namespace howto-k8s-http-headers on your cluster -
```
kubectl -n howto-k8s-http-headers run -it curler --image=tutum/curl /bin/bash
```

Run the commands on curler to test.

Requesting blue color -
```
curl -H "color_header: blue" front.howto-k8s-http-headers.svc.cluster.local:8080/; echo;
```

Requesting red color -
```
curl -H "color_header: red" front.howto-k8s-http-headers.svc.cluster.local:8080/; echo;
```

Requesting green color (color_header with the text 'green' in it) -
```
curl -H "color_header: requesting.green.color" front.howto-k8s-http-headers.svc.cluster.local:8080/; echo;
```

Getting yellow color (color_header is present with an unrecognized value) -
```
curl -H "color_header: rainbow" front.howto-k8s-http-headers.svc.cluster.local:8080/; echo;
```

Getting white color (no color_header) -
```
curl front.howto-k8s-http-headers.svc.cluster.local:8080/; echo;
```
