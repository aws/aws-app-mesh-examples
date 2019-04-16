target=$1

echo "Execing into pod and curling http://$target.prod.svc.cluster.local:9080"


thepod=$(kubectl get pods -l app=dj -o json -nprod | jq .items[0].metadata.name | sed 's/"//g')
kubectl exec $thepod -nprod -t -- bash -c "while [ 1 ]; do curl -s http://{$target}.prod.svc.cluster.local:9080;echo; done"
