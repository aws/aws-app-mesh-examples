#! /bin/bash

MESH=$1
DELETE=$2

account=($(aws sts get-caller-identity --query "Account" | sed -e 's/^"//' -e 's/"$//'))
echo Running for account $account

meshes=($(aws appmesh list-meshes --query "meshes[*].meshName" --output text))
services=($(aws appmesh list-virtual-services --mesh-name $MESH --query "virtualServices[*].virtualServiceName" --output text))
routers=($(aws appmesh list-virtual-routers --mesh-name $MESH --query "virtualRouters[*].virtualRouterName" --output text))
nodes=($(aws appmesh list-virtual-nodes --mesh-name $MESH --query "virtualNodes[*].virtualNodeName" --output text))

pods=($(kubectl get pods -nprod | awk ' { printf sep $1; sep=" "} ' | sed -e 's/NAME//g'))

echo Found Mesh: ${meshes[*]}
echo Found Virtual Services: ${services[*]}
echo Found Virtual Routers: ${routers[*]}
echo Found Virtual Nodes: ${nodes[*]}
echo Found pods: ${pods[*]}

echo

for vs in "${services[@]}"
do
  # echo "Virtual Service: $vs"
  if [ -n "$DELETE" ]; then
    echo Deleting Virtual Service: $vs
    aws appmesh delete-virtual-service --mesh-name $MESH --virtual-service-name $vs
    sleep 3
  fi
done


for vr in "${routers[@]}"
do
    # echo "Router: $vr"

    routes=($(aws appmesh list-routes --mesh-name $MESH --virtual-router-name $vr --query 'routes[*].routeName' --output text))
    echo Found Route in ${vr}: ${routes[*]}

    # Delete routes
    for r in "${routes[@]}"
    do
      if [ -n "$DELETE" ]; then
        echo Deleting route: $r
        aws appmesh delete-route --mesh-name $MESH --route-name $r --virtual-router-name $vr
        sleep 3
      fi
    done


    echo

    # Delete routers

    if [ -n "$DELETE" ]; then
      echo Deleting router: $vr
      aws appmesh delete-virtual-router --mesh-name $MESH --virtual-router-name $vr
      sleep 3
    fi
done

# delete Nodes

for vn in "${nodes[@]}"
do
  if [ -n "$DELETE" ]; then
    echo Deleting Virtual Node: $vn
    aws appmesh delete-virtual-node --mesh-name $MESH --virtual-node-name $vn
    sleep 3
  fi
done


# delete meshes

for m in "${meshes[@]}"
do
  if [ -n "$DELETE" ]; then
    echo Deleting App Mesh: $m
    aws appmesh delete-mesh --mesh-name $m
    sleep 3
  fi
done
