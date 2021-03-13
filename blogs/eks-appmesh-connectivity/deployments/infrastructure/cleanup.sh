#!/bin/bash

kubectl label ns default \
appmesh.k8s.aws/sidecarInjectorWebhook- gateway- mesh- --overwrite

# Delete all objects from default namespace
kubectl delete all --all

# Delete appmesh
kubectl delete mesh yelb-mesh

# Delete IAM Service Account
eksctl delete iamserviceaccount \
  --cluster ${CLUSTER_NAME} \
  --namespace appmesh-system \
  --name appmesh-controller

# uninstall appmesh helm
helm delete appmesh-controller --namespace appmesh-system

# delete appmesh-system namespace
kubectl delete ns appmesh-system

# Delete db cluster
echo "Deleting RDS Cluster"
aws rds delete-db-cluster \
--db-cluster-identifier=yelb-db-cluster \
--skip-final-snapshot &> /dev/null

# Delete ElastiCache cluster
echo "Deleting ElastiCache cluster"
aws elasticache delete-cache-cluster \
--cache-cluster-id=yelb-cache-cluster &> /dev/null
