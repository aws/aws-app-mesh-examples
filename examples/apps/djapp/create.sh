echo
echo Create Prod Namespace
echo

kubectl create -f 1_create_the_initial_architecture/1_prod_ns.yaml

echo
echo Initial Deployments and Services
echo

kubectl create -nprod -f 1_create_the_initial_architecture/1_initial_architecture_deployment.yaml
kubectl create -nprod -f 1_create_the_initial_architecture/1_initial_architecture_services.yaml

echo
echo Create Injector Controller
echo

cd 2_create_injector
./create.sh
cd ..
kubectl label namespace prod appmesh.k8s.aws/sidecarInjectorWebhook=enabled

echo
echo Create CRDs
echo

sleep 5

kubectl apply -f 3_add_crds/mesh-definition.yaml
kubectl apply -f 3_add_crds/virtual-node-definition.yaml
kubectl apply -f 3_add_crds/virtual-service-definition.yaml
kubectl apply -f 3_add_crds/controller-deployment.yaml

sleep 5

echo
echo Create Mesh
echo

kubectl create -nprod -f 4_create_initial_mesh_components/mesh.yaml

sleep 5

echo
echo Create Virtual Nodes for Virtual Services
echo

kubectl create -nprod -f 4_create_initial_mesh_components/nodes_representing_virtual_services.yaml

echo
echo Create Placeholder Services for Virtual Nodes for Virtual Services
echo

kubectl create -nprod -f 4_create_initial_mesh_components/metal_and_jazz_placeholder_services.yaml

echo
echo Create Virtual Nodes for Physical Services and Virtual Services
echo

kubectl create -nprod -f 4_create_initial_mesh_components/nodes_representing_physical_services.yaml
kubectl apply -nprod -f 4_create_initial_mesh_components/virtual-services.yaml

echo
echo Create Jazz and Metal v2 Resources
echo

kubectl apply -nprod -f 5_canary/jazz_v2.yaml
kubectl apply -nprod -f 5_canary/jazz_service_update.yaml
kubectl apply -nprod -f 5_canary/metal_v2.yaml
kubectl apply -nprod -f 5_canary/metal_service_update.yaml

sleep 30

echo
echo Bounce the deployments to include sidecars
echo

kubectl patch deployment dj -nprod -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployment metal-v1 -nprod -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployment jazz-v1 -nprod -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"

echo
echo "Waiting for pods to come back up."
echo
sleep 30
