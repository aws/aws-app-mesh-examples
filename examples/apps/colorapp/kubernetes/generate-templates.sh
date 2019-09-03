#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

cat << CONFIG_EOF > "${DIR}/colorapp.yaml"
apiVersion: v1
kind: Service
metadata:
  name: colorgateway
  labels:
    app: colorgateway
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: colorgateway
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: colorgateway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: colorgateway
      version: v1
  template:
    metadata:
      labels:
        app: colorgateway
        version: v1
    spec:
      containers:
        - name: colorgateway
          image: "${COLOR_GATEWAY_IMAGE}"
          ports:
            - containerPort: 9080
          env:
            - name: "SERVER_PORT"
              value: "9080"
            - name: "COLOR_TELLER_ENDPOINT"
              value: "colorteller.${SERVICES_DOMAIN}:9080"
            - name: "TCP_ECHO_ENDPOINT"
              value: "tcpecho.${SERVICES_DOMAIN}:2701"
        - name: envoy
          image: "${ENVOY_IMAGE}"
          securityContext:
            runAsUser: 1337
          env:
            - name: "APPMESH_VIRTUAL_NODE_NAME"
              value: "mesh/${MESH_NAME}/virtualNode/colorgateway-vn"
            - name: "ENVOY_LOG_LEVEL"
              value: "debug"
            - name: "AWS_REGION"
              value: "${AWS_DEFAULT_REGION}"
      initContainers:
        - name: proxyinit
          image: 111345817488.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/aws-appmesh-proxy-route-manager:v2
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
          env:
            - name: "APPMESH_START_ENABLED"
              value: "1"
            - name: "APPMESH_IGNORE_UID"
              value: "1337"
            - name: "APPMESH_ENVOY_INGRESS_PORT"
              value: "15000"
            - name: "APPMESH_ENVOY_EGRESS_PORT"
              value: "15001"
            - name: "APPMESH_APP_PORTS"
              value: "9080"
            - name: "APPMESH_EGRESS_IGNORED_IP"
              value: "169.254.169.254"
---

apiVersion: v1
kind: Service
metadata:
  name: colorteller
  labels:
    app: colorteller
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: colorteller
    version: white
---

# white
apiVersion: apps/v1
kind: Deployment
metadata:
  name: colorteller-white
spec:
  replicas: 1
  selector:
    matchLabels:
      app: colorteller
      version: white
  template:
    metadata:
      labels:
        app: colorteller
        version: white
    spec:
      containers:
        - name: colorteller
          image: ${COLOR_TELLER_IMAGE}
          ports:
            - containerPort: 9080
          env:
            - name: "SERVER_PORT"
              value: "9080"
            - name: "COLOR"
              value: "white"
        - name: envoy
          image: ${ENVOY_IMAGE}
          securityContext:
            runAsUser: 1337
          env:
            - name: "APPMESH_VIRTUAL_NODE_NAME"
              value: "mesh/${MESH_NAME}/virtualNode/colorteller-white-vn"
            - name: "ENVOY_LOG_LEVEL"
              value: "debug"
            - name: "AWS_REGION"
              value: ${AWS_DEFAULT_REGION}
      initContainers:
        - name: proxyinit
          image: 111345817488.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/aws-appmesh-proxy-route-manager:v2
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
          env:
            - name: "APPMESH_START_ENABLED"
              value: "1"
            - name: "APPMESH_IGNORE_UID"
              value: "1337"
            - name: "APPMESH_ENVOY_INGRESS_PORT"
              value: "15000"
            - name: "APPMESH_ENVOY_EGRESS_PORT"
              value: "15001"
            - name: "APPMESH_APP_PORTS"
              value: "9080"
            - name: "APPMESH_EGRESS_IGNORED_IP"
              value: "169.254.169.254"
---


# black
apiVersion: v1
kind: Service
metadata:
  name: colorteller-black
  labels:
    app: colorteller
    version: black
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: colorteller
    version: black
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: colorteller-black
spec:
  replicas: 1
  selector:
    matchLabels:
      app: colorteller
      version: black
  template:
    metadata:
      labels:
        app: colorteller
        version: black
    spec:
      containers:
        - name: colorteller
          image: ${COLOR_TELLER_IMAGE}
          ports:
            - containerPort: 9080
          env:
            - name: "SERVER_PORT"
              value: "9080"
            - name: "COLOR"
              value: "black"
        - name: envoy
          image: ${ENVOY_IMAGE}
          securityContext:
            runAsUser: 1337
          env:
            - name: "APPMESH_VIRTUAL_NODE_NAME"
              value: "mesh/${MESH_NAME}/virtualNode/colorteller-black-vn"
            - name: "ENVOY_LOG_LEVEL"
              value: "debug"
            - name: "AWS_REGION"
              value: ${AWS_DEFAULT_REGION}
      initContainers:
        - name: proxyinit
          image: 111345817488.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/aws-appmesh-proxy-route-manager:v2
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
          env:
            - name: "APPMESH_START_ENABLED"
              value: "1"
            - name: "APPMESH_IGNORE_UID"
              value: "1337"
            - name: "APPMESH_ENVOY_INGRESS_PORT"
              value: "15000"
            - name: "APPMESH_ENVOY_EGRESS_PORT"
              value: "15001"
            - name: "APPMESH_APP_PORTS"
              value: "9080"
            - name: "APPMESH_EGRESS_IGNORED_IP"
              value: "169.254.169.254"
