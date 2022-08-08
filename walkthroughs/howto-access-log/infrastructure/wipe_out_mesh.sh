#!/bin/bash

set -ex

if [ ! -z "${AWS_PROFILE}" ]; then
    PROFILE_OPT="--profile ${AWS_PROFILE}"
fi

if [ "$APPMESH_ENDPOINT" = "" ]; then
    appmesh_cmd="aws appmesh"
else
    appmesh_cmd="aws --endpoint-url "${APPMESH_ENDPOINT}" appmesh"
fi

virtual_services=($($appmesh_cmd list-virtual-services \
    ${PROFILE_OPT} \
    --mesh-name "${MESH_NAME}" \
    | jq -r ".virtualServices[].virtualServiceName"))

for virtual_service_name in ${virtual_services[@]}
do
    $appmesh_cmd delete-virtual-service \
        ${PROFILE_OPT} \
        --mesh-name "${MESH_NAME}" \
        --virtual-service-name "${virtual_service_name}" || echo "Unable to delete virtual-service $virtual_service_name $?"
done

virtual_routers=($($appmesh_cmd list-virtual-routers \
    ${PROFILE_OPT} \
    --mesh-name "${MESH_NAME}" \
    | jq -r ".virtualRouters[].virtualRouterName"))

for virtual_router_name in ${virtual_routers[@]}
do
    routes=($($appmesh_cmd list-routes \
        ${PROFILE_OPT} \
        --mesh-name "${MESH_NAME}" \
        --virtual-router-name "${virtual_router_name}" \
        | jq -r ".routes[].routeName"))

    for route_name in ${routes[@]}
    do
        $appmesh_cmd delete-route \
            ${PROFILE_OPT} \
            --mesh-name "${MESH_NAME}" \
            --virtual-router-name "${virtual_router_name}" \
            --route-name "${route_name}" || echo "Unable to delete route $route_name $?"
    done
done

for virtual_router_name in ${virtual_routers[@]}
do
    $appmesh_cmd delete-virtual-router \
        ${PROFILE_OPT} \
        --mesh-name "${MESH_NAME}" \
        --virtual-router-name "${virtual_router_name}" || echo "Unable to delete virtual-router $virtual_router_name $?"
done


virtual_nodes=($($appmesh_cmd list-virtual-nodes \
    ${PROFILE_OPT} \
    --mesh-name "${MESH_NAME}" \
    | jq -r ".virtualNodes[].virtualNodeName"))

for virtual_node_name in ${virtual_nodes[@]}
do
    $appmesh_cmd delete-virtual-node \
        ${PROFILE_OPT} \
        --mesh-name "${MESH_NAME}" \
        --virtual-node-name "$virtual_node_name" || echo "Unable to delete virtual-node $virtual_node_name $?"
done

$appmesh_cmd delete-mesh ${PROFILE_OPT} --mesh-name "${MESH_NAME}" || echo "Unable to delete mesh ${MESH_NAME} $?"
