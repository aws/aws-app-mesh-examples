#!/bin/bash
set -x

echo "Deleing virtual service for colors"
aws appmesh delete-virtual-service --mesh-name ${MESH_NAME} --virtual-service-name colors

echo "Deleting colors route"
aws appmesh delete-route --mesh-name ${MESH_NAME} --route-name colors-route --virtual-router-name colors

echo "Deleting colors virtuals router"
aws appmesh delete-virtual-router --mesh-name ${MESH_NAME} --virtual-router-name colors

echo "Deleting frontend virtual node"
aws appmesh delete-virtual-node --mesh-name ${MESH_NAME} --virtual-node-name front-end-appmesh-demo

echo "Deleting colors node"
aws appmesh delete-virtual-node --mesh-name ${MESH_NAME} --virtual-node-name colors

echo "Deleting orange node"
aws appmesh delete-virtual-node --mesh-name ${MESH_NAME} --virtual-node-name orange-appmesh-demo

echo "Deleting blue node"
aws appmesh delete-virtual-node --mesh-name ${MESH_NAME} --virtual-node-name blue-appmesh-demo

echo "Deleting green node"
aws appmesh delete-virtual-node --mesh-name ${MESH_NAME} --virtual-node-name green-appmesh-demo

echo "Deleting mesh"
aws appmesh delete-mesh --mesh-name ${MESH_NAME}
