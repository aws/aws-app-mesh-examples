## Overview
In this walk through, we'll enable mTLS between two applications in App Mesh using Envoy's Secret Discovery Service(SDS). SDS allows envoy to fetch certificates from a remote SDS Server. When SDS is enabled and configured in Envoy, it will fetch the certificates from a central SDS server. SDS server will automatically renew the certs when they are about to expire and will push them to respective envoys. This greatly simplifies the certificate management process for individual services/apps and is more secure when compared to file based certs as the certs are no longer stored on the disk. If the envoy fails to fetch a certificate from the SDS server for any reason, the listener will be marked as active and the port will be open but the connection to the port will be reset. 

Please refer to https://www.envoyproxy.io/docs/envoy/latest/configuration/security/secret for more details on Envoy's Secret Discovery Service.

SPIRE will be used as SDS provider in this walk through and will be the only SDS provider option supported in the Preview release. SPIRE is an Identity Management platform which at its heart is a tool chain that automatically issues and rotates authorized SVIDs (SPIFFE Verifiable Identity Document). A SPIRE Agent will run on each of the nodes on the cluster and will expose a Workload API via a Unix Domain Socket. All the envoys on a particular node will reach out to the local SPIRE Agent over UDS. Please refer to https://spiffe.io/docs/latest/spire/understand/ for more details.

In App Mesh, traffic encryption works between Virtual Nodes, and thus between Envoys in your service mesh. This means your application code is not responsible for negotiating a TLS-encrypted session, instead allowing the local proxy(envoy) to negotiate and terminate TLS on your application's behalf. We will be configuring an SDS cluster in Envoy to obtain certificates from the SDS provider (i.e.,) SPIRE.

## Prerequisites

