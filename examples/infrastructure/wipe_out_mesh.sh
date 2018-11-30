#!/bin/bash

set -ex

virtual_routers=($(aws appmesh list-virtual-routers \
    --mesh-name "${MESH_NAME}" \
    | jq -r ".virtualRouters[].virtualRouterName"))

for virtual_router_name in ${virtual_routers[@]}
do
    routes=($(aws appmesh list-routes \
        --mesh-name "${MESH_NAME}" \
        --virtual-router-name "${virtual_router_name}" \
        | jq -r ".routes[].routeName"))

    for route_name in ${routes[@]}
    do
        aws appmesh delete-route \
            --mesh-name "${MESH_NAME}" \
            --virtual-router-name "${virtual_router_name}" \
            --route-name "${route_name}" || echo "Unable to delete route $route_name $?"
    done
done

for virtual_router_name in ${virtual_routers[@]}
do
    aws appmesh delete-virtual-router \
        --mesh-name "${MESH_NAME}" \
        --virtual-router-name "${virtual_router_name}" || echo "Unable to delete virtual-router $virtual_router_name $?"
done


virtual_nodes=($(aws appmesh list-virtual-nodes \
    --mesh-name "${MESH_NAME}" \
    | jq -r ".virtualNodes[].virtualNodeName"))

for virtual_node_name in ${virtual_nodes[@]}
do
    aws appmesh delete-virtual-node \
        --mesh-name "${MESH_NAME}" \
        --virtual-node-name "$virtual_node_name" || echo "Unable to delete virtual-node $virtual_node_name $?"
done

aws appmesh delete-mesh --mesh-name "${MESH_NAME}" || echo "Unable to delete mesh ${MESH_NAME} $?"
