## Overview
This example shows how to access external services outside of your mesh.

The example will create two Kubernetes namespaces: `howto-k8s-egress` and `mesh-external`. Mesh will span only the namespace `howto-k8s-egress` and resources in it and `mesh-external` is not part the Mesh.
`mesh-external` will have two services `red` and `blue`, where we will show case the two external services are accessible from the Mesh:
  * by using Mesh `ALLOW_ALL` egress filter
  * by using Mesh `DROP_ALL` egress filter with blue service exposed via a virtual node (to make it selectively accessible)

## Prerequisites
1. [Walkthrough: App Mesh with EKS](../eks/)

2. The manifest in this walkthrough requires [aws-app-mesh-controller-for-k8s](https://github.com/aws/aws-app-mesh-controller-for-k8s) version [>=v1.0.0](https://github.com/aws/aws-app-mesh-controller-for-k8s/releases/tag/v1.0.0). Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1
```

3. Install Docker. `deploy.sh` script builds the demo application images using Docker CLI.

## Setup
1. Clone this repository and navigate to the walkthrough/howto-k8s-egress folder, all commands will be ran from this location

2. Your AWS account id:

```
    export AWS_ACCOUNT_ID=<your_account_id>
```

3. Region e.g. us-west-2

```
    export AWS_DEFAULT_REGION=us-west-2
```

4. **(Optional) Specify Envoy Image version** If you'd like to use a different Envoy image version than the [default](https://github.com/aws/eks-charts/tree/master/stable/appmesh-controller#configuration), run `helm upgrade` to override the `sidecar.image.repository` and `sidecar.image.tag` fields.
5. Deploy the application and Mesh

```
    ./deploy.sh
```

## Verify

1. Verify two namespaces are created: `howto-k8s-egress` (part of the Mesh) and `mesh-external` (outside the Mesh)
```
kubectl get ns

appmesh-system     Active   10d
default            Active   10d
howto-k8s-egress   Active   6s
kube-node-lease    Active   10d
kube-public        Active   10d
kube-system        Active   10d
mesh-external      Active   6s

```

2. Let's check the external services
```
kubectl get pod,svc -n mesh-external

NAME                        READY   STATUS    RESTARTS   AGE
pod/blue-5cf49bddcf-mnlrx   1/1     Running   0          2m17s
pod/red-7c595d6f8f-jj2vh    1/1     Running   0          2m17s

NAME           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/blue   ClusterIP   10.100.254.102   <none>        8080/TCP   2m17s
service/red    ClusterIP   10.100.237.219   <none>        8080/TCP   2m17s
```

3. Check connectivity to `blue` and `red` from inside the Mesh

    Exec into the front pod
```
FRONT_POD=$(kubectl get pod -l "app=front" -n howto-k8s-egress --output=jsonpath={.items..metadata.name})
kubectl exec -it $FRONT_POD -n howto-k8s-egress -- /bin/bash
```

4. Check connectivity to external service: `blue`

```
curl blue.mesh-external.svc.cluster.local:8080/; echo;
external: blue
```

You should see a response like `external: blue` since we have setup a virtual node inside the Mesh to refer to this external service despite having `DROP_ALL` egress at Mesh level

5. Check connectivity to external service: `red`

```
curl red.mesh-external.svc.cluster.local:8080/; echo;

```
You should get a 404 response when accessing the external service `red` as Mesh has `DROP_ALL` egress and we don't have any virtual node refering to this external service


6. Modify the Mesh to `ALLOW_ALL` egress

Change mesh->egressFilter in `v1beta2/manifest.yaml.template` to `ALLOW_ALL` and deploy the application again

```
SKIP_IMAGES=1 ./deploy.sh
```

7. Check connectivity to external services: `blue` and `red`

```
curl blue.mesh-external.svc.cluster.local:8080/; echo;
external: blue

curl red.mesh-external.svc.cluster.local:8080/; echo;
external: red
```

You should be responses from both the external service as the Mesh allows connecting all external services using `ALLOW_ALL` egressFilter

## Cleanup
If you want to keep the application running, you can do so, but this is the end of this walkthrough. Run the following commands to clean up and tear down the resources that we’ve created.

```
kubectl delete -f _output/manifest.yaml
```