---

# blue
apiVersion: v1
kind: Service
metadata:
  name: colorteller-blue
  labels:
    app: colorteller
    version: blue
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: colorteller
    version: blue
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: colorteller-blue
spec:
  replicas: 1
  selector:
    matchLabels:
      app: colorteller
      version: blue
  template:
    metadata:
      labels:
        app: colorteller
        version: blue
    spec:
      containers:
        - name: colorteller
          image: ${COLOR_TELLER_IMAGE}
          ports:
            - containerPort: 9080
          env:
            - name: "SERVER_PORT"
              value: "9080"
            - name: "COLOR"
              value: "blue"
        - name: envoy
          image: ${ENVOY_IMAGE}
          securityContext:
            runAsUser: 1337
          env:
            - name: "APPMESH_VIRTUAL_NODE_NAME"
              value: "mesh/${MESH_NAME}/virtualNode/colorteller-blue-vn"
            - name: "ENVOY_LOG_LEVEL"
              value: "debug"
            - name: "AWS_REGION"
              value: ${AWS_DEFAULT_REGION}
      initContainers:
        - name: proxyinit
          image: 111345817488.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/aws-appmesh-proxy-route-manager:v2
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
          env:
            - name: "APPMESH_START_ENABLED"
              value: "1"
            - name: "APPMESH_IGNORE_UID"
              value: "1337"
            - name: "APPMESH_ENVOY_INGRESS_PORT"
              value: "15000"
            - name: "APPMESH_ENVOY_EGRESS_PORT"
              value: "15001"
            - name: "APPMESH_APP_PORTS"
              value: "9080"
            - name: "APPMESH_EGRESS_IGNORED_IP"
              value: "169.254.169.254"
---

# red
apiVersion: v1
kind: Service
metadata:
  name: colorteller-red
  labels:
    app: colorteller
    version: red
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: colorteller
    version: red
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: colorteller-red
spec:
  replicas: 1
  selector:
    matchLabels:
      app: colorteller
      version: red
  template:
    metadata:
      labels:
        app: colorteller
        version: red
    spec:
      containers:
        - name: colorteller
          image: ${COLOR_TELLER_IMAGE}
          ports:
            - containerPort: 9080
          env:
            - name: "SERVER_PORT"
              value: "9080"
            - name: "COLOR"
              value: "red"
        - name: envoy
          image: ${ENVOY_IMAGE}
          securityContext:
            runAsUser: 1337
          env:
            - name: "APPMESH_VIRTUAL_NODE_NAME"
              value: "mesh/${MESH_NAME}/virtualNode/colorteller-red-vn"
            - name: "ENVOY_LOG_LEVEL"
              value: "debug"
            - name: "AWS_REGION"
              value: ${AWS_DEFAULT_REGION}
      initContainers:
        - name: proxyinit
          image: 111345817488.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/aws-appmesh-proxy-route-manager:v2
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
          env:
            - name: "APPMESH_START_ENABLED"
              value: "1"
            - name: "APPMESH_IGNORE_UID"
              value: "1337"
            - name: "APPMESH_ENVOY_INGRESS_PORT"
              value: "15000"
            - name: "APPMESH_ENVOY_EGRESS_PORT"
              value: "15001"
            - name: "APPMESH_APP_PORTS"
              value: "9080"
            - name: "APPMESH_EGRESS_IGNORED_IP"
              value: "169.254.169.254"
---

# tester-app
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tester-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tester-app
  template:
    metadata:
      labels:
        app: tester-app
    spec:
      containers:
        - name: tester-app
          image: "tstrohmeier/alpine-infinite-curl"
          env:
            - name: "HOST"
              value: "http://colorgateway.${SERVICES_DOMAIN}:9080/color"
---

# tcpecho
apiVersion: v1
kind: Service
metadata:
  name: tcpecho
  labels:
    app: tcpecho
spec:
  ports:
  - port: 2701
    name: tcpecho
  selector:
    app: tcpecho
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tcpecho
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tcpecho
      version: v1
  template:
    metadata:
      labels:
        app: tcpecho
        version: v1
    spec:
      containers:
        - name: tcpecho
          image: cjimti/go-echo
          ports:
            - containerPort: 2701
          env:
            - name: "TCP_PORT"
              value: "2701"
            - name: "NODE_NAME"
              value: "mesh/${MESH_NAME}/virtualNode/tcpecho-vn"
---
CONFIG_EOF