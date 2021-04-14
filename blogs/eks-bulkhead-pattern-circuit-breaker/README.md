# EKS Bulkhead Pattern and Circuit Breakers
> Setup content for the article

## Requirements

* EKS with AppMesh Setup
* docker, git, jq, kubectl, httpie installed

## Setup

⚠️  Make sure to set `AWS_ACCOUNT_ID`, `AWS_DEFAULT_REGION` and that your kubectl is set to the correct cluster.

The `deploy.sh` is the entrypoint, it will:

* Build the docker image
* Create a namespace called `bulkhead-pattern`
* Configure a new Mesh called `bukhead-pattern`
* Deploy 2 version of the app, for write and read
* Configure the Mesh to have a virtual gateway, virtual service, 2 virtual notes and a virtual router.
* Expose virtual gateway is through a Kubernetes LoadBalancer Type Service
* Create a [vegeta](https://github.com/tsenart/vegeta) deployment for load-testing within the cluster

The `update.sh` will set the connection pools of the nodes to avoid flooding the pods with requests they won't handle.

The `cleanup.sh` will delete the ECR repository, the Kubernetes namespace and it's resources and finally the Mesh.

## Docker Image

The price app is covered in more detail in the article.

The docker image in `price-app/` has 3 endpoints:

* `GET /health` - just returns 200
* `GET /price/$1` - returns 200 with a static JSON
* `POST /price` - return 200 with a static JSON (delayed configured)

The POST endpoint is faking a network/database delay, configured by the ENV variable `DATABASE_DELAY`, example accepted values: `1ms`, `5s`, `10s`, default is set to 10s.
