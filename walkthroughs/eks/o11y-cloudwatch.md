# App Mesh with EKS—Observability: CloudWatch

NOTE: Before you start with this part, make sure you've gone through the [base deployment](base.md) of App Mesh with EKS. In other words, the following assumes that an EKS cluster with App Mesh configured is available and the prerequisites (`aws`, `kubectl`, `jq`, etc. installed) are met.

First, create an IAM policy as defined in [logs-policy.json](logs-policy.json) and attach it to the EC2 auto-scaling group of your EKS cluster. To attach the IAM logs policy via the command line, use:

```
$ INSTANCE_PROFILE_PREFIX=$(aws cloudformation describe-stacks | jq -r '.Stacks[].StackName' | grep eksctl-appmeshtest-nodegroup-ng)
$ INSTANCE_PROFILE_NAME=$(aws iam list-instance-profiles | jq -r '.InstanceProfiles[].InstanceProfileName' | grep $INSTANCE_PROFILE_PREFIX)
$ ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME | jq -r '.InstanceProfile.Roles[] | .RoleName')
$ aws iam put-role-policy \
      --role-name $ROLE_NAME \
      --policy-name Worker-Logs-Policy \
      --policy-document file://./logs-policy.json
```

Next, deploy Fluentd as a log forwarder using a `DaemonSet` as defined in the [fluentd.yml](fluentd.yml) manifest:

```
$ kubectl apply -f fluentd.yml

# validate that the Fluentd pods are up and running:
$ kubectl -n kube-system get po -l=k8s-app=fluentd-cloudwatch
NAME                       READY   STATUS    RESTARTS   AGE
fluentd-cloudwatch-7ls6g   1/1     Running   0          13m
fluentd-cloudwatch-mdf9z   1/1     Running   0          13m
```

Now it's time to configure the virtual node `colorgateway-appmesh-demo` so it outputs its logs to `stdout`, which is in turn forwarded by Fluentd to CloudWatch. In order to configure the virtual node, use the console to set the log output on virtual node `colorgateway-appmesh-demo`.

First, locate the virtual node `colorgateway-appmesh-demo` in the AppMesh console:

![AppMesh console edit virtual node step 0](appmesh-log-0.png)

Now, expand the 'Additional configuration' section and enter `/dev/stdout` in the 'HTTP access logs path' as shown in the following:

![AppMesh console edit virtual node step 1](appmesh-log-1.png)

When you now go to the CloudWatch console you should see something like this:

![CloudWatch console output of AppMesh virtual node](cloudwatch.png)

