## Overview
This example shows how to use [AWS Load Balancer Controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller) with targets registered as virtual-nodes under App Mesh.

![System Diagram](./howto-k8s-alb.png "System Diagram")

## Prerequisites
- [Walkthrough: App Mesh with EKS](../eks/)
- [Walkthrough: AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.3/examples/echo_server/)
- Install Docker. It is needed to build the demo application images.

Note: Only [setup the AWS Load Balancer controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.3/examples/echo_server/#setup-the-aws-load-balancer-controller) and rest this example service will replace the echoserver in the AWS Load Balancer Controller link provider

## Setup

1. Clone this repository and navigate to the walkthrough/howto-k8s-alb folder, all commands will be run from this location
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
    ```.
    ./deploy.sh
    ```

## Usage

Check the events of the ingress to see what has occur.

    
    kubectl describe ing -n howto-k8s-alb color
    

You should see similar to the following.

    
    Name:             color
    Namespace:        howto-k8s-alb
    Address:          k8s-howtok8s-color-63786f35e6-1171992961.us-west-2.elb.amazonaws.com
    Default backend:  default-http-backend:80 (<error: endpoints "default-http-backend" not found>)
    Rules:
    Host        Path  Backends
    ----        ----  --------
    *           
                /color   front:8080 ()
    Annotations:  alb.ingress.kubernetes.io/healthcheck-path: /color
                alb.ingress.kubernetes.io/scheme: internet-facing
                alb.ingress.kubernetes.io/target-type: ip
                kubernetes.io/ingress.class: alb
    Events:
    Type    Reason                  Age   From     Message
    ----    ------                  ----  ----     -------
    Normal  SuccessfullyReconciled  5s    ingress  Successfully reconciled
     

To check if the application is reachable via AWS Load Balancer Controller

```
curl -v k8s-howtok8s-color-63786f35e6-1171992961.us-west-2.elb.amazonaws.com/color
```

You should see similar to the following.

```
*   Trying 54.148.15.33...
* TCP_NODELAY set
* Connected to k8s-howtok8s-color-63786f35e6-1171992961.us-west-2.elb.amazonaws.com (54.148.15.33) port 80 (#0)
> GET /color HTTP/1.1
> Host: k8s-howtok8s-color-63786f35e6-1171992961.us-west-2.elb.amazonaws.com
> User-Agent: curl/7.64.1
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Wed, 26 Jan 2022 20:31:19 GMT
< Transfer-Encoding: chunked
< Connection: keep-alive
< server: envoy
< x-envoy-upstream-service-time: 11
< 
* Connection #0 to host k8s-howtok8s-color-63786f35e6-1171992961.us-west-2.elb.amazonaws.com left intact
green
```

&nbsp;

## Clean up once done

    kubectl delete ns howto-k8s-alb && kubectl delete mesh howto-k8s-alb