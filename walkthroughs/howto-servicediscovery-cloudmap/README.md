# Introducing Cloud Map support for AWS App Mesh

## Overview

This is a demo of using Cloud Map for service discovery in App Mesh.

## Prerequisites

1. You have version 1.16.124 or higher of the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) installed.
2. You have cloned the [github.com/aws/aws-app-mesh-examples](https://github.com/aws/aws-app-mesh-examples) repo and changed directory to the project root.

## Environment

Set or export the following environment variables with appropriate values for your account, etc.

```bash
# Your AWS account ID
export AWS_ACCOUNT_ID=999999999999

# The AWS region you want to use
export AWS_DEFAULT_REGION=us-west-2

# The prefix to use for all the resources we create
export RESOURCE_PREFIX=demo
```

## Publish application container images to ECR

Run `walkthroughs/howto-servicediscovery-cloudmap/deploy-images.sh`

## Run the Demo

Once your environment is ready, run `walkthroughs/howto-servicediscovery-cloudmap/deploy.sh`

```bash
$ walkthroughs/howto-servicediscovery-cloudmap/deploy.sh
deploy vpc...
Waiting for changeset to be created..
No changes to deploy. Stack demo-vpc is up to date
deploy mesh...
Waiting for changeset to be created..
No changes to deploy. Stack demo-mesh is up to date
deploy app...
Waiting for changeset to be created..
Waiting for stack create/update to complete
Successfully created/updated stack - demo
http://demo-Public-1G1K8NGKE7VH6-369254194.us-west-1.elb.amazonaws.com
```

Save the endpoint in a variable and curl it to see responses:

```bash
app=http://demo-Public-1G1K8NGKE7VH6-369254194.us-west-1.elb.amazonaws.com
curl $app/color
```
