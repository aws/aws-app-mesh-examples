#!/bin/bash

set -e

for PROFILE in frontend backend shared
  do 
    if [ "$PROFILE" == "shared" ]; then 
      kubectl config use-context $SHARED_CXT
    elif [ "$PROFILE" == "frontend" ]; then 
      kubectl config use-context $FRONT_CXT
    else 
      kubectl config use-context $BACK_CXT
    fi

    echo "Deleting the yelb namespace..."
    kubectl delete ns yelb

    echo "Deleting the spire namespace..."
    kubectl delete ns spire

    if [ "$PROFILE" == "backend" ]; then 
      echo "Deleting the Cloud Map namespace am-multi-account.local..."
      aws --profile backend servicediscovery get-operation \
        --operation-id $(aws --profile backend servicediscovery delete-namespace \
        --id $(aws --profile backend servicediscovery list-namespaces \
        | jq -r '.Namespaces[] | select(.Name=="am-multi-account.local").Id') \
        | jq -r '.OperationId') > /dev/null
    fi

    echo "Deleting the App Mesh am-multi-account-mesh..."
    kubectl delete mesh am-multi-account-mesh

    if [ "$PROFILE" == "shared" ]; then 
      echo "Deleting the mesh-share RAM resource share..."
      aws --profile shared ram delete-resource-share \
        --resource-share-arn $(aws --profile shared ram get-resource-shares \
        --resource-owner SELF | jq -r '.resourceShares[] | select((.name=="mesh-share") and (.status=="ACTIVE")).resourceShareArn') > /dev/null
    fi 

    echo "Deleting the appmesh-controller..."
    helm -n appmesh-system delete appmesh-controller

    echo "Deleting the App Mesh custom resource definitions..."
    for i in $(kubectl get crd | grep appmesh | cut -d" " -f1)
      do
        kubectl delete crd $i
      done
    
    echo "Deleting the appmesh-controller IAM service account..."
    eksctl --profile $PROFILE delete iamserviceaccount \
      --cluster eks-cluster-$PROFILE \
      --namespace appmesh-system \
      --name appmesh-controller

    echo "Deleting the appmesh-system namespace..."
    kubectl delete namespace appmesh-system
  done