## Prerequisites
- [EKS Walkthrough](https://github.com/aws/aws-app-mesh-examples/tree/master/walkthroughs/eks)

## Usage
1. Set following environment variables
```
export AWS_ACCOUNT_ID=<your_account_id>
export AWS_DEFAULT_REGION=<aws_region where appmesh is available, e.g. us-west-2>
```

2. Deploy application images to ECR
```
./deploy-images.sh
```

3. Deploy Kubernetes manifests
```
./k8s/deploy.sh
```