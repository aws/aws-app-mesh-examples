# Kubernetes deployment

The steps below require that you have already [built the images](../README.md).


## Local deployment

You can deploy the voting app using the following commands:

```
kubectl create -f database-deployment.yml -f database-service.yml -f queue-deployment.yml -f queue-service.yml -f vote-deployment.yml -f vote-service.yml -f worker-deployment.yml

```

Make sure the application is up and running by running the following command:
```
$ kubectl get all
NAME                         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/database-deployment   1         1         1            1           9s
deploy/queue-deployment      1         1         1            1           9s
deploy/vote-deployment       1         1         1            1           9s
deploy/worker-deployment     1         1         1            1           9s

NAME                                DESIRED   CURRENT   READY     AGE
rs/database-deployment-6c656f4697   1         1         1         9s
rs/queue-deployment-849484d6cd      1         1         1         9s
rs/vote-deployment-6cc9b555bd       1         1         1         9s
rs/worker-deployment-76f648b9f      1         1         1         9s

NAME                         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/database-deployment   1         1         1            1           9s
deploy/queue-deployment      1         1         1            1           9s
deploy/vote-deployment       1         1         1            1           9s
deploy/worker-deployment     1         1         1            1           9s

NAME                                DESIRED   CURRENT   READY     AGE
rs/database-deployment-6c656f4697   1         1         1         9s
rs/queue-deployment-849484d6cd      1         1         1         9s
rs/vote-deployment-6cc9b555bd       1         1         1         9s
rs/worker-deployment-76f648b9f      1         1         1         9s

NAME                                      READY     STATUS    RESTARTS   AGE
po/database-deployment-6c656f4697-g57h5   1/1       Running   0          9s
po/queue-deployment-849484d6cd-sszfw      1/1       Running   0          9s
po/vote-deployment-6cc9b555bd-x2czq       1/1       Running   0          9s
po/worker-deployment-76f648b9f-2rll8      1/1       Running   0          9s

NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
svc/database     ClusterIP   10.101.23.61    <none>        27017/TCP   9s
svc/kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP     5m
svc/queue        ClusterIP   10.111.198.49   <none>        6379/TCP    9s
svc/vote         ClusterIP   10.109.15.94    <none>        3000/TCP    9s
```

You can now vote:

```
$ kubectl run voter --rm -i --tty --image subfuzion/voter --image-pull-policy=IfNotPresent -- vote
If you don't see a command prompt, try pressing enter.
? What do you like better?
❯ (quit)
  cats
  dogs

```

You can check the vote results:
```
$ kubectl run voter --rm -i --tty --image subfuzion/voter --image-pull-policy=IfNotPresent -- results
If you don't see a command prompt, try pressing enter.
Total votes -> cats: 0, dogs: 1 ... DOGS WIN!
```

When you're done, remove the application using the following command:
```
$ kubectl delete deploy/database-deployment deploy/queue-deployment deploy/vote-deployment deploy/worker-deployment svc/database svc/queue svc/vote
```

## Cloud deployment

### Docker Images
If your deployment is on a cloud cluster, tag and push these images on your private registry.

As an example, if [deploying on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-container-cluster), use a command similar to:

```
export PROJECT_ID=YOUR_PROJECT_ID
docker tag vote:latest gcr.io/$PROJECT_ID/vote:latest
gcloud docker -- push gcr.io/$PROJECT_ID/vote:latest
docker tag worker:latest gcr.io/$PROJECT_ID/worker:latest
gcloud docker -- push gcr.io/$PROJECT_ID/worker:latest
```

You'll then have to modify the worker-deployment.yml and vote-deployment.yml files to replace the name of the image by the tagged one.


### Deployment

Deploy the voting app using the following commands:

```
kubectl create -f database-deployment.yml -f database-service.yml -f queue-deployment.yml -f queue-service.yml -f vote-deployment.yml -f vote-service.yml -f worker-deployment.yml

```

Make sure the application is up and running by running the following command:
```
$ kubectl get all
NAME                         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/database-deployment   1         1         1            1           9s
deploy/queue-deployment      1         1         1            1           9s
deploy/vote-deployment       1         1         1            1           9s
deploy/worker-deployment     1         1         1            1           9s

NAME                                DESIRED   CURRENT   READY     AGE
rs/database-deployment-6c656f4697   1         1         1         9s
rs/queue-deployment-849484d6cd      1         1         1         9s
rs/vote-deployment-6cc9b555bd       1         1         1         9s
rs/worker-deployment-76f648b9f      1         1         1         9s

NAME                         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/database-deployment   1         1         1            1           9s
deploy/queue-deployment      1         1         1            1           9s
deploy/vote-deployment       1         1         1            1           9s
deploy/worker-deployment     1         1         1            1           9s

NAME                                DESIRED   CURRENT   READY     AGE
rs/database-deployment-6c656f4697   1         1         1         9s
rs/queue-deployment-849484d6cd      1         1         1         9s
rs/vote-deployment-6cc9b555bd       1         1         1         9s
rs/worker-deployment-76f648b9f      1         1         1         9s

NAME                                      READY     STATUS    RESTARTS   AGE
po/database-deployment-6c656f4697-g57h5   1/1       Running   0          9s
po/queue-deployment-849484d6cd-sszfw      1/1       Running   0          9s
po/vote-deployment-6cc9b555bd-x2czq       1/1       Running   0          9s
po/worker-deployment-76f648b9f-2rll8      1/1       Running   0          9s

NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
svc/database     ClusterIP   10.101.23.61    <none>        27017/TCP   9s
svc/kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP     5m
svc/queue        ClusterIP   10.111.198.49   <none>        6379/TCP    9s
svc/vote         ClusterIP   10.109.15.94    <none>        3000/TCP    9s
```

### Setting up an ingress to access the vote service from internet

Create an ingress for the vote service:

```
kubectl create -f vote-ingress.yml

```

Wait for the ingress to be ready (it should have an IP):

```
kubectl get ingress vote-ingress
NAME           HOSTS     ADDRESS          PORTS     AGE
vote-ingress   *         35.227.221.249   80        2h
```

You can check with your browser that the API is working:

```
curl 35.227.221.249
{"success":true,"result":"hello"}
```

You can now vote using the IP address of the ingress and port 80:

```
$ docker run -it --rm -e VOTE_API_HOST=35.227.221.249 -e VOTE_API_PORT=80 subfuzion/voter vote
? What do you like better?
❯ (quit)
  cats
  dogs
```

You can check the vote results:
```
$ docker run -it --rm -e VOTE_API_HOST=35.227.221.249 -e VOTE_API_PORT=80 subfuzion/voter results
Total votes -> cats: 0, dogs: 1 ... DOGS WIN!
```

When you're done, remove the application using the following command:
```
$ kubectl delete deploy/database-deployment deploy/queue-deployment deploy/vote-deployment deploy/worker-deployment svc/database svc/queue svc/vote ingress/vote-ingress
```
