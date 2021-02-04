## Overview
In this walkthrough we'll enable mTLS encryption between two applications in App Mesh using X.509 certificates.

In App Mesh, traffic encryption works between Virtual Nodes, and thus between Envoys in your service mesh. This means your application code is not responsible for negotiating a TLS-encrypted session, instead allowing the local proxy to negotiate and terminate TLS on your application's behalf. We will be configuring Envoy to use the file based strategy (via Kubernetes Secrets) to setup certificates.

## Prerequisites

1. [Walkthrough: App Mesh with EKS](../eks/)
2. Run the following to check the version of controller you are running. v1.3.0 is the minimum controller version required for mTLS feature.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1

v1.3.0
```
3. Install Docker. It is needed to build the demo application images.

## Step 1: Setup environment
1. Clone this repository and navigate to the walkthrough/howto-k8s-mtls-file-based folder, all commands will be ran from this location
2. Your AWS account id:

    export AWS_ACCOUNT_ID=<your_account_id>

3. Region e.g. us-west-2

    export AWS_DEFAULT_REGION=us-west-2

4. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.

## Step 2: Generate the certificates and Kubernetes Secrets

Before we can encrypt traffic between services in the mesh, we need to generate our certificates.

For this walkthrough, we are going to set up two separate Certificate Authorities. The first one will be used to sign the certificate for the Blue Color app, the second will be used to sign the certificate for the Green Color app.

```bash
./mtls/certs.sh
```

This generates a few different files

- *_cert.pem: These files are the public side of the certificates
- *_key.pem: These files are the private key for the certificates
- *_cert_chain: These files are an ordered list of the public certificates used to sign a private key
- ca_1_ca_2_bundle.pem: This file contains the public certificates for both CAs.

You can verify that the Blue Color app certificate was signed by CA 1 using this command.

```bash
openssl verify -verbose -CAfile mtls/ca_1_cert.pem  mtls/colorapp-blue_cert.pem
```

We are going to store these certificates as [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/). This will allow us to mount them in the Envoy containers

```bash
./mtls/deploy.sh
```

You can verify the Kubernetes Secrets created using this command.

```bash
kubectl get secrets -n howto-k8s-mtls-file-based

NAME                  TYPE                                  DATA   AGE
colorapp-blue-tls     Opaque                                3      4s
colorapp-green-tls    Opaque                                3      3s
default-token-jtd47   kubernetes.io/service-account-token   3      5s
front-ca1-ca2-tls     Opaque                                3      4s
front-ca1-tls         Opaque                                3      4s
```

## Step 3: Create a Mesh with mTLS enabled

We are going to setup a mesh with four virtual nodes: Frontend, Blue, Green and Red, one virtual service: color and one virtual router: color.

Let's create the mesh.

```bash
./mesh.sh up
```

Frontend has backend virtual service (color) configured and the virtual service (color) uses virtual router (color) as the provider. The virtual router (color) has three routes configured:
- color-route-blue: matches on HTTP header "blue" to route traffic to virtual node `blue`
- color-route-green: matches on HTTP header "green" to route traffic to virtual node `green` 
- color-route-red: matches on HTTP header "red" to route traffic to virtual node `red`

Virtual nodes `blue` and `green` are configured with mTLS enabled. Here's the spec for `green` Virtual Node:

```
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: green
  namespace: ${APP_NAMESPACE}
spec:
  podSelector:
    matchLabels:
      app: color
      version: green
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      healthCheck:
        protocol: http
        path: '/ping'
        healthyThreshold: 2
        unhealthyThreshold: 2
        timeoutMillis: 2000
        intervalMillis: 5000
      tls:
        mode: STRICT
        certificate:
          file:
            certificateChain: /certs/colorapp-green_cert_chain.pem
            privateKey: /certs/colorapp-green_key.pem
        validation:
          trust:
            file:
              certificateChain: /certs/ca_1_cert.pem
          subjectAlternativeNames:
            match:
              exact:
              - front.howto-k8s-mtls-file-based.svc.cluster.local
  serviceDiscovery:
    dns:
      hostname: color-green.howto-k8s-mtls-file-based.svc.cluster.local
