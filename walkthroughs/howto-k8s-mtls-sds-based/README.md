## Overview
In this walk through, we'll enable mTLS between two applications in App Mesh using Envoy's Secret Discovery Service(SDS). SDS allows envoy to fetch certificates from a remote SDS Server. When SDS is enabled and configured in Envoy, it will fetch the certificates from a central SDS server. SDS server will automatically renew the certs when they are about to expire and will push them to respective envoys. This greatly simplifies the certificate management process for individual services/apps and is more secure when compared to file based certs as the certs are no longer stored on the disk. If the envoy fails to fetch a certificate from the SDS server for any reason, the listener will be marked as active and the port will be open but the connection to the port will be reset. 

Refer to [Envoy SDS](https://www.envoyproxy.io/docs/envoy/latest/configuration/security/secret) docs for additional details on Envoy's Secret Discovery Service.

SPIRE will be used as SDS provider in this walk through and will be the only SDS provider option supported currently. SPIRE is an Identity Management platform which at its heart is a tool chain that automatically issues and rotates authorized SVIDs (SPIFFE Verifiable Identity Document). A SPIRE Agent will run on each of the nodes on the cluster and will expose a Workload API via a Unix Domain Socket. All the envoys on a particular node will reach out to the local SPIRE Agent over UDS. Please refer [here](https://spiffe.io/docs/latest/spire/understand/) for additional details.

In App Mesh, traffic encryption is enabled between Virtual Nodes and VirtualGateways, and thus between Envoys in your service mesh. This means your application code is not responsible for negotiating a TLS-encrypted session, instead allowing the local proxy(envoy) to negotiate and terminate TLS on your application's behalf. We will be configuring an SDS cluster in Envoy to obtain certificates from the SDS provider (i.e.,) SPIRE.

## Prerequisites

1. [Walkthrough: App Mesh with EKS](../eks/)
2. Run the following to check the version of controller you are running. v1.3.0 is the minimum controller version required for mTLS feature.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'|tail -n1

v1.3.0
```

3. Run the following to check that SDS is enabled.
```
$ kubectl get deployment -n appmesh-system appmesh-controller -o json | jq -r '.spec.template.spec.containers[].args[] | select(contains("enable-sds"))'

--enable-sds=true
```

4. Install Docker. It is needed to build the demo application images.

## Step 1: Setup Environment
1. Clone this repository and navigate to the walkthrough/howto-k8s-mtls-sds-based folder, all commands will be ran from this location
2. Your AWS account id:

    export AWS_ACCOUNT_ID=<your_account_id>

3. Region e.g. us-west-2

    export AWS_DEFAULT_REGION=us-west-2

4. ENVOY_IMAGE environment variable is set to App Mesh Envoy, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html

    export ENVOY_IMAGE=...
    
    **Note:** 1.15.1.0 is the minimum envoy version required for mTLS support using SDS.


## Step 2: SPIRE Installation

**Option 1: Quick setup**

Walk through provides a quick and simple way to install and configure both SPIRE Server and Agent. This installation is purely for demo purposes. If you don't have SPIRE Server and Agent(s) already running on your cluster, you can execute the below SPIRE installation script. It will install and configure SPIRE Server and Agent(s) with the trust domain of this walkthrough (howto-k8s-mtls-sds-based.aws). SPIRE Server will be installed as a Stateful set and SPIRE Agent will be installed as a Daemonset (under namespace `spire`). SPIRE Agent is configured with a 'trust_bundle_path' pointing to SPIRE Server's CA bundle.

Walk through uses built-in k8s node attestor([k8s_sat](https://github.com/spiffe/spire/blob/master/doc/plugin_agent_nodeattestor_k8s_sat.md)) and workload attestor([k8s](https://github.com/spiffe/spire/blob/master/doc/plugin_agent_workloadattestor_k8s.md)) plugins. You can use "[aws_iid](https://github.com/spiffe/spire/blob/master/doc/plugin_server_nodeattestor_aws_iid.md)" as a Node attestor plugin if you wish to attest an Agent's identity using an AWS Instance Identity Document. Check out list of available [built-in plugins](https://github.com/spiffe/spire/blob/master/doc/spire_agent.md#built-in-plugins)

```bash
./deploy_spire.sh
```
**Note:** You can also install sample SPIRE Server and Agent via helm. Please refer to [SPIRE Server](https://github.com/aws/eks-charts/tree/master/stable/appmesh-spire-server) and [SPIRE Agent](https://github.com/aws/eks-charts/tree/master/stable/appmesh-spire-agent) charts in EKS charts repository for instructions on how to install them. If you prefer to install SPIRE via the sample helm charts for this walkthrough then please make sure to set the SPIRE trust domain to `howto-k8s-mtls-sds-based.aws` (--set config.trustDomain=howto-k8s-mtls-sds-based.aws)

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

**Optional**
**SPIRE Observability:** SPIRE supports metrics collection via most of the common metrics collectors (i.e.,) Prometheus, StatsD, DogStatsd etc. You can configure them via configuring "telemetry" section in the SPIRE config. Check [SPIRE telemetry](https://spiffe.io/docs/latest/spire/using/telemetry_config/) for more details.

**Option 2: Working with existing SPIRE installation on your cluster**

If you prefer to instead work with an existing SPIRE installation, you would need to modify the trust domain that is configured on your cluster to the one used by this walkthrough (howto-k8s-mtls-sds-based.aws). Update the 'trust_domain' field in your SPIRE Server and Agent configs (kubectl edit - server/agent configmaps) and apply the changes. Also, update the "server_address", "server_port" and "trust_bundle_path" in the Server/Agent ConfigMaps to match with your environment.

## Step 3: Register Node and Workload entries with SPIRE Server

Once we have SPIRE Server and Agent(s) up and running, we need to register node and workload entries with SPIRE Server. SPIRE Server will share the list of all the registered entries with individual SPIRE agents. SPIRE Agents will cache these entries locally. When a Workload/Pod reaches out to the local SPIRE Agent via the Workload API that it exposes, SPIRE Agent will collect info about that pod/workload and compares it against the registered entries to determine the SVID it needs to issue for this particular pod.

Refer to [SPIRE entry registration](https://spiffe.io/docs/latest/spire/using/registering/) for more details

Let's go ahead and register the entries with SPIRE server.

```bash
./spire/register_server_entries.sh register
```

You should now be able to check the registered entries in the SPIRE Server

```bash
kubectl exec -n spire spire-server-0 -- /opt/spire/bin/spire-server entry show
Found 4 entries
Entry ID      : 20ab95a6-e988-4628-9191-cc7e24acdb84
SPIFFE ID     : spiffe://howto-k8s-mtls-sds-based.aws/colorblue
Parent ID     : spiffe://howto-k8s-mtls-sds-based.aws/ns/spire/sa/spire-agent
TTL           : 3600
Selector      : k8s:container-name:envoy
Selector      : k8s:ns:howto-k8s-mtls-sds-based
Selector      : k8s:pod-label:app:color
Selector      : k8s:pod-label:version:blue
Selector      : k8s:sa:default

Entry ID      : 97ba7159-9e89-48be-9fd1-f7324f6fd81e
SPIFFE ID     : spiffe://howto-k8s-mtls-sds-based.aws/colorred
Parent ID     : spiffe://howto-k8s-mtls-sds-based.aws/ns/spire/sa/spire-agent
TTL           : 3600
Selector      : k8s:container-name:envoy
Selector      : k8s:ns:howto-k8s-mtls-sds-based
Selector      : k8s:pod-label:app:color
Selector      : k8s:pod-label:version:red
Selector      : k8s:sa:default

Entry ID      : f0490524-907d-4a4b-b4e3-8dfc6f4628a9
SPIFFE ID     : spiffe://howto-k8s-mtls-sds-based.aws/front
Parent ID     : spiffe://howto-k8s-mtls-sds-based.aws/ns/spire/sa/spire-agent
TTL           : 3600
Selector      : k8s:container-name:envoy
Selector      : k8s:ns:howto-k8s-mtls-sds-based
Selector      : k8s:pod-label:app:front
Selector      : k8s:sa:default

Entry ID      : f58159ad-0cc4-4856-b122-ddf3f0e0ef9a
SPIFFE ID     : spiffe://howto-k8s-mtls-sds-based.aws/ns/spire/sa/spire-agent
Parent ID     : spiffe://howto-k8s-mtls-sds-based.aws/spire/server
TTL           : 3600
Selector      : k8s_sat:agent_ns:spire
Selector      : k8s_sat:agent_sa:spire-agent
Selector      : k8s_sat:cluster:eks-cluster

```

So, for example a K8S Pod running in namespace 'howto-k8s-mtls-sds-based' with 'default' ServiceAccount and with a pod label 'app:front' will receive  "spiffe://howto-k8s-mtls-sds-based.aws/front" as SPIFFE ID. If it doesn't find a match with any of the registered entries then it will not issue an SVID for that workload/pod. We set a default TTL value of "3600" in this walk through, so the certs are automatically renewed every 1 hr. If you wish to change this, you can modify "default_svid_ttl" value in SPIRE Server's ConfigMap. Also, as we can see from the output above, we didn't register an entry to match on the `green` app. We will use this to illustrate how SPIRE vends out identities as well as to show how mTLS communication fails between `front` and `green` without valid certs on both ends.
                                                                                                                                       
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
virtualrouter.appmesh.k8s.aws/color   arn:aws:appmesh:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualRouter/color_howto-k8s-mtls-sds-based   2m

NAME                                   ARN                                                                                                                                            AGE
virtualservice.appmesh.k8s.aws/color   arn:aws:appmesh:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualService/color.howto-k8s-mtls-sds-based.svc.cluster.local   2m

NAME                                ARN                                                                                                                       AGE
virtualnode.appmesh.k8s.aws/blue    arn:aws:appmesh:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualNode/blue_howto-k8s-mtls-sds-based    2m
virtualnode.appmesh.k8s.aws/front   arn:aws:appmesh:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualNode/front_howto-k8s-mtls-sds-based   2m
virtualnode.appmesh.k8s.aws/green   arn:aws:appmesh:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualNode/green_howto-k8s-mtls-sds-based   2m
virtualnode.appmesh.k8s.aws/red     arn:aws:appmesh:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualNode/red_howto-k8s-mtls-sds-based     2m

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
            secretName: spiffe://howto-k8s-mtls-sds-based.aws/front
        validation:
          trust:
            sds:
              secretName: spiffe://howto-k8s-mtls-sds-based.aws
          subjectAlternativeNames:
            match:
              exact:
              - spiffe://howto-k8s-mtls-sds-based.aws/colorblue
              - spiffe://howto-k8s-mtls-sds-based.aws/colorred
              - spiffe://howto-k8s-mtls-sds-based.aws/colorgreen
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
            secretName: spiffe://howto-k8s-mtls-sds-based.aws/colorblue
        validation:
          trust:
            sds:
              secretName: spiffe://howto-k8s-mtls-sds-based.aws
          subjectAlternativeNames:
            match:
              exact:
              - spiffe://howto-k8s-mtls-sds-based.aws/front
  serviceDiscovery:
    dns:
      hostname: color-blue.howto-k8s-mtls-sds-based.svc.cluster.local
```

We can check VirtualNode info in App Mesh. Let's check blue VirtualNode config with mTLS enabled under listener.

```
aws appmesh describe-virtual-node --virtual-node-name blue_howto-k8s-mtls-sds-based --mesh-name howto-k8s-mtls-sds-based
{
    "virtualNode": {
        "meshName": "howto-k8s-mtls-sds-based",
        "metadata": {
            "arn": "arn:aws:appmesh:us-west-2:1111111111:mesh/howto-k8s-mtls-sds-based/virtualNode/blue_howto-k8s-mtls-sds-based",
            "createdAt": 1606022091.476,
            "lastUpdatedAt": 1606022091.476,
            "meshOwner": "1111111111",
            "resourceOwner": "1111111111",
            "uid": "1783f48d-39fe-4364-adc7-c7d5c1c786b6",
            "version": 1
        },
        "spec": {
            "backends": [],
            "listeners": [
                {
                    "healthCheck": {
                        "healthyThreshold": 2,
                        "intervalMillis": 5000,
                        "path": "/ping",
                        "port": 8080,
                        "protocol": "http",
                        "timeoutMillis": 2000,
                        "unhealthyThreshold": 2
                    },
                    "portMapping": {
                        "port": 8080,
                        "protocol": "http"
                    },
                    "tls": {
                        "certificate": {
                            "sds": {
                                "secretName": "spiffe://howto-k8s-mtls-sds-based.aws/colorblue"
                            }
                        },
                        "mode": "STRICT",
                        "validation": {
                            "subjectAlternativeNames": {
                                "match": {
                                    "exact": [
                                        "spiffe://howto-k8s-mtls-sds-based.aws/front"
                                    ]
                                }
                            },
                            "trust": {
                                "sds": {
                                    "secretName": "spiffe://howto-k8s-mtls-sds-based.aws"
                                }
                            }
                        }
                    }
                }
            ],
            "serviceDiscovery": {
                "dns": {
                    "hostname": "color-blue.howto-k8s-mtls-sds-based.svc.cluster.local"
                }
            }
        },
        "status": {
            "status": "ACTIVE"
        },
        "virtualNodeName": "blue_howto-k8s-mtls-sds-based"
    }
}
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
   "ca_cert": [
    {
     "path": "\u003cinline\u003e",
     "serial_number": "0",
     "subject_alt_names": [
      {
       "uri": "spiffe://howto-k8s-mtls-sds-based.aws"
      }
     ],
     "days_until_expiration": "0",
     "valid_from": "2020-11-22T05:13:03Z",
     "expiration_time": "2020-11-23T05:13:13Z"
    }
   ],
   "cert_chain": [
    {
     "path": "\u003cinline\u003e",
     "serial_number": "47d78411ed47a779ae54d25263671a0c",
     "subject_alt_names": [
      {
       "uri": "spiffe://howto-k8s-mtls-sds-based.aws/front"
      }
     ],
     "days_until_expiration": "0",
     "valid_from": "2020-11-22T05:13:50Z",
     "expiration_time": "2020-11-22T06:14:00Z"
    }
   ]
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

## Step 5: Verify traffic with mTLS

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

## Step 6: Verify client policy

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
       "uri": "spiffe://howto-k8s-mtls-sds-based.aws"
      }
     ],
     "days_until_expiration": "0",
     "valid_from": "2020-11-22T05:13:03Z",
     "expiration_time": "2020-11-23T05:13:13Z"
    }
   ],
   "cert_chain": [
    {
     "path": "\u003cinline\u003e",
     "serial_number": "52f3b82ebb99af2d826bc1c3ac3835ba",
     "subject_alt_names": [
      {
       "uri": "spiffe://howto-k8s-mtls-sds-based.aws/colorgreen"
      }
     ],
     "days_until_expiration": "0",
     "valid_from": "2020-11-22T05:18:29Z",
     "expiration_time": "2020-11-22T06:18:39Z"
    }
   ]
  }
 ]
}

```

Now, we should see a successful SSL handshake between `front` and `green` apps. As a result, `green` backend cluster should now turn healthy in the front app's envoy.

Note: It might take about 15 secs for the cluster to turn healthy.

```bash
kubectl exec -it $FRONT_POD -n howto-k8s-mtls-sds-based -c envoy -- curl http://localhost:9901/clusters | grep green.*health

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

## Step 7: mTLS on VirtualGateway

You can configure mTLS (via file or SDS) on a VirtualGateway similar to how we configured mTLS on a VirtualNode in this walk through (i.e.,) configure `certificate` and `validation` sections under `backend` or `backendDefaults` or `listener` sections based on your requirement. For SPIRE to uniquely identify the envoys that are part of a VirtualGateway deployment, you can add a label to the envoy containers and use that as a selector in the SPIRE registration entry.

## Step 8: Cleanup

If you want to keep the application running, you can do so, but this is the end of this walk through. Run the following commands to clean up and tear down the resources that we’ve created.

```bash
./cleanup.sh
```
