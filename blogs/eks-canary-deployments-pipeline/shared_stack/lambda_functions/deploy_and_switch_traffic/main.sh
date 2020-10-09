function handler () {
    # Get variables
    cluster_name=$(echo $1 | jq -r '.cluster_name')
    new_version=$(echo $1 | jq -r '.deployment.new_version | tonumber')
    container_image=$(echo $1 | jq -r '.container_image')
    microservice_name=$(echo $1 | jq -r '.microservice_name')
    kubernetes_namespace=$(echo $1 | jq -r '.kubernetes_namespace')

    echo $1 | jq -r '.config_file' | base64 -d > /tmp/deployment.yml

    # Create kubeconfig file
    aws eks update-kubeconfig --name $cluster_name --kubeconfig /tmp/kubeconfig

    # Check if first deployment then apply all traffic to deployed version
    if [ $new_version -eq 1 ]; then
        canary_routes='{"virtualNodeRef":{"name":"'$microservice_name'-'$new_version'"},"weight":1}'
        new_percentage=100
    else
        percentage_step=$(echo $1 | jq -r '.percentage_step | tonumber')
        current_percentage=$(echo $1 | jq -r '.deployment.current_percentage | tonumber')

        new_percentage=$(($current_percentage + $percentage_step))
        # Ensure that new percentage is not greater than 100%
        if [ $new_percentage -gt 100 ]; then
          new_percentage=100
        fi
        old_percentage=$((100 - $new_percentage))
        old_version=$(($new_version - 1))
        canary_routes='{"virtualNodeRef":{"name":"'$microservice_name'-'$new_version'"},"weight":'$new_percentage'},{"virtualNodeRef":{"name":"'$microservice_name'-'$old_version'"},"weight":'$old_percentage'}'
    fi

    # Apply configurations to deployment spec
    sed -i 's@${CANARY_VERSION}@'"$new_version"'@' /tmp/deployment.yml
    sed -i 's@${CONTAINER_IMAGE}@'"$container_image"'@' /tmp/deployment.yml
    sed -i 's@${CANARY_ROUTES}@'"$canary_routes"'@' /tmp/deployment.yml
    sed -i 's@${KUBERNETES_NAMESPACE}@'"$kubernetes_namespace"'@' /tmp/deployment.yml
    sed -i 's@${MICROSERVICE_NAME}@'"$microservice_name"'@' /tmp/deployment.yml

    # Apply deployment to kubernetes
    kubectl apply -f /tmp/deployment.yml

    # Output configured specfile to logs
    echo "Microservice: $microservice_name"
    echo "Container Image: $container_image"
    echo "Deployment Version: $new_version"
    echo "Traffic Route: $canary_routes"

    # Lambda runtime response
    export response=$new_percentage
}