```

The `certificate` section of `tls` block specifies a filepath to where the Envoy can find the certificates it expects. In order to encrypt the traffic, Envoy needs to have both the certificate chain and the private key. `validation` section of the `tls` block specifies the path to CA Cert.

Virtual Nodes `front` and `blue` certificates were signed by CA 1 and Virtual node `green` certificate was signed by CA 2.

Virtual Node `front` has mTLS enabled. We will change the certificate chain in the Virtual Node `front` to be signed from CA 1 only and then to both CA 1 and CA2. So, `front` can initially only communicate with Virtual Node `blue` (signed by CA 1) and later communicate with both `blue` (signed by CA 1) and `green` (signed by CA 2), when we update it to use the certificate chain bundle from CA 1 and CA 2.

Kubernetes Secrets are mounted on the Envoy sidecars by the injector in App Mesh Controller for Kubernetes. This is achieved using annotations on your application Pods. Here's a sample YAML for Green Color app deployment.


```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: green
  namespace: ${APP_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: color
      version: green
  template:
    metadata:
      annotations:
        appmesh.k8s.aws/secretMounts: "colorapp-green-tls:/certs/"
        appmesh.k8s.aws/sds: "disabled"
      labels:
        app: color
        version: green
    spec:
      containers:
        - name: app
          image: ${COLOR_APP_IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: "COLOR"
              value: "green"
```

To mount secret in Envoy sidecar, add the annotation `appmesh.k8s.aws/secretMounts` with "source-secret:destination_path_to_mount_the_secret". 

Controller can currently support both SDS and File based certs on the same VirtualNode. If you're only using File based certs and have enabled SDS in the controller by setting `enabled-sds` to `true`, then we can disable the sds using the annotation `appmesh.k8s.aws/sds: "disabled"`.

Now that we have the Mesh deployed. Let's derive the pod identities which we will use through the rest of the walk through.

```bash
FRONT_POD=$(kubectl get pod -l "app=front" -n howto-k8s-mtls-file-based --output=jsonpath={.items..metadata.name})
BLUE_POD=$(kubectl get pod -l "version=blue" -n howto-k8s-mtls-file-based --output=jsonpath={.items..metadata.name})
RED_POD=$(kubectl get pod -l "version=red" -n howto-k8s-mtls-file-based --output=jsonpath={.items..metadata.name})
GREEN_POD=$(kubectl get pod -l "version=green" -n howto-k8s-mtls-file-based --output=jsonpath={.items..metadata.name})
```

You can verify if the `certs` are mounted at the path specified via the annotation `appmesh.k8s.aws/secretMounts` in the deployment spec.

For example, the annotation `appmesh.k8s.aws/secretMounts: "colorapp-green-tls:/certs/"` in the deployment spec of `green` will mount contents of K8S secret `colorapp-green-tls` at `/certs/` in the Envoy container. You can verify this by running the following command.

```bash
kubectl exec -it $GREEN_POD -n howto-k8s-mtls-file-based -c envoy -- ls /certs/
```

It should output the contents of the Kubernetes Secret `colorapp-green-tls` 

```
ca_1_cert.pem  colorapp-green_cert_chain.pem  colorapp-green_key.pem
```

Now, we have configured VirtualNode `front` configured with CA1 in it's validation context. `blue` is signed by CA1 whereas `green` is signed by CA2. Let's check the health status of the backend clusters. VirtualNode `red` isn't configured for TLS.

```bash
kubectl exec -it $FRONT_POD -n howto-k8s-mtls-file-based -c envoy -- curl http://localhost:9901/clusters | grep -E '((blue|green|red).*health)'

cds_egress_howto-k8s-mtls-file-based_red_howto-k8s-mtls-file-based_http_8080::10.100.177.181:8080::health_flags::/failed_active_hc
cds_egress_howto-k8s-mtls-file-based_green_howto-k8s-mtls-file-based_http_8080::10.100.75.104:8080::health_flags::/failed_active_hc
cds_egress_howto-k8s-mtls-file-based_blue_howto-k8s-mtls-file-based_http_8080::10.100.252.203:8080::health_flags::healthy
```
As we can see above, only `blue` passed the health check. Health check failed for `green` because `front` only validates the certs signed by CA1.

## Setup 4: Verify TLS is enabled

```bash
kubectl -n default run -it --rm curler --image=tutum/curl /bin/bash
```

```
curl -H "color_header: blue" front.howto-k8s-mtls-file-based.svc.cluster.local:8080/; echo;
```

You should see a successful response when using the HTTP header "color_header: blue"

Let's check the SSL handshake statistics.

```bash
kubectl exec -it $BLUE_POD -n howto-k8s-mtls-file-based -c envoy -- curl -s http://localhost:9901/stats | grep ssl.handshake
```

You should see output similar to: listener.0.0.0.0_15000.ssl.handshake: 2, indicating a successful SSL handshake was achieved between front and blue color app

## Setup 4: Verify client policy

```
curl -H "color_header: green" front.howto-k8s-mtls-file-based.svc.cluster.local:8080/; echo;
```

You should see connection getting refused when you attempt to communicate with `green`. This is because the Green Color app certificates were signed by a different CA than Frontend app. And we have added a backend default for the Client Policy that instructs Frontend app Envoy to only allow certificates signed by CA 1 to be accepted.

Let's check for SSL errors in  `front`.

```bash
kubectl exec -it $FRONT_POD -n howto-k8s-mtls-file-based -c envoy  -- curl -s http://localhost:9901/stats | grep ssl | grep green | grep fail_verify_error`

cluster.cds_egress_howto-k8s-mtls-file-based_green_howto-k8s-mtls-file-based_http_8080.ssl.fail_verify_error: 9
```

As we can see above, CA verification failed as expected in `front` while trying to start a session with `green`. 

Now let's change the Frontend client policy to allow certificates from both CA 1 and CA 2.

```bash
SKIP_IMAGES=1 ./mesh.sh addGreen
```

```
curl -H "color_header: green" front.howto-k8s-mtls-file-based.svc.cluster.local:8080/; echo;
```

You should see a successful response when using the HTTP header "color_header: green"

Let's check ssl stats in `green` app.

```bash
kubectl exec -it $GREEN_POD -n howto-k8s-mtls-file-based -c envoy -- curl -s http://localhost:9901/stats | grep ssl.handshake
```

You should see output similar to: listener.0.0.0.0_15000.ssl.handshake: 2, indicating a successful SSL handshake was achieved between front and green color app

## Step 4: Cleanup

If you want to keep the application running, you can do so, but this is the end of this walkthrough. Run the following commands to clean up and tear down the resources that we’ve created.

```bash
./mtls/cleanup.sh
kubectl delete -f _output/manifest.yaml
```
