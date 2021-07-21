#!/usr/bin/env bash
set -e
register_server_entries() {
    kubectl exec -n spire spire-server-0 -c spire-server -- /opt/spire/bin/spire-server entry create $@
}

echo "Registering a node entry for the frontend spire agent..."
register_server_entries \
  -spiffeID spiffe://am-multi-account-mesh/ns/spire/sa/spire-agent-front \
  -selector k8s_psat:cluster:frontend-k8s-cluster \
  -selector k8s_psat:agent_ns:spire \
  -selector k8s_psat:agent_sa:spire-agent-front \
  -node
echo "Registering a node entry for the backend spire agent..."
register_server_entries \
  -spiffeID spiffe://am-multi-account-mesh/ns/spire/sa/spire-agent-back \
  -selector k8s_psat:cluster:backend-k8s-cluster \
  -selector k8s_psat:agent_ns:spire \
  -selector k8s_psat:agent_sa:spire-agent-back \
  -node
echo "Registering a workload entry for the frontend app..."
register_server_entries \
  -parentID spiffe://am-multi-account-mesh/ns/spire/sa/spire-agent-front \
  -spiffeID spiffe://am-multi-account-mesh/frontend \
  -selector k8s:ns:yelb \
  -selector k8s:sa:default \
  -selector k8s:pod-label:app:yelb-ui \
  -selector k8s:pod-label:tier:frontend \
  -selector k8s:container-name:envoy
echo "Registering a workload entry for the redis-server..."
register_server_entries \
  -parentID spiffe://am-multi-account-mesh/ns/spire/sa/spire-agent-back \
  -spiffeID spiffe://am-multi-account-mesh/redis \
  -selector k8s:ns:yelb \
  -selector k8s:sa:default \
  -selector k8s:pod-label:app:redis-server \
  -selector k8s:pod-label:tier:cache \
  -selector k8s:container-name:envoy
echo "Registering a workload entry for the yelb-db..."
register_server_entries \
  -parentID spiffe://am-multi-account-mesh/ns/spire/sa/spire-agent-back \
  -spiffeID spiffe://am-multi-account-mesh/yelbdb \
  -selector k8s:ns:yelb \
  -selector k8s:sa:default \
  -selector k8s:pod-label:app:yelb-db \
  -selector k8s:pod-label:tier:backenddb \
  -selector k8s:container-name:envoy
echo "Registering a workload entry for the yelb-app..."
register_server_entries \
  -parentID spiffe://am-multi-account-mesh/ns/spire/sa/spire-agent-back \
  -spiffeID spiffe://am-multi-account-mesh/yelbapp \
  -selector k8s:ns:yelb \
  -selector k8s:sa:default \
  -selector k8s:pod-label:app:yelb-appserver \
  -selector k8s:pod-label:tier:middletier \
  -selector k8s:container-name:envoy
