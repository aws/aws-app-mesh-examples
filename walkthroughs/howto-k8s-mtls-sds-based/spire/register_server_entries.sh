#/bin/bash

set -e

register_server_entries() {
    kubectl exec -n spire spire-server-0 -c spire-server -- /opt/spire/bin/spire-server entry create $@
}


if [ "$1" == "register" ]; then
  echo "Registering an entry for spire agent..."
  register_server_entries \
    -spiffeID spiffe://howto-k8s-mtls-sds-based.aws/ns/spire/sa/spire-agent \
    -selector k8s_sat:cluster:k8s-cluster \
    -selector k8s_sat:agent_ns:spire \
    -selector k8s_sat:agent_sa:spire-agent \
    -node

  echo "Registering an entry for the front app..."
  register_server_entries \
    -parentID spiffe://howto-k8s-mtls-sds-based.aws/ns/spire/sa/spire-agent \
    -spiffeID spiffe://howto-k8s-mtls-sds-based.aws/front \
    -selector k8s:ns:howto-k8s-mtls-sds-based \
    -selector k8s:sa:default \
    -selector k8s:pod-label:app:front \
    -selector k8s:container-name:envoy

  echo "Registering an entry for the color app - version:red..."
  register_server_entries \
    -parentID spiffe://howto-k8s-mtls-sds-based.aws/ns/spire/sa/spire-agent \
    -spiffeID spiffe://howto-k8s-mtls-sds-based.aws/colorred \
    -selector k8s:ns:howto-k8s-mtls-sds-based \
    -selector k8s:sa:default \
    -selector k8s:pod-label:app:color \
    -selector k8s:pod-label:version:red \
    -selector k8s:container-name:envoy

  echo "Registering an entry for the color app - version:blue..."
  register_server_entries \
    -parentID spiffe://howto-k8s-mtls-sds-based.aws/ns/spire/sa/spire-agent \
    -spiffeID spiffe://howto-k8s-mtls-sds-based.aws/colorblue \
    -selector k8s:ns:howto-k8s-mtls-sds-based \
    -selector k8s:sa:default \
    -selector k8s:pod-label:app:color \
    -selector k8s:pod-label:version:blue \
    -selector k8s:container-name:envoy
elif [ "$1" == "registerGreen" ]; then
  echo "Registering an entry for the color app - version:green..."
  register_server_entries \
    -parentID spiffe://howto-k8s-mtls-sds-based.aws/ns/spire/sa/spire-agent \
    -spiffeID spiffe://howto-k8s-mtls-sds-based.aws/colorgreen \
    -selector k8s:ns:howto-k8s-mtls-sds-based \
    -selector k8s:sa:default \
    -selector k8s:pod-label:app:color \
    -selector k8s:pod-label:version:green \
    -selector k8s:container-name:envoy
fi

