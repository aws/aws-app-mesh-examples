#!/bin/bash

MESH_OWNER=$(aws --profile frontend sts get-caller-identity | jq -r .Account)

cat > /tmp/app-mesh.yml <<-EKS_CONF
  apiVersion: appmesh.k8s.aws/v1beta2
  kind: Mesh
  metadata:
    name: am-multi-account-mesh
  spec:
    meshOwner: "$MESH_OWNER"
    namespaceSelector:
      matchLabels:
        mesh: am-multi-account-mesh
EKS_CONF

kubectl apply -f /tmp/app-mesh.yml
