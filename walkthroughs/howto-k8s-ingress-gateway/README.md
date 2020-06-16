# Configuring Ingress Gateway

In this walkthrough, we'll configure an Ingress Gateway in our existing example color app but with a VirtualGateway resource instead of VirtualNode for ingress traffic.

A virtual gateway allows resources outside your mesh to communicate to resources that are inside your mesh. The virtual gateway represents an Envoy proxy running in an Amazon ECS, in a Kubernetes service, or on an Amazon EC2 instance. Unlike a virtual node, which represents a proxy running with an application, a virtual gateway represents the proxy deployed by itself.

## Prerequisites
This feature is currently only available in App Mesh preview and will work with App Mesh controller [here](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller)

This example requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/CHANGELOG.md). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-ingress-gateway folder, all commands will be ran from this location
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

## Use Ingress gateway

There are two GatewayRoutes setup in this example: 1) `gateway-route-headers` 2) `gateway-route-paths`.
`gateway-route-headers` will route traffic to VirtualService `color-headers` and `gateway-route-paths` will route traffic to VirtualService `color-paths`

VirtualService `color-headers` uses a VirtualRouter to match HTTP headers to choose the backend VirtualNode. VirtualService `color-paths` uses HTTP path prefixes to choose backend VirtualNode

Let's look at the VirtualGateway deployed:

```
kubectl get virtualgateway -n howto-k8s-ingress-gateway                                         
NAME         ARN                                                                                                                                 AGE
ingress-gw   arn:aws:appmesh-preview:us-west-2:112233333455:mesh/howto-k8s-ingress-gateway/virtualGateway/ingress-gw_howto-k8s-ingress-gateway   113s
```

The entry point for traffic will be an Envoy linked to the VirtualGateway `ingress-gw`:

```
kubectl get pod -n howto-k8s-ingress-gateway                                                    
NAME                        READY   STATUS    RESTARTS   AGE
blue-574fc6f766-jtc76       2/2     Running   0          13s
green-5fdb4488cb-mtrsl      2/2     Running   0          13s
ingress-gw-c9c9b895-rqv9r   1/1     Running   0          13s
red-54b44b859b-jqmxx        2/2     Running   0          13s
white-85685c459b-rgj4f      2/2     Running   0          13s
yellow-67b88f8cf4-mtnhq     2/2     Running   0          13s
```

`ingress-gw-c9c9b895-rqv9r` is pointing to VirtualGateway and is accessible via LoadBalancer type k8s Service:

```
kubectl get svc -n howto-k8s-ingress-gateway                                                    
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP                                                              PORT(S)          AGE
color-blue      ClusterIP      10.100.10.91     <none>                                                                   8080/TCP         3m21s
color-green     ClusterIP      10.100.81.185    <none>                                                                   8080/TCP         3m22s
color-headers   ClusterIP      10.100.90.162    <none>                                                                   8080/TCP         3m21s
color-paths     ClusterIP      10.100.49.62     <none>                                                                   8080/TCP         3m21s
color-red       ClusterIP      10.100.247.202   <none>                                                                   8080/TCP         3m21s
color-white     ClusterIP      10.100.5.232     <none>                                                                   8080/TCP         3m21s
color-yellow    ClusterIP      10.100.151.20    <none>                                                                   8080/TCP         3m21s
ingress-gw      LoadBalancer   10.100.177.113   a0b14c18c13114255ab46432fcb9e1f8-135255798.us-west-2.elb.amazonaws.com   80:30151/TCP   3m21s
```

Let's verify connectivity into the Mesh:

```
GW_ENDPOINT=$(kubectl get svc ingress-gw -n howto-k8s-ingress-gateway --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

Connect to VirtualNode red via VirtualService color-paths
```
curl ${GW_ENDPOINT}/paths/red ; echo;
red
```

Connect to VirtualNode blue via VirtualService color-paths
```
curl ${GW_ENDPOINT}/paths/blue ; echo;
blue
```

Connect to VirtualNode yellow via VirtualService color-paths
```
curl ${GW_ENDPOINT}/paths/yellow ; echo;
yellow
```

Connect to VirtualNode blue via VirtualService color-headers
```
curl -H "color_header: blue" ${GW_ENDPOINT}/headers ; echo;
blue
```

Connect to VirtualNode red via VirtualService color-headers
```
curl -H "color_header: red" ${GW_ENDPOINT}/headers ; echo;
red
```

## Cleanup

```
kubectl delete -f _output/manifest.yaml
```
