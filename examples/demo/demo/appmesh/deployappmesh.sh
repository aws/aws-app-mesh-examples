#!/bin/bash
set -x

echo "Creating mesh, if your mesh was already created you can ignore this error"
aws appmesh create-mesh --mesh-name ${MESH_NAME}

echo "Deploying front end virtual node"
aws appmesh create-virtual-node --mesh-name ${MESH_NAME} --cli-input-json file://frontend.vn.json

echo "Deploying colors virtual node"
aws appmesh create-virtual-node --mesh-name ${MESH_NAME} --cli-input-json file://colors.vn.json

echo "Deploying orange virtual node"
aws appmesh create-virtual-node --mesh-name ${MESH_NAME} --cli-input-json file://orange.vn.json

echo "Deploying blue virtual node"
aws appmesh create-virtual-node --mesh-name ${MESH_NAME} --cli-input-json file://blue.vn.json

echo "Deploying green virtual node"
aws appmesh create-virtual-node --mesh-name ${MESH_NAME} --cli-input-json file://green.vn.json

echo "Deploying colors virtual router"
aws appmesh create-virtual-router --mesh-name ${MESH_NAME} --cli-input-json file://colors.vr.json

echo "Creating virtual service for colors"
aws appmesh create-virtual-service --mesh-name ${MESH_NAME} --cli-input-json file://colors.vs.json

echo "Deploying colors route"
aws appmesh create-route --mesh-name ${MESH_NAME} --cli-input-json file://colors.r.json
