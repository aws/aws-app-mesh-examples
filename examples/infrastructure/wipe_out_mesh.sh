#!/bin/bash

set -ex

if [ "$APPMESH_ENDPOINT" = "" ]; then
    appmesh_cmd="aws appmesh"
else
    appmesh_cmd="aws --endpoint-url "${APPMESH_ENDPOINT}" appmesh"
fi

virtual_services=($($appmesh_cmd list-virtual-services \
    --mesh-name "${MESH_NAME}" \
    | jq -r ".virtualServices[].virtualServiceName"))

for virtual_service_name in ${virtual_services[@]}
do
    $appmesh_cmd delete-virtual-service \
        --mesh-name "${MESH_NAME}" \
        --virtual-service-name "${virtual_service_name}" || echo "Unable to delete virtual-service $virtual_service_name $?"
done

virtual_routers=($($appmesh_cmd list-virtual-routers \
    --mesh-name "${MESH_NAME}" \
    | jq -r ".virtualRouters[].virtualRouterName"))

for virtual_router_name in ${virtual_routers[@]}
do
    routes=($($appmesh_cmd list-routes \
        --mesh-name "${MESH_NAME}" \
        --virtual-router-name "${virtual_router_name}" \
        | jq -r ".routes[].routeName"))

    for route_name in ${routes[@]}
    do
        $appmesh_cmd delete-route \
            --mesh-name "${MESH_NAME}" \
            --virtual-router-name "${virtual_router_name}" \
            --route-name "${route_name}" || echo "Unable to delete route $route_name $?"
    done
done

for virtual_router_name in ${virtual_routers[@]}
do
    $appmesh_cmd delete-virtual-router \
        --mesh-name "${MESH_NAME}" \
        --virtual-router-name "${virtual_router_name}" || echo "Unable to delete virtual-router $virtual_router_name $?"
done


virtual_nodes=($($appmesh_cmd list-virtual-nodes \
    --mesh-name "${MESH_NAME}" \
    | jq -r ".virtualNodes[].virtualNodeName"))

for virtual_node_name in ${virtual_nodes[@]}
do
    $appmesh_cmd delete-virtual-node \
        --mesh-name "${MESH_NAME}" \
        --virtual-node-name "$virtual_node_name" || echo "Unable to delete virtual-node $virtual_node_name $?"
done

$appmesh_cmd delete-mesh --mesh-name "${MESH_NAME}" || echo "Unable to delete mesh ${MESH_NAME} $?"
