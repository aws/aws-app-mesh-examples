# Overview
The Color App is simple microservice demo to showcase traffic routing when used with [AWS App Mesh]. This app has two services, `gateway` and `colorteller`.

This page provides a summary description of the Color App. For a step-by-step orientation to running this demo with App Mesh, see this [walkthrough].

### The Gateway service
`gateway` is an HTTP service written in Go intended to provide a simple REST API to external clients of the application. It responds to requests at http://service-name:port/color with a JSON resource that includes the color it retrieves from a `colorteller` service as well as a histogram of all colors observed so far. For example:

```
$ curl -s http://colorgateway.default.svc.cluster.local:9080/color
{"color":"blue", "stats": {"blue":"1"}}

### after many such calls ...
$ curl -s http://colorgateway.default.svc.cluster.local:9080/color
{"color":"blue", "stats": {"black":0.16,"blue":0.82,"red":0.01}}

### the histogram can be reset by invoking /color/clear
$ curl -s http://colorgateway.default.svc.cluster.local:9080/color/clear
```

`gateway` runs as a service optionally exposed via an external application load-balancer (ALB). Each running task is able to communicate with the endpoint of the `colorteller` service via an Envoy proxy (running as a task sidecar) that is configured by App Mesh.

### The Color Teller service
`colorteller` is a simple service written in Go that is configured to return a specific color. Each deployment of a service that configured to return a different color is meant to provide a simple, visual represention of the deployment of different version releases in real world applications (the color configuration is provided as an environment variable so that it isn't necessary to actually recompile any implementation code). As with `gateway` tasks, each `colorteller` task is deployed with an Envoy proxy running as a sidecar.

## Setup

* Setup virtual-nodes, virtual-router and routes for color-app

```
$ ./servicemesh/appmesh-colorapp.sh
```

### ECS

> For detailed, step-by-step instructions, see the [walkthrough].

* Deploy color-teller and color-gateway to ECS

```
$ ./ecs/ecs-colorapp.sh
```

* Verify by doing a curl on color-gateway

```
<ec2-bastion-host>$ curl -s http://colorgateway.${SERVICES_DOMAIN}:9080/color
```

### EKS
* Deploy color-teller and color-gateway to EKS

```
$ ./kubernetes/generate-templates.sh && kubectl apply -f ./kubernetes/colorapp.yaml
```

* Verify by doing a curl on color-gateway

```
$ kubectl run -it curler --image=tutum/curl --env="SERVICES_DOMAIN=${SERVICES_DOMAIN}" bash
root@curler-zzzzzz:/# curl -s --connect-timeout 2 http://colorgateway.${SERVICES_DOMAIN}:9080/color
```

### Development

Source code for the application, as well as scripts to build the application and deploy container images to ECR for your account, are all located under `src`.



[AWS App Mesh]: https://aws.amazon.com/app-mesh/
[walkthrough]: ../../../walkthroughs/ecs/
