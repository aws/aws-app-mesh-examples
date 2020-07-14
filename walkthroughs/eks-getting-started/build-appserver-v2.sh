#!/bin/bash

# Build docker image
APPSERVER_ECR_REPO=$(jq < cfn-output.json -r '.AppServerEcrRepo');
docker build -t $APPSERVER_ECR_REPO ./yelb-appserver-v2/

# Push image to ECR repo
$(aws ecr get-login --no-include-email)
docker push  $APPSERVER_ECR_REPO:latest

# Generate Kubernetes deployment file
cat > ./infrastructure/yelb_appserver_v2_deployment.yaml <<-EOF
apiVersion: v1
kind: Service
metadata:
  namespace: yelb
  name: yelb-appserver-v2
  labels:
    app: yelb-appserver-v2
    tier: middletier
spec:
  type: ClusterIP
  ports:
    - port: 4567
  selector:
    app: yelb-appserver-v2
    tier: middletier
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: yelb
  name: yelb-appserver-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: yelb-appserver-v2
      tier: middletier
  template:
    metadata:
      labels:
        app: yelb-appserver-v2
        tier: middletier
    spec:
      containers:
        - name: yelb-appserver-v2
          image: $APPSERVER_ECR_REPO:latest
          ports:
            - containerPort: 4567
EOF