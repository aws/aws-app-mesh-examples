# AppMesh K8s Load Test
This walkthrough demonstrates how to load test AppMesh on EKS. It can be used as a tool for further load testing in different mesh configuration. We use [Fortio](https://github.com/fortio/fortio) to generate the load. Currently, this walkthrough only focuses AppMesh on EKS. 

## Step 1: Prerequisites
1. [Walkthrough: App Mesh with EKS](../eks/). Make sure you have:
   1. Cloned the [AWS AppMesh controller repo](https://github.com/aws/aws-app-mesh-controller-for-k8s). We will need this controller repo path (`CONTROLLER_PATH`) in [step 2](##step-2:-set-environment-variables).
   2. Created an EKS cluster and setup kubeconfig.
   3. Installed "appmesh-prometheus". You may follow this [App Mesh Prometheus](https://github.com/aws/eks-charts/tree/master/stable/appmesh-prometheus) chart for installation support.
   4. This load test uses [Ginkgo](https://github.com/onsi/ginkgo/tree/v1.16.4). Make sure you have ginkgo installed by running `ginkgo version`. If it's not, you may need to install it:
      1. Install [Go](https://go.dev/doc/install), if you haven't already.
      2. Install Ginkgo v1.16.4 (currently, AppMesh controller uses [ginkgo v1.16.4](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/go.mod#L13))
         1. `go get -u github.com/onsi/ginkgo/ginkgo@v1.16.5` or 
         2. `go install github.com/onsi/ginkgo/ginkgo@v1.16.5` for GO version 1.17+
   5. (Optional) You can follow this doc: [Getting started with AWS App Mesh and Kubernetes](https://docs.aws.amazon.com/app-mesh/latest/userguide/getting-started-kubernetes.html) to install appmesh-controller and EKS cluster using `eksctl`.
2. Clone this repository and navigate to the `walkthroughs/howto-k8s-appmesh-load-test` folder, all the commands henceforth are assumed to be run from the same directory as this `README`.
3. Make sure you have the latest version of [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) or [AWS CLI v1](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv1.html) installed.
4. This test requires Python 3 or later (tested with Python 3.9.6). So make sure you have [Python 3](https://www.python.org/downloads/) installed.  
5. Load test results will be stored into S3 bucket. So, in `scripts/constants.py` give your `S3_BUCKET` a unique name. 
6. In case you get `AccessDeniedException` (or any kind of accessing AWS resource denied exception) while creating any AppMesh resources (e.g., VirtualNode), don't forget to authenticate with your AWS account.


## Step 2: Set Environment Variables
We need to set a few environment variables before starting the load tests.

```bash
export CONTROLLER_PATH=<Path to the controller repo we cloned in step 1, e.g., /home/userName/workplace/appmesh-controller/aws-app-mesh-controller-for-k8s>
export CLUSTER_NAME=<Name of the EKS cluster, e.g., appmeshtest>
export KUBECONFIG=<If eksctl is used to create the cluster, the KUBECONFIG will look like: ~/.kube/eksctl/clusters/cluster-name>
export AWS_REGION=us-west-2
export VPC_ID=<VPC ID of the cluster, can be found using:  aws eks describe-cluster --name $CLUSTER_NAME | grep 'vpcId'>
```



## Step 3: Configuring the Load Test
All parameters of the mesh, load tests, metrics can be specified in `config.json`

`backends_map` -: The mapping from each Virtual Node to its backend Virtual Services. For each unique node name in `backends_map`, 
a VirtualNode, Deployment, Service and VirtualService (with its VirtualNode as its target) are created at runtime.

`load_tests` -: Array of different test configurations that need to be run on the mesh. `url` is the service endpoint that Fortio (load generator) should hit.

`metrics` -: Map of metric_name to the corresponding metric PromQL logic

## Step 4: Running the Load Test
Run the driver script using the below command -:
> sh scripts/driver.sh

The driver script will perform the following -:
1. Install necessary Python3 libraries.
2. Port-forward the Prometheus service to local.
3. Run the Ginkgo test which is the entrypoint for our load test.
4. Kill the Prometheus port-forwarding after the load Test is done.


## Step 5: Analyze the Results
All the test results are saved into `S3_BUCKET` which was specified in `scripts/constants.py`.    
Optionally, you can run the `scripts/analyze_load_test_data.py` to visualize the results.  
The `analyze_load_test_data.py` will
* First download all the load test results from the `S3_BUCKET` into `scripts\data` directory, then 
* Plot a graph against the actual QPS (query per second) Fortio sends to the first VirtualNode vs the max memory consumed by the container of that VirtualNode.

## Description of other files
`load_driver.py` -: Script which reads `config.json` and triggers load tests, reads metrics from PromQL and writes to S3. Called from within ginkgo

`fortio.yaml` -: Spec of the Fortio components which are created during runtime

`request_handler.py` and `request_handler_driver.sh` -: The custom service that runs in each of the pods to handle and route incoming requests according 
to the mapping in `backends_map` 

`configmap.yaml` -: ConfigMap spec to mount above request_handler* files into the cluster instead of creating Docker containers. Don't forget to use the absolute path of `request_handler_driver.sh`

`cluster.yaml` -: A sample EKS cluster config. This `cluster.yaml` can be used to create an EKS cluster by running `eksctl create cluster -f cluster.yaml`
