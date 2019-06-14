# Introducing Cloud Map support for AWS App Mesh

## Overview

This is a demo of using Cloud Map for service discovery in App Mesh.

To run this, ensure the following environment variables are set to appropriate
values for your account, etc.

# Your AWS account ID
export AWS_ACCOUNT_ID=999999999999

# The AWS region you want to use
export AWS_DEFAULT_REGION=us-west-1

# The prefix to use for all the resources we create
export RESOURCE_PREFIX=demo

Then run `walkthroughs/howto-servicediscovery-cloudmap/deploy.sh`

```
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

```
$ app=http://demo-Public-1G1K8NGKE7VH6-369254194.us-west-1.elb.amazonaws.com
$ curl $app/color
$ ...
