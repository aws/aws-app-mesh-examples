# Securing Kubernetes applications with AWS App Mesh and cert-manager

Full configuration files for blog post [Securing Kubernetes applications with AWS App Mesh and cert-manager]()

## 0. Deploy base yelb with App Mesh

`kubectl apply -f yelb-base.yaml`

## 1. Install cert-manager

```
kubectl create ns cert-manager

helm repo add jetstack https://charts.jetstack.io
helm repo update
 
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v0.16.1 \
  --set installCRDs=true
```

## 2. Create CA and issue certificates for microservices

```
#generate a private key
openssl genrsa -out ca.key 2048
 
#create a self signed x.509 CA certificate
openssl req -x509 -new -key ca.key -subj "/CN=App Mesh Examples CA" -days 3650 -out ca.crt

#create TLS secret
kubectl create secret tls ca-key-pair \
   --cert=ca.crt \
   --key=ca.key \
   --namespace=yelb

#create CA issuer
kubectl apply -f ca-issuer.yaml

#create certificate
kubectl apply -f yelb-cert.yaml
```

## 3. Mount certificate to microservice deployment 

`kubectl apply -f yelb-deployment-secretMounts.yaml`

## 4. Add TLS configuration to virtual node

`kubectl apply -f yelb-virtualnode-tls.yaml`

## 5. Configure encryption between external LB and App Mesh

Please set `ENVOY_IMAGE` ENV variable to the correct value based on https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html

Additionally set `LB_CERT_ARN` ENV variable with your own valid arn.

```
ENVOY_IMAGE="840364872350.dkr.ecr.<region>.amazonaws.com/aws-appmesh-envoy:<version>"

LB_CERT_ARN="arn:aws:acm:<region>:<account-id>:certificate/<cert-id>"

sed -e "s|{{ENVOY_IMAGE}}|${ENVOY_IMAGE}|g" -e "s|{{LB_CERT_ARN}}|${LB_CERT_ARN}|g" yelb-gw.yaml | kubectl apply -f -
```