This feature is currently only available in [App Mesh preview](https://docs.aws.amazon.com/app-mesh/latest/userguide/preview.html) and will work with App Mesh controller [here](https://github.com/aws/eks-charts/tree/preview/stable/appmesh-controller). App Mesh preview is only provided in the `us-west-2` region.

1. [Walkthrough: App Mesh with EKS](../eks/)
2. Run the following to check the version of controller you are running.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1

v1.2.0-preview
```
3. [Setup](https://docs.aws.amazon.com/app-mesh/latest/userguide/preview.html) AWS CLI to use preview channel
```
curl https://raw.githubusercontent.com/aws/aws-app-mesh-roadmap/master/appmesh-preview/service-model.json \
        -o $HOME/appmesh-preview-model.json
aws configure add-model \
    --service-name appmesh-preview \
    --service-model file://$HOME/appmesh-preview-model.json
```

4. Install Docker. `deploy.sh` script builds the demo application images using Docker CLI.

## Step 1: Setup environment
1. Clone this repository and navigate to the walkthrough/howto-k8s-mtls-sds-based folder, all commands will be ran from this location
2. Your AWS account id:

    export AWS_ACCOUNT_ID=<your_account_id>

3. Region e.g. us-west-2

    export AWS_DEFAULT_REGION=us-west-2

4. ENVOY_IMAGE environment variable is set to App Mesh Envoy, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html

    export ENVOY_IMAGE=...


## Step 2: SPIRE Installation

**Option 1: Quick setup**

Walk through provides a quick and simple way to install and configure both SPIRE Server and Agent. If you don't have SPIRE Server and Agent(s) already running on your cluster, you can execute the below SPIRE installation script. It will install and configure SPIRE Server and Agent(s) with the trust domain of this walkthrough (howto-k8s-mtls-sds-based.com). SPIRE Server will be installed as a Stateful set and SPIRE Agent will be installed as a Daemonset (under namespace `spire`). SPIRE Agent is configured with a 'trust_bundle_path' pointing to SPIRE Server's CA bundle.

Walk through uses built-in k8s node attestor(k8s_sat) and workload attestor(k8s) plugins. You can use "aws_iid" as a Node attestor plugin if you wish to attest an Agent's identity using an AWS Instance Identity Document. Please refer to https://github.com/spiffe/spire/blob/master/doc/spire_agent.md#built-in-plugins for list of available built-in plugins.

```bash
./deploy_spire.sh
```

Let's check if both SPIRE Server and Agent are up and running. You should see a SPIRE Agent up and running on every node on your cluster.

```
kubectl get all -n spire
NAME                    READY   STATUS    RESTARTS   AGE
pod/spire-agent-npqbf   1/1     Running   0          7m38s
pod/spire-agent-qztbq   1/1     Running   0          7m38s
pod/spire-agent-rwqdn   1/1     Running   0          7m38s
pod/spire-agent-sxgfr   1/1     Running   0          7m38s
pod/spire-server-0      1/1     Running   0          7m38s

```

**SPIRE Observability:** SPIRE supports metrics collection via most of the common metrics collectors (i.e.,) Prometheus, StatsD, DogStatsd etc. You can configure them via configuring "telemetry" section in the SPIRE config. Please refer to https://spiffe.io/docs/latest/spire/using/telemetry_config/ for more details.

**Option 2: Working with existing SPIRE installation on your cluster**

If you prefer to instead work with an existing SPIRE installation, you would need to modify the trust domain that is configured on your cluster to the one used by this walkthrough (howto-k8s-mtls-sds-based.com). Update the 'trust_domain' field in your SPIRE Server and Agent configs (kubectl edit - server/agent configmaps) and apply the changes. Also, update the "server_address", "server_port" and "trust_bundle_path" in the Server/Agent ConfigMaps to match with your environment.

## Step 3: Register Node and Workload entries with SPIRE Server

Once we have SPIRE Server and Agent(s) up and running, we need to register Node and Workload entries with SPIRE Server. SPIRE Server will share the list of all the registered entries with individual SPIRE agents. SPIRE Agents will cache these entries locally. When a Workload/Pod reaches out to the local SPIRE Agent via the Workload API that it exposes, SPIRE Agent will collect info about that pod and compares it against the registered entries to determine the SVID they need to issue for this particular pod.

Please refer to https://spiffe.io/docs/latest/spire/using/registering/ for more details

Let's go ahead and register the entries with SPIRE server.

```bash
./spire/register_server_entries.sh register
```

You should now be able to check the registered entries in the SPIRE Server

```bash
kubectl exec -n spire spire-server-0 -- /opt/spire/bin/spire-server entry show

Found 4 entries
Entry ID      : a036533e-b911-452d-9b72-c0689b715e04
SPIFFE ID     : spiffe://howto-k8s-mtls-sds-based.com/colorblue
Parent ID     : spiffe://howto-k8s-mtls-sds-based.com/ns/spire/sa/spire-agent
TTL           : 3600
Selector      : k8s:container-name:envoy
Selector      : k8s:ns:howto-k8s-mtls-sds-based
Selector      : k8s:pod-label:app:color
Selector      : k8s:pod-label:version:blue
Selector      : k8s:sa:default

Entry ID      : 38aaae74-b90a-486b-b0a5-d4b811562dc2
SPIFFE ID     : spiffe://howto-k8s-mtls-sds-based.com/colorred
Parent ID     : spiffe://howto-k8s-mtls-sds-based.com/ns/spire/sa/spire-agent
TTL           : 3600
Selector      : k8s:container-name:envoy
Selector      : k8s:ns:howto-k8s-mtls-sds-based
Selector      : k8s:pod-label:app:color
Selector      : k8s:pod-label:version:red
Selector      : k8s:sa:default

Entry ID      : 23489df4-5aff-4661-bfc2-ec19dd20e469
SPIFFE ID     : spiffe://howto-k8s-mtls-sds-based.com/front
Parent ID     : spiffe://howto-k8s-mtls-sds-based.com/ns/spire/sa/spire-agent
TTL           : 3600
Selector      : k8s:container-name:envoy
Selector      : k8s:ns:howto-k8s-mtls-sds-based
Selector      : k8s:pod-label:app:front
Selector      : k8s:sa:default

Entry ID      : d65777e1-4f48-43af-b5e5-089def4e7f90
SPIFFE ID     : spiffe://howto-k8s-mtls-sds-based.com/ns/spire/sa/spire-agent
Parent ID     : spiffe://howto-k8s-mtls-sds-based.com/spire/server
TTL           : 3600
Selector      : k8s_sat:agent_ns:spire
Selector      : k8s_sat:agent_sa:spire-agent
Selector      : k8s_sat:cluster:demo-cluster

```

So, for example a K8S Pod running in namespace 'howto-k8s-mtls-sds-based' with 'default' ServiceAccount and with a pod label 'app:front' will receive  "spiffe://howto-k8s-mtls-sds-based.com/front" as SPIFFE ID. If it doesn't find a match with any of the registered entries then it will not issue an SVID for that workload/pod. We set a default TTL value of "3600" in this walk through, so the certs are automatically renewed every 1 hr. If you wish to change this, you can modify "default_svid_ttl" value in SPIRE Server's ConfigMap. Also, as we can see from the output above, we didn't register an entry to match on the `green` app. We will use this to illustrate how SPIRE vends out identities as well as to show how mTLS communication fails between `front` and `green` without valid certs on both ends.
                                                                                                                                       
## Step 4: Create a Mesh with mTLS enabled

We are going to setup a mesh with four virtual nodes: Frontend, Blue, Green and Red, one virtual service: color and one virtual router: color.

Let's create the App Mesh resources and corresponding app deployments.

```bash
./deploy_app.sh
```

Frontend has backend virtual service (color) configured and the virtual service (color) uses virtual router (color) as the provider. The virtual router (color) has three routes configured:
- color-route-blue: matches on HTTP header "blue" to route traffic to virtual node `blue`
- color-route-green: matches on HTTP header "green" to route traffic to virtual node `green` 
- color-route-red: matches on HTTP header "red" to route traffic to virtual node `red`

mTLS is enabled for all Virtual nodes in their respective listeners and backends. We use Mesh name(howto-k8s-mtls-sds-based) as the trust domain for this walk through. 

Verify all the resources are up and running.

```bash
kubectl get all -n howto-k8s-mtls-sds-based
NAME                         READY   STATUS    RESTARTS   AGE
pod/blue-5ff858765d-rd4rx    2/2     Running   0          2m
pod/front-5f8757d4c-6nmj9    2/2     Running   0          2m
pod/green-7d6c78dfd8-tqrqz   2/2     Running   0          2m
pod/red-64c8887c8d-ccnr4     2/2     Running   0          2m

NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/color         ClusterIP   10.100.158.92    <none>        8080/TCP   2m
service/color-blue    ClusterIP   10.100.65.11     <none>        8080/TCP   2m
service/color-green   ClusterIP   10.100.91.203    <none>        8080/TCP   2m
service/color-red     ClusterIP   10.100.130.238   <none>        8080/TCP   2m
service/front         ClusterIP   10.100.56.110    <none>        8080/TCP   2m

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/blue    1/1     1            1           2m
deployment.apps/front   1/1     1            1           2m
deployment.apps/green   1/1     1            1           2m
deployment.apps/red     1/1     1            1           2m

NAME                               DESIRED   CURRENT   READY   AGE
replicaset.apps/blue-5ff858765d    1         1         1       2m
replicaset.apps/front-5f8757d4c    1         1         1       2m
replicaset.apps/green-7d6c78dfd8   1         1         1       2m
replicaset.apps/red-64c8887c8d     1         1         1       2m

NAME                                  ARN                                                                                                                         AGE
virtualrouter.appmesh.k8s.aws/color   arn:aws:appmesh-preview:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualRouter/color_howto-k8s-mtls-sds-based   2m

NAME                                   ARN                                                                                                                                            AGE
virtualservice.appmesh.k8s.aws/color   arn:aws:appmesh-preview:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualService/color.howto-k8s-mtls-sds-based.svc.cluster.local   2m

NAME                                ARN                                                                                                                       AGE
virtualnode.appmesh.k8s.aws/blue    arn:aws:appmesh-preview:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualNode/blue_howto-k8s-mtls-sds-based    2m
virtualnode.appmesh.k8s.aws/front   arn:aws:appmesh-preview:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualNode/front_howto-k8s-mtls-sds-based   2m
virtualnode.appmesh.k8s.aws/green   arn:aws:appmesh-preview:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualNode/green_howto-k8s-mtls-sds-based   2m
virtualnode.appmesh.k8s.aws/red     arn:aws:appmesh-preview:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualNode/red_howto-k8s-mtls-sds-based     2m

Note: "1111111111" is a dummy Account ID. You should see your Accoount ID in place of "1111111111"
```

Let's look at the spec for `front` Virtual Node that has `green`, `red` and `blue` as it's backends. In order to enable mTLS, we need to specify both the `certificate` and `validation` sections of the `tls` block. The `certificate` block under `tls` specifies the SDS secret name(SPIFFE ID that was assigned for this workload) of the `front` app and the `validation` block specifies trust domain that it is part of. TLS `mode` is set to `STRICT` which will only allow mTLS traffic. `mode` can be set to `PERMISSIVE` if you wish to allow both plaintext traffic and mutual mTLS traffic at the same time. Use `subjectAlternativeNames` section to list out any alternative names for the services.

```
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: front
  namespace: howto-k8s-mtls-sds-based
spec:
  podSelector:
    matchLabels:
      app: front
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      healthCheck:
        protocol: http
        path: '/ping'
        healthyThreshold: 2
        unhealthyThreshold: 2
        timeoutMillis: 2000
        intervalMillis: 5000
  backends:
    - virtualService:
        virtualServiceRef:
          name: color
  backendDefaults:
    clientPolicy:
      tls:
        enforce: true
        mode: STRICT
        certificate:
          sds:
            secretName: spiffe://howto-k8s-mtls-sds-based.com/front
        validation:
          trust:
            sds:
              secretName: spiffe://howto-k8s-mtls-sds-based.com
          subjectAlternativeNames:
            match:
              exact:
              - spiffe://howto-k8s-mtls-sds-based.com/colorblue
              - spiffe://howto-k8s-mtls-sds-based.com/colorred
              - spiffe://howto-k8s-mtls-sds-based.com/colorgreen
  serviceDiscovery:
    dns:
      hostname: front.howto-k8s-mtls-sds-based.svc.cluster.local
```

Below is the VirtualNode spec for `blue` app which has mTLS enabled for it's listener. Both `certificate` and `validation` sections are specified with respective client cert and trust domain values. `mode` is set to `STRICT` to allow only mTLS traffic.

```
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: blue
  namespace: howto-k8s-mtls-sds-based
spec:
  podSelector:
    matchLabels:
      app: color
      version: blue
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      healthCheck:
        protocol: http
        path: '/ping'
        healthyThreshold: 2
        unhealthyThreshold: 2
        timeoutMillis: 2000
        intervalMillis: 5000
      tls:
        mode: STRICT
        certificate:
          sds:
            secretName: spiffe://howto-k8s-mtls-sds-based.com/colorblue
        validation:
          trust:
            sds:
              secretName: spiffe://howto-k8s-mtls-sds-based.com
          subjectAlternativeNames:
            match:
              exact:
              - spiffe://howto-k8s-mtls-sds-based.com/front
  serviceDiscovery:
    dns:
      hostname: color-blue.howto-k8s-mtls-sds-based.svc.cluster.local
```

Now that we have the Mesh deployed. Let's derive the pod identities which we will use through the rest of the walk through.

```bash
FRONT_POD=$(kubectl get pod -l "app=front" -n howto-k8s-mtls-sds-based --output=jsonpath={.items..metadata.name})
BLUE_POD=$(kubectl get pod -l "version=blue" -n howto-k8s-mtls-sds-based --output=jsonpath={.items..metadata.name})
RED_POD=$(kubectl get pod -l "version=red" -n howto-k8s-mtls-sds-based --output=jsonpath={.items..metadata.name})
GREEN_POD=$(kubectl get pod -l "version=green" -n howto-k8s-mtls-sds-based --output=jsonpath={.items..metadata.name})
```

Let's check if envoy is able to communicate with the SDS cluster and if it is `healthy`

```bash
kubectl exec -it $FRONT_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/clusters | grep -E '(static_cluster_sds.*cx_active|static_cluster_sds.*healthy)'
```

We should see the below output indicating that the SDS cluster is active and healthy

```
static_cluster_sds_unix_socket::/run/spire/sockets/agent.sock::cx_active::1
static_cluster_sds_unix_socket::/run/spire/sockets/agent.sock::health_flags::healthy
``` 

We can now check if Envoy was able to source both the app certs and CA certs from the SDS provider (SPIRE in this example walk through)

```bash
kubectl exec -it $FRONT_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/certs
```

It should output the certs that Envoy currently has and we should see both the app cert and the CA cert.

```
{
 "certificates": [
  {
   "ca_cert": [
    {
     "path": "\u003cinline\u003e",
     "serial_number": "0",
     "subject_alt_names": [
      {
       "uri": "spiffe://howto-k8s-mtls-sds-based.com"
      }
     ],
     "days_until_expiration": "0",
     "valid_from": "2020-11-11T20:49:06Z",
     "expiration_time": "2020-11-12T20:49:16Z"
    }
   ],
   "cert_chain": [
    {
     "path": "\u003cinline\u003e",
     "serial_number": "7b177c736290d0fe5527a7ccf0ecee4c",
     "subject_alt_names": [
      {
       "uri": "spiffe://howto-k8s-mtls-sds-based.com/front"
      }
     ],
     "days_until_expiration": "0",
     "valid_from": "2020-11-11T23:19:45Z",
     "expiration_time": "2020-11-12T00:19:55Z"
    }
   ]
  }
 ]
}
```

We also have health checks enabled for all the Virtualnodes, so we should be able to check if envoy health check is working as expected with mTLS enabled between the individual envoys. We should also see a successful TLS handshake between `front` and the backend VirtualNode envoys (`blue`, `red` and `green`). Since, we didn't register an entry for `green` service with the SPIRE Server, it will not be able to issue an SVID for it. So, we should see a failed health check for `green` and healthy clusters for `red` and `green` backends.

```bash
kubectl exec -it $FRONT_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/clusters | grep -E '((blue|green|red).*health)'

cds_egress_howto-k8s-mtls-sds-based_red_howto-k8s-mtls-sds-based_http_8080::10.100.130.238:8080::health_flags::healthy
cds_egress_howto-k8s-mtls-sds-based_green_howto-k8s-mtls-sds-based_http_8080::10.100.91.203:8080::health_flags::/failed_active_hc
cds_egress_howto-k8s-mtls-sds-based_blue_howto-k8s-mtls-sds-based_http_8080::10.100.65.11:8080::health_flags::healthy
```

We can also verify that SPIRE Agent didn't issue an SVID for `green` app because none of the registered entries match the selectors SPIRE Agent derived for the `green` app during workload attestation.

```bash
kubectl exec -it $GREEN_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/certs
{
 "certificates": []
}
```

Let's now check the TLS handshake stats

```bash
kubectl exec -it $FRONT_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/stats | grep ssl.handshake
```

Output should be as below, which shows a successful TLS handshake with `red` and `blue` backends. We can also see that there was no SSL handshake with the `green` service.

```
cluster.cds_egress_howto-k8s-mtls-sds-based_blue_howto-k8s-mtls-sds-based_http_8080.ssl.handshake: 1
cluster.cds_egress_howto-k8s-mtls-sds-based_green_howto-k8s-mtls-sds-based_http_8080.ssl.handshake: 0
cluster.cds_egress_howto-k8s-mtls-sds-based_red_howto-k8s-mtls-sds-based_http_8080.ssl.handshake: 1
```

Let's also check the TLS handshake stats for the backend listener of the `blue` and `red` backend services

```bash
kubectl exec -it $BLUE_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/stats | grep ssl.handshake

listener.0.0.0.0_15000.ssl.handshake: 1
```

```bash
kubectl exec -it $RED_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/stats | grep ssl.handshake

listener.0.0.0.0_15000.ssl.handshake: 1
```

## Setup 4: Verify traffic with mTLS

Let's start a sample `curler` pod

```bash
kubectl -n default run -it --rm curler --image=tutum/curl /bin/bash
```
Once you're at the prompt, let's try to reach out to `blue` backend
```
curl -H "color_header: blue" front.howto-k8s-mtls-sds-based.svc.cluster.local:8080/; echo;
```

You should see a successful response `blue` when using the HTTP header "color_header: blue"

Let's check the SSL handshake statistics.

```bash
kubectl exec -it $BLUE_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/stats | grep ssl.handshake
```

You should see the listener ssl.handshake count go up by 1 from the previous value, indicating that the above curl triggered a new ssl handshake between `front` and `blue` services.

```
listener.0.0.0.0_15000.ssl.handshake: 2
```

## Setup 4: Verify client policy

Let's try reaching out to `green` service which is missing required certs.

```
curl -H "color_header: green" front.howto-k8s-mtls-sds-based.svc.cluster.local:8080/; echo;
```

You should see that the request fails when you attempt to communicate with `green`.

Now let's register an entry for `green` app with SPIRE server so that it knows the SPIFFE ID that it needs to issue for this workload.

```bash
./spire/register_server_entries.sh registerGreen
```

Let's verify that `green` app is now able to source both app and CA certs from SPIRE agent.
Note: It might take some 15-30 seconds for the `green` app to be able to successfully source certs from SPIRE after registering the entry for `green` app.

```bash
kubectl exec -it $GREEN_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/certs

{
 "certificates": [
  {
   "ca_cert": [
    {
     "path": "\u003cinline\u003e",
     "serial_number": "0",
     "subject_alt_names": [
      {
       "uri": "spiffe://howto-k8s-mtls-sds-based.com"
      }
     ],
     "days_until_expiration": "0",
     "valid_from": "2020-11-12T19:22:40Z",
     "expiration_time": "2020-11-13T19:22:50Z"
    }
   ],
   "cert_chain": [
    {
     "path": "\u003cinline\u003e",
     "serial_number": "b2d629e0f8de238779eff25e5cbaa749",
     "subject_alt_names": [
      {
       "uri": "spiffe://howto-k8s-mtls-sds-based.com/colorgreen"
      }
     ],
     "days_until_expiration": "0",
     "valid_from": "2020-11-12T19:51:23Z",
     "expiration_time": "2020-11-12T20:51:33Z"
    }
   ]
  }
 ]
}

```

Now, we should see a successful SSL handshake between `front` and `green` apps. As a result, `green` backend cluster should now turn healthy in the front app's envoy.

```bash
kubectl exec -it $FRONT_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/clusters | grep green.*healthy

cds_egress_howto-k8s-mtls-sds-based_green_howto-k8s-mtls-sds-based_http_8080::10.100.121.235:8080::health_flags::healthy
```

..and corresponding SSL handshake for the `green` backend cluster

```bash
kubectl exec -it $FRONT_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/stats | grep ssl.handshake | grep green

cluster.cds_egress_howto-k8s-mtls-sds-based_green_howto-k8s-mtls-sds-based_http_8080.ssl.handshake: 1
```

..listener SSL handshake count in the `green` app
```bash
kubectl exec -it $GREEN_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/stats | grep ssl.handshake

listener.0.0.0.0_15000.ssl.handshake: 1
```

Let's attempt to reach `green` app through the `front` app now. Execute the below command from the 'curler' pod we instantiated above

```
curl -H "color_header: green" front.howto-k8s-mtls-sds-based.svc.cluster.local:8080/; echo;
```

You should see a successful response "green" for the above request. 

Let's verify the listener SSL handshake counts on the `green` app. We should see a new SSL handshake between `front` and `green` apps.

```bash
kubectl exec -it $GREEN_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/stats | grep ssl.handshake

listener.0.0.0.0_15000.ssl.handshake: 2
```

## Step 4: mTLS on VirtualGateway

You can configure mTLS (via file or SDS) on a VirtualGateway similar to how we configured mTLS on a VirtualNode in this walk through (i.e.,) configure `certificate` and `validation` sections under `backend` or `backendDefaults` or `listener` sections based on your requirement. For SPIRE to uniquely identify the envoys that are part of a VirtualGateway deployment, you can add a label to the envoy containers and use that as a selector in the SPIRE registration entry.

## Step 5: Cleanup

If you want to keep the application running, you can do so, but this is the end of this walk through. Run the following commands to clean up and tear down the resources that we’ve created.

```bash
./cleanup.sh
```
