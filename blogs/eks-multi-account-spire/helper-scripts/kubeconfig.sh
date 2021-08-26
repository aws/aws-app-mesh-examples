#!/bin/bash

set -e

kubectl config use-context $SHARED_CXT

echo "Creating the spire namespace..."
kubectl create ns spire

echo "Creating a separate kubeconfig file (front_config) for frontend cluster eks get-token authentication..."
aws --profile frontend eks update-kubeconfig \
  --kubeconfig front_config \
  --name eks-cluster-frontend \
  --role-arn $(aws --profile frontend iam get-role \
  --role-name eks-cluster-frontend-access-role | jq -r '.Role.Arn')

# remove AWS_PROFILE from the frontend kubeconfig file
sed "$(( $(wc -l <front_config)-3+1 )),$ d" front_config \
  > /tmp/front_config && mv /tmp/front_config front_config

echo "Packaging the frontend kubeconfig file into a ConfigMap..."
cat << EOF > front_kubeconfig.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: front-kubeconfig
  namespace: spire
data:
  frontend.conf: |
$(awk '{printf "    %s\n", $0}' < front_config)
EOF

echo "Creating the front-kubeconfig ConfigMap to be mounted as a volume to the SPIRE server..."
kubectl apply -f front_kubeconfig.yaml

echo "Creating a separate kubeconfig file (back_config) for backend cluster eks get-token authentication..."
aws --profile backend eks update-kubeconfig \
  --kubeconfig back_config \
  --name eks-cluster-backend \
  --role-arn $(aws --profile backend iam get-role \
  --role-name eks-cluster-backend-access-role | jq -r '.Role.Arn')
 
# remove AWS_PROFILE from the backend kubeconfig file
sed "$(( $(wc -l <back_config)-3+1 )),$ d" back_config \
  > /tmp/back_config && mv /tmp/back_config back_config

echo "Packaging the backend kubeconfig file into a ConfigMap..."
cat << EOF > back_kubeconfig.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: back-kubeconfig
  namespace: spire
data:
  backend.conf: |
$(awk '{printf "    %s\n", $0}' < back_config)
EOF

echo "Creating the back-kubeconfig ConfigMap to be mounted as a volume to the SPIRE server..."
kubectl apply -f back_kubeconfig.yaml