

kubectl apply -f appmesh-ns.yaml
./gen-cert.sh
echo
./ca-bundle.sh
echo
kubectl apply -f inject.yaml
echo
echo Waiting for pods to come up...
sleep 15
echo
echo App Inject Pods and Services After Install:
echo
kubectl get svc -nappmesh-inject
kubectl get pods -nappmesh-inject
