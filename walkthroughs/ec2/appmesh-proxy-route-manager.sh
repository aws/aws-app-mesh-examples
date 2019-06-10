#!/bin/bash -e

#
# Start of configurable options
#
APPMESH_APP_PORTS="${APPMESH_APP_PORTS:-9080}"
APPMESH_START_ENABLED="${APPMESH_START_ENABLED:-0}"
APPMESH_IGNORE_UID="${APPMESH_IGNORE_UID:-1337}"
APPMESH_ENVOY_INGRESS_PORT="${APPMESH_ENVOY_INGRESS_PORT:-15000}"
APPMESH_ENVOY_EGRESS_PORT="${APPMESH_ENVOY_EGRESS_PORT:-15001}"
APPMESH_EGRESS_IGNORED_IP="${APPMESH_EGRESS_IGNORED_IP:-169.254.169.254,169.254.170.2}" 

# Enable routing on the application start.
[ -z "$APPMESH_START_ENABLED" ] && APPMESH_START_ENABLED="0"

# Egress traffic from the processess owned by the following UID/GID will be ignored.
if [ -z "$APPMESH_IGNORE_UID" ] && [ -z "$APPMESH_IGNORE_GID" ]; then
    echo "Variables APPMESH_IGNORE_UID and/or APPMESH_IGNORE_GID must be set."
    echo "Envoy must run under those IDs to be able to properly route it's egress traffic."
    exit 1
fi

# Port numbers Application and Envoy are listening on.
if [ -z "$APPMESH_ENVOY_INGRESS_PORT" ] || [ -z "$APPMESH_ENVOY_EGRESS_PORT" ] || [ -z "$APPMESH_APP_PORTS" ]; then
    echo "All of APPMESH_ENVOY_INGRESS_PORT, APPMESH_ENVOY_EGRESS_PORT and APPMESH_APP_PORTS variables must be set."
    echo "If any one of them is not set we will not be able to route either ingress, egress, or both directions."
    exit 1
fi

# Comma separated list of ports for which egress traffic will be ignored, we always refuse to route SSH traffic.
if [ -z "$APPMESH_EGRESS_IGNORED_PORTS" ]; then
    APPMESH_EGRESS_IGNORED_PORTS="22"
else
    APPMESH_EGRESS_IGNORED_PORTS="$APPMESH_EGRESS_IGNORED_PORTS,22"
fi

#
# End of configurable options
#

APPMESH_LOCAL_ROUTE_TABLE_ID="100"
APPMESH_PACKET_MARK="0x1e7700ce"

function initialize() {
    echo "=== Initializing ==="
    iptables -t mangle -N APPMESH_INGRESS
    iptables -t nat -N APPMESH_INGRESS
    iptables -t nat -N APPMESH_EGRESS

    ip rule add fwmark "$APPMESH_PACKET_MARK" lookup $APPMESH_LOCAL_ROUTE_TABLE_ID
    ip route add local default dev lo table $APPMESH_LOCAL_ROUTE_TABLE_ID
}

function enable_egress_routing() {
    # Stuff to ignore
    [ ! -z "$APPMESH_IGNORE_UID" ] && \
        iptables -t nat -A APPMESH_EGRESS \
        -m owner --uid-owner $APPMESH_IGNORE_UID \
        -j RETURN

    [ ! -z "$APPMESH_IGNORE_GID" ] && \
        iptables -t nat -A APPMESH_EGRESS \
        -m owner --gid-owner $APPMESH_IGNORE_GID \
        -j RETURN

    [ ! -z "$APPMESH_EGRESS_IGNORED_PORTS" ] && \
        iptables -t nat -A APPMESH_EGRESS \
        -p tcp \
        -m multiport --dports "$APPMESH_EGRESS_IGNORED_PORTS" \
        -j RETURN

    [ ! -z "$APPMESH_EGRESS_IGNORED_IP" ] && \
        iptables -t nat -A APPMESH_EGRESS \
        -p tcp \
        -d "$APPMESH_EGRESS_IGNORED_IP" \
        -j RETURN

    # Redirect everything that is not ignored
    iptables -t nat -A APPMESH_EGRESS \
        -p tcp \
        -j REDIRECT --to $APPMESH_ENVOY_EGRESS_PORT

    # Apply APPMESH_EGRESS chain to non local traffic
    iptables -t nat -A OUTPUT \
        -p tcp \
        -m addrtype ! --dst-type LOCAL \
        -j APPMESH_EGRESS
}

function enable_ingress_redirect_routing() {
    # Route everything arriving at the application port to Envoy
    iptables -t nat -A APPMESH_INGRESS \
        -p tcp \
        -m multiport --dports "$APPMESH_APP_PORTS" \
        -j REDIRECT --to-port "$APPMESH_ENVOY_INGRESS_PORT"

    # Apply AppMesh ingress chain to everything non-local
    iptables -t nat -A PREROUTING \
        -p tcp \
        -m addrtype ! --src-type LOCAL \
        -j APPMESH_INGRESS
}

function enable_routing() {
    echo "=== Enabling routing ==="
    enable_egress_routing
    enable_ingress_redirect_routing
}

function disable_routing() {
    echo "=== Disabling routing ==="
    iptables -F
    iptables -F -t nat
    iptables -F -t mangle
}

function dump_status() {
    echo "=== Routing rules ==="
    ip rule
    echo "=== AppMesh routing table ==="
    ip route list table $APPMESH_LOCAL_ROUTE_TABLE_ID
    echo "=== iptables FORWARD table ==="
    iptables -L -v -n
    echo "=== iptables NAT table ==="
    iptables -t nat -L -v -n
    echo "=== iptables MANGLE table ==="
    iptables -t mangle -L -v -n
}

function main_loop() {
    echo "=== Entering main loop ==="
    while read -p '> ' cmd; do
        case "$cmd" in
            "quit")
                break
                ;;
            "status")
                dump_status
                ;;
            "enable")
                enable_routing
                ;;
            "disable")
                disable_routing
                ;;
            *)
                echo "Available commands: quit, status, enable, disable"
                ;;
        esac
    done
}

function print_config() {
    echo "=== Input configuration ==="
    env | grep APPMESH_ || true
}

print_config

initialize

if [ "$APPMESH_START_ENABLED" == "1" ]; then
    enable_routing
fi

main_loop
