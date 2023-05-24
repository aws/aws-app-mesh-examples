# App Mesh Envoy Sidecar Customization

## Prerequisites
[Base deployment](base.md)  
[Ready to modify color app manifest](https://github.com/aws/aws-app-mesh-examples/tree/main/examples/apps/colorapp/kubernetes) (we choose howto-k8s-http2 as an example here)

## volumeMounts
volumeMounts can be used to inject configuration files or certificates directly into the Envoy container. This enables customizing the behavior of the Envoy proxy.

### Use Cases:
Custom Envoy Configuration: You can create a ConfigMap that contains your custom Envoy configuration and mount it into the Envoy container. This allows you to customize the behavior of the Envoy proxy according to your specific needs.

TLS Certificates: If your Envoy proxy needs to establish secure communication channels, you might need to provide it with TLS certificates. You can store these certificates in a ConfigMap or on the host system and mount them into the Envoy sidecar.

### Configuration:
#### Way1: ConfigMap  
1. Create a customized ConfigMap in either the main manifest or separate manifest
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: howto-k8s-http2
data:
  app.properties: |-
    key1=value1
    key2=value2
    key3=value3
```
2. Add a volumes section under the spec section of the template
3. Set annotation for the volume mount to envoy sidecar containers (remember need to set for all pods which has envoy sidecar containers)
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blue
  namespace: howto-k8s-http2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: color
      version: blue
  template:
    metadata:
      labels:
        app: color
        version: blue
      annotations:
        appmesh.k8s.aws/mesh: howto-k8s-http2
        appmesh.k8s.aws/volumeMounts: app-config:/tmp/app-config
    spec:
      containers:
        - name: app
          image: 653561076409.dkr.ecr.us-west-2.amazonaws.com/howto-k8s-http2/color_server
          ports:
            - containerPort: 8080
          env:
            - name: "COLOR"
              value: "blue"
            - name: "PORT"
              value: "8080"
      volumes:
        - name: app-config
          configMap:
            name: app-config
``` 

#### Way2: HostPath
1. Create a directory on the host system that contains the configuration files you want to inject into the Envoy container.
2. Add a volumes section under the spec section of the template
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: green
  namespace: howto-k8s-http2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: color
      version: green
  template:
    metadata:
      labels:
        app: color
        version: green
      annotations:
        appmesh.k8s.aws/mesh: howto-k8s-http2
        appmesh.k8s.aws/sidecarEnv: "ENV1=env1Value"
        appmesh.k8s.aws/volumeMounts: test:/tmp/test
    spec:
      containers:
        - name: app
          image: 653561076409.dkr.ecr.us-west-2.amazonaws.com/howto-k8s-http2/color_server
          ports:
            - containerPort: 8080
          env:
            - name: "COLOR"
              value: "green"
            - name: "PORT"
              value: "8080"
      volumes:
        - name: test
          hostPath:
            path: /tmp/mountTest/test
```

### Verification:
After [deployment](https://github.com/aws/aws-app-mesh-examples/tree/main/walkthroughs/howto-k8s-http2#setup), describe the specific pod to check the volume mount setting.  
Get the pod name you want to describe:  
`kubectl get pods --all-namespaces`    
Describe the pod:  
`kubectl describe pods <select-pod-name> -n howto-k8s-http2`  
Could also get into the container to verify the mounted files:  
`kubectl exec -it <select-pod-name> -n howto-k8s-http2 -c envoy -- sh`  
Under Containers/envoy/Mounts you should see the mounted files:  
```
Mounts:
      /tmp/app-config from app-config (ro)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-q9csb (ro)
```
Also within Volumes section:
```
Volumes:
  app-config:
    Type:      ConfigMap (a volume populated by a ConfigMap)
    Name:      app-config
    Optional:  false
```

## sidecarEnv
sidecarEnv is a configuration option that allows you to set environment variables in the sidecar container. This can be particularly useful in scenarios where you want to influence Envoy's behavior or provide it with specific information about its running environment.

### Use Cases:
A common use case for sidecarEnv with Envoy is to set specific environment variables that Envoy reads on startup to configure its behavior. These could be settings for logging levels, tracing configurations, or other operational parameters.

### Configuration:
1. Add a sidecarEnv section under the spec section of the template
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: green
  namespace: howto-k8s-http2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: color
      version: green
  template:
    metadata:
      labels:
        app: color
        version: green
      annotations:
        appmesh.k8s.aws/mesh: howto-k8s-http2
        appmesh.k8s.aws/sidecarEnv: "ENV1=env1Value, ENV2=env2Value"
```

### Verification:
Again, describe the pod and check the sidecarEnv setting.
`kubectl describe pods <select-pod-name> -n howto-k8s-http2`  
Under Containers/envoy/Environment you should see system variables and your customized variables:  
```
Environment:
      APPMESH_PLATFORM_K8S_VERSION:                  v1.24.13-eks-0a21954
      ENV1:                                          env1Value
      ENV2:                                          env2Value
      APPMESH_VIRTUAL_NODE_NAME:                     mesh/howto-k8s-http2/virtualNode/green_howto-k8s-http2
      AWS_REGION:                                    us-west-2
      APPMESH_DUALSTACK_ENDPOINT:                    0
      APPMESH_PREVIEW:                               0
      ENVOY_ADMIN_ACCESS_PORT:                       9901
      APPMESH_FIPS_ENDPOINT:                         0
      APPNET_AGENT_ADMIN_MODE:                       uds
      APPNET_AGENT_ADMIN_UDS_PATH:                   /tmp/agent.sock
      ENVOY_ADMIN_ACCESS_ENABLE_IPV6:                false
      ENVOY_LOG_LEVEL:                               info
      ENVOY_ADMIN_ACCESS_LOG_FILE:                   /tmp/envoy_admin_access.log
      APPMESH_PLATFORM_APP_MESH_CONTROLLER_VERSION:  v1.11.0-dirty
      APPMESH_PLATFORM_K8S_POD_UID:                   (v1:metadata.uid)
```

