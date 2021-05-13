# App Mesh SPIRE Agent for multi-account mTLS trust domain 

## Install App Mesh SPIRE Agent:

```sh
helm install appmesh-spire-agent eks-multi-account-spire/appmesh-spire-agent \
  --namespace spire \
  --set serviceAccount.name=spire-agent-front \
  --set config.clusterName=frontend-k8s-cluster \
  --set config.trustDomain=am-multi-account-mesh \
  --set config.serverAddress=$(kubectl get pod/spire-server-0 -n spire -o json \
  --context $SHARED_CXT | jq -r '.status.podIP')
```

The [configuration](#configuration) section lists the parameters that can be configured during installation.

## Uninstalling the Chart

To uninstall/delete the `appmesh-spire-agent` deployment:

```console
helm delete appmesh-spire-agent --namespace spire
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following tables lists the configurable parameters of the chart and their default values.

Parameter | Description | Default
--- | --- | ---
`config.clusterName` | cluster name use for k8s_psat node attestation | `k8s-cluster`
`config.trustDomain` | SPIRE Trust Domain | `appmesh.aws`
`config.logLevel` | Log Level | `DEBUG`
`config.serverAddress` | SPIRE Server Address | `spire-server`
`config.serverPort` | SPIRE Server Bind Port | `8081`
`serviceAccount.create` | If `true`, create a new service account | `true`
`serviceAccount.name` | Service account to be used | `spire-agent`
