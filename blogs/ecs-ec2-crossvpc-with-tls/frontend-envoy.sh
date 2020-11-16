# Please modify the envoy image parameter with the latest image from  https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html 
# Create YAML file #
cat <<-"EOF" > /tmp/install_envoy.yml
---
schemaVersion: '2.2'
description: Install Envoy Proxy
parameters: 
  envoyimage:
    type: String
  region:
    type: String
  meshName:
    type: String
  vNodeName:
    type: String 
  ignoredUID:
    type: String
    default: '1337'
  proxyIngressPort:
    type: String
    default: '15000'
  proxyEgressPort:
    type: String
    default: '15001'
  appPorts:
    type: String
  egressIgnoredIPs:
    type: String
    default: '169.254.169.254,169.254.170.2'
  egressIgnoredPorts:
    type: String 
    default: '22'
mainSteps:
- action: aws:configureDocker
  name: configureDocker
  inputs:
    action: Install
- action: aws:runShellScript
  name: installEnvoy
  inputs:
    runCommand: 
      - |
        #! /bin/bash -ex
        sudo yum install -y jq
        $(aws ecr get-login --no-include-email --region {{region}} --registry-ids 840364872350)
        # Install and run envoy
        sudo docker run --detach \
          --env APPMESH_VIRTUAL_NODE_NAME=mesh/{{meshName}}/virtualNode/{{vNodeName}} \
          --env ENABLE_ENVOY_XRAY_TRACING=1 \
          --log-driver=awslogs \
          --log-opt awslogs-region={{region}} \
          --log-opt awslogs-create-group=true \
          --log-opt awslogs-group=appmesh-workshop-frontend-envoy \
          --log-opt tag=ec2/envoy/{{.FullID}} \
          -u {{ignoredUID}} --network host \
          {{envoyimage}}
- action: aws:runShellScript
  name: installXRay
  inputs:
    runCommand: 
      - |
        #! /bin/bash -ex
        XRAY_HOST=https://s3.dualstack.{{region}}.amazonaws.com
        XRAY_PATH=aws-xray-assets.{{region}}/xray-daemon/aws-xray-daemon-3.x.rpm
        # Install and run xray daemon
        sudo curl $XRAY_HOST/$XRAY_PATH -o /tmp/xray.rpm
        sudo yum install -y /tmp/xray.rpm
- action: aws:runShellScript
  name: enableRouting
  inputs:
    runCommand: 
      - |
        #! /bin/bash -ex
        APPMESH_LOCAL_ROUTE_TABLE_ID="100"
        APPMESH_PACKET_MARK="0x1e7700ce"
        # Initialize chains
        sudo iptables -t mangle -N APPMESH_INGRESS
        sudo iptables -t nat -N APPMESH_INGRESS
        sudo iptables -t nat -N APPMESH_EGRESS
        sudo ip rule add fwmark "$APPMESH_PACKET_MARK" lookup $APPMESH_LOCAL_ROUTE_TABLE_ID
        sudo ip route add local default dev lo table $APPMESH_LOCAL_ROUTE_TABLE_ID
        # Enable egress routing
          # Ignore egress redirect based UID, ports, and IPs
          sudo iptables -t nat -A APPMESH_EGRESS \
            -m owner --uid-owner {{ignoredUID}} \
            -j RETURN
          sudo iptables -t nat -A APPMESH_EGRESS \
            -p tcp \
            -m multiport --dports "{{egressIgnoredPorts}}" \
            -j RETURN
          sudo iptables -t nat -A APPMESH_EGRESS \
            -p tcp \
            -d "{{egressIgnoredIPs}}" \
            -j RETURN
          # Redirect everything that is not ignored
          sudo iptables -t nat -A APPMESH_EGRESS \
            -p tcp \
            -j REDIRECT --to {{proxyEgressPort}}
          # Apply APPMESH_EGRESS chain to non-local traffic
          sudo iptables -t nat -A OUTPUT \
            -p tcp \
            -m addrtype ! --dst-type LOCAL \
            -j APPMESH_EGRESS
        # Enable ingress routing
          # Route everything arriving at the application port to Envoy
          sudo iptables -t nat -A APPMESH_INGRESS \
            -p tcp \
            -m multiport --dports "{{appPorts}}" \
            -j REDIRECT --to-port "{{proxyIngressPort}}"
          # Apply APPMESH_INGRESS chain to non-local traffic
          sudo iptables -t nat -A PREROUTING \
            -p tcp \
            -m addrtype ! --src-type LOCAL \
            -j APPMESH_INGRESS
EOF
# Create ssm document #
aws ssm create-document \
  --name appmesh-workshop-installenvoy \
  --document-format YAML \
  --content file:///tmp/install_envoy.yml \
  --document-type Command
AUTOSCALING_GROUP=$(jq < cfn-crystal.json -r '.RubyAutoScalingGroupName');
# Create the association with the frontend EC2 instances
aws ssm create-association \
  --name appmesh-workshop-installenvoy \
  --association-name appmesh-workshop-state \
  --targets "Key=tag:aws:autoscaling:groupName,Values=$AUTOSCALING_GROUP" \
  --max-errors 0 \
  --max-concurrency 50% \
  --parameters \
      "region=$AWS_REGION,
        meshName=appmesh-workshop,
        vNodeName=frontend,
        envoyimage=$ENVOY_IMAGE,
        appPorts=3000"
