echo
echo Remove Injector and App Mesh Controller components
echo

kubectl delete -f 3_add_crds/virtual-service-definition.yaml
kubectl delete -f 3_add_crds/virtual-node-definition.yaml
kubectl delete -f 3_add_crds/mesh-definition.yaml
kubectl delete -f 3_add_crds/controller-deployment.yaml

kubectl delete secret aws-app-mesh-inject -nappmesh-inject
kubectl delete -f 2_create_injector/inject.yaml

echo
echo Remove k8s DJ App NS, Deployments, and Services
echo

kubectl delete deployment -nprod dj
kubectl delete deployment -nprod metal-v1
kubectl delete deployment -nprod metal-v2
kubectl delete deployment -nprod jazz-v1
kubectl delete deployment -nprod jazz-v2

kubectl delete service -nprod dj
kubectl delete service -nprod metal-v1
kubectl delete service -nprod metal-v1
kubectl delete service -nprod metal
kubectl delete service -nprod jazz-v1
kubectl delete service -nprod jazz-v2
kubectl delete service -nprod jazz

kubectl delete ns prod
