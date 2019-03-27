# App Mesh with EKS—Observability: CloudWatch

NOTE: Before you start with this part, make sure you've gone through the [base deployment](base.md) of App Mesh with EKS. In other words, the following assumes that an EKS cluster with App Mesh configured is available.


First, create an IAM policy as shown below and attach it to the EC2 auto-scaling group of your EKS cluster, see also these [notes](https://eksworkshop.com/logging/prereqs/) for further details. Note that it doesn't matter to which node you attach the following policy as it will propagate automatically throughout the auto-scaling group:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
```

Next, deploy Fluentd as a log forwarder using a `DaemonSet` as defined in the [fluentd.yml](fluentd.yml) manifest:

```
$ kubectl apply -f fluentd.yml

# validate if the Fluentd daemon set is up and running:
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

Check by getting the virtual node configuration via the CLI:

```
$ aws appmesh describe-virtual-node \
      --virtual-node-name colorgateway-appmesh-demo \
      --mesh-name color-mesh \
      --region us-east-2
{
    "virtualNode": {
        "status": {
            "status": "ACTIVE"
        },
        "meshName": "color-mesh",
        "virtualNodeName": "colorgateway-appmesh-demo",
        "spec": {
            "serviceDiscovery": {
                "dns": {
                    "hostname": "colorgateway.appmesh-demo.svc.cluster.local"
                }
            },
            "listeners": [
                {
                    "portMapping": {
                        "protocol": "http",
                        "port": 9080
                    }
                }
            ],
            "backends": [
                {
                    "virtualService": {
                        "virtualServiceName": "colorteller.appmesh-demo.svc.cluster.local"
                    }
                }
            ]
        },
        "metadata": {
            "version": 1,
            "lastUpdatedAt": 1553617729.736,
            "createdAt": 1553617729.736,
            "arn": "arn:aws:appmesh:us-east-2:661776721573:mesh/color-mesh/virtualNode/colorgateway-appmesh-demo",
            "uid": "0581b908-5efc-4192-9f44-40cc75d5075e"
        }
    }
}
```

When you now go to the CloudWatch console you should see something like this:

![CloudWatch console output of AppMesh virtual node](cloudwatch.png)

