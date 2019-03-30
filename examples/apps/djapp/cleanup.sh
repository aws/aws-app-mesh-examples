cd 2_create_injector
./delete.sh
cd ..
kubectl delete -nprod -f  5_canary/
kubectl delete -nprod -f 4_create_initial_mesh_components/

sleep 5

kubectl delete -f 3_add_crds/controller-deployment.yaml
kubectl delete -f 3_add_crds/virtual-service-definition.yaml
kubectl delete -f 3_add_crds/virtual-node-definition.yaml
kubectl delete -f 3_add_crds/mesh-definition.yaml

sleep 5

kubectl delete -nprod -f 1_create_the_initial_architecture/

sleep 5
./amctl.sh dj-app delete
