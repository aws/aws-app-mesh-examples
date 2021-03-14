## Overview
In this walkthrough we'll enable TLS encryption between two applications in App Mesh using X.509 certificates.

In App Mesh, traffic encryption works between Virtual Nodes, and thus between Envoys in your service mesh. This means your application code is not responsible for negotiating a TLS-encrypted session, instead allowing the local proxy to negotiate and terminate TLS on your application's behalf. We will be configuring Envoy to use the file based strategy (via Kubernetes Secrets) to setup certificates.

## Prerequisites
1. [Walkthrough: App Mesh with EKS](../eks/)

2. The manifest in this walkthrough requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

3. Install Docker. It is needed to build the demo application images.

## Step 1: Setup environment
1. Clone this repository and navigate to the walkthrough/howto-k8s-tls-file-based folder, all commands will be ran from this location
2. Your AWS account id:

    export AWS_ACCOUNT_ID=<your_account_id>

3. Region e.g. us-west-2

    export AWS_DEFAULT_REGION=us-west-2

4. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.

## Step 2: Generate the certificates and Kubernetes Secrets

Before we can encrypt traffic between services in the mesh, we need to generate our certificates.

For this walkthrough, we are going to set up two separate Certificate Authorities. The first one will be used to sign the certificate for the Blue Color app, the second will be used to sign the certificate for the Green Color app.

```bash
./tls/certs.sh
```

This generates a few different files

- *_cert.pem: These files are the public side of the certificates
- *_key.pem: These files are the private key for the certificates
- *_cert_chain: These files are an ordered list of the public certificates used to sign a private key
- ca_1_ca_2_bundle.pem: This file contains the public certificates for both CAs.

You can verify that the Blue Color app certificate was signed by CA 1 using this command.

```bash
openssl verify -verbose -CAfile tls/ca_1_cert.pem  tls/colorapp-blue_cert.pem
```

We are going to store these certificates as [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/). This will allow us to mount them in the Envoy containers

```bash
./tls/deploy.sh
```

You can verify the Kubernetes Secrets created using this command.

```bash
kubectl get secrets -n howto-k8s-tls-file-based
```

It should return an output like following:
```
NAME                  TYPE                                  DATA   AGE
ca1-ca2-bundle-tls    Opaque                                1      10m
ca1-cert-tls          Opaque                                1      10m
colorapp-blue-tls     Opaque                                2      10m
colorapp-green-tls    Opaque                                2      10m
default-token-xh8zw   kubernetes.io/service-account-token   3      10m
```

## Step 3: Create a Mesh with TLS enabled

We are going to setup a mesh with four virtual nodes: Frontend, Blue, Green and Red, one virtual service: color and one virtual router: color.

Let's create the mesh.

```bash
./mesh.sh up
```

Frontend has backend virtual service (color) configured and the virtual service (color) uses virtual router (color) as the provider. The virtual router (color) has three routes configured:
- color-route-blue: matches on HTTP header "blue" to route traffic to virtual node `blue`
- color-route-green: matches on HTTP header "green" to route traffic to virtual node `green` 
- color-route-red: matches on HTTP header "red" to route traffic to virtual node `red`

Virtual nodes `blue` and `green` are configured with TLS enabled for their respective listeners. Here's the spec for `green` Virtual Node:

```
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: green
  namespace: howto-k8s-tls-file-based
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
  serviceDiscovery:
    dns:
      hostname: color-green.howto-k8s-tls-file-based.svc.cluster.local
```

The `tls` block specifies a filepath to where the Envoy can find the certificates it expects. In order to encrypt the traffic, Envoy needs to have both the certificate chain and the private key.

Virtual Node `blue` certificate was signed by CA 1 and Virtual node `green` certificate was signed by CA 2.

Virtual Node `front` has client side TLS validation enabled. We will change the certificate chain in the Virtual Node `front` to be signed from CA 1 only and then to both CA 1 and CA2 so verify `front` can initially only communicate with Virtual Node `blue` (signed by CA 1) and later communicate with both `blue` (signed by CA 1) and `green` (signed by CA 2), when uses the certificate chain bundle from CA 1 and CA 2.

Kubernetes Secrets are mounted on the Envoy sidecare by the injector in App Mesh Controller for Kubernetes. This is achieved using annotations on your application Pods. Here's a sample YAML for Green Color app deployment.


```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: green
  namespace: howto-k8s-tls-file-based
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
      labels:
        app: color
        version: green
    spec:
      containers:
        - name: app
          image: 669977933099.dkr.ecr.us-west-2.amazonaws.com/howto-k8s-tls-file-based/colorapp
          ports:
            - containerPort: 8080
          env:
            - name: "COLOR"
              value: "green"
```

To mount secret in Envoy sidecar, add the annotation `appmesh.k8s.aws/secretMounts` with "source-secret:destination_path_to_mount_the_secret". 

For example, the annotation `appmesh.k8s.aws/secretMounts: "colorapp-green-tls:/certs/"` will mount contents of secret `colorapp-green-tls` at `/certs/` in the Envoy container. You can verify this by running the following command.

```bash
GREEN_POD=$(kubectl get pod -l "version=green" -n howto-k8s-tls-file-based --output=jsonpath={.items..metadata.name})
kubectl exec -it $GREEN_POD -n howto-k8s-tls-file-based -c envoy -- ls /certs/
```

It should output the contents of the Kubernetes Secret `colorapp-green-tls` 

```
colorapp-green_cert_chain.pem  colorapp-green_key.pem
```

## Setup 4: Verify TLS is enabled

```bash
kubectl -n default run -it --rm curler --image=tutum/curl /bin/bash
```

```
curl -H "color_header: blue" front.howto-k8s-tls-file-based.svc.cluster.local:8080/; echo;
```

You should see a successful response when using the HTTP header "color_header: blue"

Let's check the SSL handshake statistics.

```bash
BLUE_POD=$(kubectl get pod -l "version=blue" -n howto-k8s-tls-file-based --output=jsonpath={.items..metadata.name})
kubectl exec -it $BLUE_POD -n howto-k8s-tls-file-based -c envoy -- curl -s http://localhost:9901/stats | grep ssl.handshake
```

You should see output similar to: listener.0.0.0.0_15000.ssl.handshake: 1, indicating a successful SSL handshake was achieved between front and blue color app

## Setup 4: Verify client policy

```
curl -H "color_header: green" front.howto-k8s-tls-file-based.svc.cluster.local:8080/; echo;
```

You should see connection getting refused when you attempt to communicate with `green`. This is because the Green Color app certificates were signed by a different CA than Frontend app. And we have added a backend default for the Client Policy that instructs Frontend app Envoy to only allow certificates signed by CA 1 to be accepted.

Now let's change the Frontend client policy to allow certificates from both CA 1 and CA 2.

```bash
SKIP_IMAGES=1 ./mesh.sh addGreen
```

```
curl -H "color_header: green" front.howto-k8s-tls-file-based.svc.cluster.local:8080/; echo;
```

You should see a successful response when using the HTTP header "color_header: green"

## Step 4: Cleanup

If you want to keep the application running, you can do so, but this is the end of this walkthrough. Run the following commands to clean up and tear down the resources that we’ve created.

```bash
./tls/cleanup.sh
kubectl delete -f _output/manifest.yaml
```
