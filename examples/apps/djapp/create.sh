# Namespace
kubectl create -f 1_create_the_initial_architecture/1_prod_ns.yaml

# Initial Deployments and Services
kubectl create -nprod -f 1_create_the_initial_architecture/1_initial_architecture_deployment.yaml
kubectl create -nprod -f 1_create_the_initial_architecture/1_initial_architecture_services.yaml

# Create Injector Controller

cd 2_create_injector
./create.sh
cd ..
kubectl label namespace prod appmesh.k8s.aws/sidecarInjectorWebhook=enabled


# Create CRDs

sleep 5

kubectl apply -f 3_add_crds/mesh-definition.yaml
kubectl apply -f 3_add_crds/virtual-node-definition.yaml
kubectl apply -f 3_add_crds/virtual-service-definition.yaml
kubectl apply -f 3_add_crds/controller-deployment.yaml

sleep 5
# Create MESH
kubectl create -nprod -f 4_create_initial_mesh_components/mesh.yaml

sleep 5
# Create Virtual Nodes for Virtual Services

kubectl create -nprod -f 4_create_initial_mesh_components/nodes_representing_virtual_services.yaml

# Create Placeholder Services for Virtual Nodes for Virtual Services

kubectl create -nprod -f 4_create_initial_mesh_components/metal_and_jazz_placeholder_services.yaml

# Create Virtual Nodes for Physical Services

kubectl create -nprod -f 4_create_initial_mesh_components/nodes_representing_physical_services.yaml

# Create Jazz and Metal Virtual Service Resources

kubectl apply -nprod -f 4_create_initial_mesh_components/virtual-services.yaml

# Bounce the deployments to include sidecars

sleep 15

kubectl patch deployment dj -nprod -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployment metal-v1 -nprod -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployment jazz-v1 -nprod -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"

# Create the v2 components

sleep 15

kubectl apply -nprod -f 5_canary/jazz_v2.yaml
kubectl apply -nprod -f 5_canary/jazz_service_update.yaml
kubectl apply -nprod -f 5_canary/metal_v2.yaml
kubectl apply -nprod -f 5_canary/metal_service_update.yaml
