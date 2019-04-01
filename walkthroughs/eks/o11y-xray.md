# App Mesh with EKS—Observability: X-Ray

NOTE: Before you start with this part, make sure you've gone through the [base deployment](base.md) of App Mesh with EKS. In other words, the following assumes that an EKS cluster with App Mesh configured is available and the prerequisites (`aws`, `kubectl`, `jq`, etc. installed) are met.

First, attach the IAM policy `arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess` to the EC2 auto-scaling group of your EKS cluster as. To attach the IAM policy via the command line, use:

```
$ INSTANCE_PROFILE_PREFIX=$(aws cloudformation describe-stacks | jq -r '.Stacks[].StackName' | grep eksctl-appmeshtest-nodegroup-ng)
$ INSTANCE_PROFILE_NAME=$(aws iam list-instance-profiles | jq -r '.InstanceProfiles[].InstanceProfileName' | grep $INSTANCE_PROFILE_PREFIX)
$ ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME | jq -r '.InstanceProfile.Roles[] | .RoleName')
$ aws iam attach-role-policy \
      --role-name $ROLE_NAME \
      --policy arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess
```

The X-Ray daemon is automatically injected by [App Mesh Inject](https://github.com/awslabs/aws-app-mesh-inject) into your app container, just like Envoy is. See with:

```
$ kubectl -n appmesh-demo \
          get pods
```