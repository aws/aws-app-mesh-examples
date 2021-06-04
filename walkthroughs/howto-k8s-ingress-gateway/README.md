# Configuring Ingress Gateway

In this walkthrough, we'll configure an Ingress Gateway in our existing example color app but with a VirtualGateway resource instead of VirtualNode for ingress traffic.

A virtual gateway allows resources outside your mesh to communicate to resources that are inside your mesh. The virtual gateway represents an Envoy proxy running in an Amazon ECS, in a Kubernetes service, or on an Amazon EC2 instance. Unlike a virtual node, which represents a proxy running with an application, a virtual gateway represents the proxy deployed by itself.

## Prerequisites

1. This example requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.1.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.1.0). Run the following to check the version of controller you are running.
```
kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1

v1.1.0
```

2. Install Docker. It is needed to build the demo application images.

## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-ingress-gateway folder, all commands will be ran from this location
2. **Your** account id:

```
    export AWS_ACCOUNT_ID=<your_account_id>
```

3. **Region** e.g. us-west-2

```
    export AWS_DEFAULT_REGION=us-west-2
```

4. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.

5. Deploy
```
    ./deploy.sh
```

## Use Ingress gateway

There are two GatewayRoutes setup in this example: 1) `gateway-route-headers` 2) `gateway-route-paths`.
`gateway-route-headers` will route traffic to VirtualService `color-headers` and `gateway-route-paths` will route traffic to VirtualService `color-paths`

VirtualService `color-headers` uses a VirtualRouter to match HTTP headers to choose the backend VirtualNode. VirtualService `color-paths` uses HTTP path prefixes to choose backend VirtualNode

Let's look at the VirtualGateway deployed in Kubernetes and AWS App Mesh:

```
kubectl get virtualgateway -n howto-k8s-ingress-gateway                                         
NAME         ARN                                                                                                                                 AGE
ingress-gw   arn:aws:appmesh:us-west-2:112233333455:mesh/howto-k8s-ingress-gateway/virtualGateway/ingress-gw_howto-k8s-ingress-gateway   113s
```

```
aws appmesh list-virtual-gateways --mesh-name howto-k8s-ingress-gateway

# {
#    "virtualGateways": [
#        {
#            "arn": "arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-ingress-gateway/virtualGateway/ingress-gw_howto-k8s-ingress-gateway",
#            "createdAt": 1592601321.986,
#            "lastUpdatedAt": 1592601321.986,
#            "meshName": "howto-k8s-ingress-gateway",
#            "meshOwner": "1234567890",
#            "resourceOwner": "1234567890",
#            "version": 1,
#            "virtualGatewayName": "ingress-gw_howto-k8s-ingress-gateway"
#        }
#    ]
# }

aws appmesh list-gateway-routes --virtual-gateway-name ingress-gw_howto-k8s-ingress-gateway --mesh-name howto-k8s-ingress-gateway

# {
#    "gatewayRoutes": [
#        {
#            "arn": "arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-ingress-gateway/virtualGateway/ingress-gw_howto-k8s-ingress-gateway/gatewayRoute/gateway-route-paths_howto-k8s-ingress-gateway",
#            "createdAt": 1592601647.409,
#            "gatewayRouteName": "gateway-route-paths_howto-k8s-ingress-gateway",
#            "lastUpdatedAt": 1592601647.409,
#            "meshName": "howto-k8s-ingress-gateway",
#            "meshOwner": "1234567890",
#            "resourceOwner": "1234567890",
#            "version": 1,
#            "virtualGatewayName": "ingress-gw_howto-k8s-ingress-gateway"
#        },
#        {
#            "arn": "arn:aws:appmesh:us-west-2:1234567890:mesh/howto-k8s-ingress-gateway/virtualGateway/ingress-gw_howto-k8s-ingress-gateway/gatewayRoute/gateway-route-headers_howto-k8s-ingress-gateway",
#            "createdAt": 1592601647.395,
#            "gatewayRouteName": "gateway-route-headers_howto-k8s-ingress-gateway",
#            "lastUpdatedAt": 1592601647.395,
#            "meshName": "howto-k8s-ingress-gateway",
#            "meshOwner": "1234567890",
#            "resourceOwner": "1234567890",
#            "version": 1,
#            "virtualGatewayName": "ingress-gw_howto-k8s-ingress-gateway"
#        }
#    ]
# }

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
