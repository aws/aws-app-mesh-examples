import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ec2 from "aws-cdk-lib/aws-ec2"
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import { Duration } from "aws-cdk-lib";
import { Construct } from "constructs";
import { MeshStack } from "../stacks/mesh-components";

export class FrontEndServiceConstruct extends Construct {
  
  taskDefinition: ecs.FargateTaskDefinition;
  service: ecs.FargateService;
  taskSecGroup: ec2.SecurityGroup;
  readonly constructIdentifier: string = "FrontendService";

  constructor(ms: MeshStack, id: string) {
    super(ms, id);

    this.taskSecGroup = new ec2.SecurityGroup(this, `${this.constructIdentifier}_TaskSecurityGroup`, {
      vpc: ms.sd.base.vpc,
    });
    this.taskSecGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.allTraffic());

    // App Mesh Proxy Config.
    const appMeshProxyConfig = new ecs.AppMeshProxyConfiguration({
      containerName: "envoy",
      properties: {
        proxyIngressPort: 15000,
        proxyEgressPort: 15001,
        appPorts: [ms.sd.base.containerPort],
        ignoredUID: 1337,
        egressIgnoredIPs: ["169.254.170.2", "169.254.169.254"],
      },
    });

    this.taskDefinition = new ecs.FargateTaskDefinition(
      this,
      `${this.constructIdentifier}_TaskDefinition`,
      {
        cpu: 256,
        memoryLimitMiB: 512,
        proxyConfiguration: appMeshProxyConfig,
        executionRole: ms.sd.base.executionRole,
        taskRole: ms.sd.base.taskRole,
        family: "front",
      }
    );

    // Add the Envoy Image to the task def.
    const envoyContainer = this.taskDefinition.addContainer(
      `${this.constructIdentifier}_EnvoyContainer`,
      {
        image: ms.sd.base.envoyImage,
        containerName: "envoy",
        logging: ecs.LogDriver.awsLogs({
          logGroup: ms.sd.base.logGroup,
          streamPrefix: "front-envoy",
        }),
        environment: {
          ENVOY_LOG_LEVEL: "debug",
          ENABLE_ENVOY_XRAY_TRACING: "1",
          ENABLE_ENVOY_STATS_TAGS: "1",
          APPMESH_VIRTUAL_NODE_NAME: `mesh/${ms.sd.base.projectName}/virtualNode/${ms.frontendVirtualNode.virtualNodeName}`,
        },
        user: "1337",
        healthCheck: {
          retries: 10,
          interval: Duration.seconds(5),
          timeout: Duration.seconds(10),
          command: [
            "CMD-SHELL",
            "curl -s http://localhost:9901/server_info | grep state | grep -q LIVE",
          ],
        },
      }
    );
    envoyContainer.addPortMappings({
      containerPort: 9901,
      protocol: ecs.Protocol.TCP,
    });
    envoyContainer.addPortMappings({
      containerPort: 15000,
      protocol: ecs.Protocol.TCP,
    });
    envoyContainer.addPortMappings({
      containerPort: 15001,
      protocol: ecs.Protocol.TCP,
    });
    envoyContainer.addUlimits({
      name: ecs.UlimitName.NOFILE,
      hardLimit: 15000,
      softLimit: 15000,
    });

    // Add the Xray Image to the task def.
    const xrayContainer = this.taskDefinition.addContainer(
      `${this.constructIdentifier}_XrayContainer`,
      {
        image: ms.sd.base.xrayDaemonImage,
        containerName: "xray",
        logging: ecs.LogDriver.awsLogs({
          logGroup: ms.sd.base.logGroup,
          streamPrefix: "front-xray",
        }),
        user: "1337",
      }
    );

    xrayContainer.addPortMappings({
      containerPort: 2000,
      protocol: ecs.Protocol.UDP,
    });

    envoyContainer.addContainerDependencies({
      container: xrayContainer,
      condition: ecs.ContainerDependencyCondition.START,
    });

    // Add the Frontend Image to the task def.
    const appContainer = this.taskDefinition.addContainer(`${this.constructIdentifier}_FrontendAppContainer`, {
      containerName: "app",
      image: ecs.ContainerImage.fromDockerImageAsset(ms.sd.base.frontendAppImageAsset),
      logging: ecs.LogDriver.awsLogs({
        logGroup: ms.sd.base.logGroup,
        streamPrefix: "front-app",
      }),
      environment: {
        PORT: ms.sd.base.containerPort.toString(),
        COLOR_HOST: `${ms.backendVirtualService.virtualServiceName}:${ms.sd.base.containerPort}`,
        XRAY_APP_NAME: `${ms.sd.base.mesh.meshName}/${ms.frontendVirtualNode.virtualNodeName}`,
      },
    });
    appContainer.addPortMappings({
      containerPort: ms.sd.base.containerPort,
      protocol: ecs.Protocol.TCP,
    });
    appContainer.addContainerDependencies({
      container: xrayContainer,
      condition: ecs.ContainerDependencyCondition.START,
    });
    appContainer.addContainerDependencies({
      container: envoyContainer,
      condition: ecs.ContainerDependencyCondition.HEALTHY,
    });

    const listener = ms.sd.frontendLoadBalancer.addListener(`${this.constructIdentifier}_Listener`, {
      port: 80,
      open: true,
    });

    this.service = new ecs.FargateService(this, `${this.constructIdentifier}_Service`, {
      serviceName: "frontend",
      cluster: ms.sd.base.cluster,
      taskDefinition: this.taskDefinition,
      desiredCount: 1,
      maxHealthyPercent: 200,
      minHealthyPercent: 100,
      enableExecuteCommand: true,
      securityGroups: [this.taskSecGroup],
    });

    this.service.registerLoadBalancerTargets({
      containerName: "app",
      containerPort: ms.sd.base.containerPort,
      newTargetGroupId: `${this.constructIdentifier}_TargetGroup`,
      listener: ecs.ListenerConfig.applicationListener(listener, {
        protocol: elbv2.ApplicationProtocol.HTTP,
        healthCheck: {
          path: "/ping",
          port: ms.sd.base.containerPort.toString(),
          timeout: Duration.seconds(5),
          interval: Duration.seconds(60),
        },
      }),
    });
  }
}
