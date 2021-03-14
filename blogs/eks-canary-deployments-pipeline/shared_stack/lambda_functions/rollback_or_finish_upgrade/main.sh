function handler () {
    # Get variables
    cluster_name=$(echo $1 | jq -r '.cluster_name')
    kubernetes_namespace=$(echo $1 | jq -r '.kubernetes_namespace')
    new_version=$(echo $1 | jq -r '.deployment.new_version | tonumber')
    microservice_name=$(echo $1 | jq -r '.microservice_name')
    old_version=$(($new_version - 1))

    # Create kubeconfig file
    aws eks update-kubeconfig --name $cluster_name --kubeconfig /tmp/kubeconfig

    # Check if should rollback or finish upgrade
    is_healthy=$(echo $1 | jq '.deployment.is_healthy')
    if [ $is_healthy = false ]; then
        to_delete=$new_version
        to_keep=$old_version
    else
        to_delete=$old_version
        to_keep=$new_version
    fi

    # Get all listener protocols
    protocols=$(kubectl get VirtualRouter $microservice_name -n $kubernetes_namespace -o json \
        | jq -r '.spec.listeners[].portMapping.protocol')

    # For all protocols found
    for p in $protocols;
    do
       # Ensure that all trafic is going to the new VirtualNode
        kubectl get VirtualRouter $microservice_name -n $kubernetes_namespace -o json \
            | jq '.spec.routes[].'$p'Route.action.weightedTargets = [{"virtualNodeRef":{"name":"'$microservice_name'-'$to_keep'"},"weight":100}]' \
            | jq 'del(.metadata.resourceVersion)' | jq 'del(.spec.meshRef)' \
            | kubectl apply -f -
    done

    # Delete the to_delete version
    kubectl -n $kubernetes_namespace delete VirtualNode "$microservice_name-$to_delete"
    kubectl -n $kubernetes_namespace delete deploy/"$microservice_name-$to_delete" svc/"$microservice_name-$to_delete"

    # Lambda runtime response
    export response=true

}