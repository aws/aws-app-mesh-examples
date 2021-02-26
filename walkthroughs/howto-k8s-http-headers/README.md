## Overview
This example shows how http routes can use headers for matching incoming requests.

## Prerequisites
1. [Walkthrough: App Mesh with EKS](../eks/)

2. v1beta2 example manifest requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

You can use v1beta1 example manifest with [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [=v0.3.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/legacy-controller/CHANGELOG.md)

3. Install Docker. It is needed to build the demo application images.

```
## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-http-headers folder, all commands will be ran from this location
2. **Your** account id:

    export AWS_ACCOUNT_ID=<your_account_id>

3. **Region** e.g. us-west-2

    export AWS_DEFAULT_REGION=us-west-2

4. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.

5. Deploy
    ```.
    ./deploy.sh
```

## Using curl to test

Add a curler on your cluster -
```
kubectl run -it curler --image=tutum/curl /bin/bash
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
