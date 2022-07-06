import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import { Duration } from "aws-cdk-lib";
import { Construct } from "constructs";
import { MeshStack } from "../stacks/mesh-components";
import { EnvoySidecar } from "./envoy-sidecar";
import { XrayContainer } from "./xray-container";
import { buildAppMeshProxy } from "../utils";

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

    this.taskDefinition = new ecs.FargateTaskDefinition(this, `${this.constructIdentifier}_TaskDefinition`, {
      cpu: 256,
      memoryLimitMiB: 512,
      proxyConfiguration: buildAppMeshProxy(ms.sd.base.containerPort),
      executionRole: ms.sd.base.executionRole,
      taskRole: ms.sd.base.taskRole,
      family: "front",
    });

    const envoyContainer = this.taskDefinition.addContainer(
      `${this.constructIdentifier}_EnvoyContainer`,
      new EnvoySidecar(ms, `${this.constructIdentifier}_Sidecar`, {
        logStreamPrefix: "front-envoy",
        appMeshResourcePath: `mesh/${ms.mesh.meshName}/virtualNode/${ms.frontendVirtualNode.virtualNodeName}`,
        enableXrayTracing: true,
      }).options
    );
    envoyContainer.addUlimits({
      name: ecs.UlimitName.NOFILE,
      hardLimit: 15000,
      softLimit: 15000,
    });

    const xrayContainer = this.taskDefinition.addContainer(
      `${this.constructIdentifier}_XrayContainer`,
      new XrayContainer(ms, `${this.constructIdentifier}_XrayHelper`, { logStreamPrefix: "front-xray" })
        .options
    );

    const appContainer = this.taskDefinition.addContainer(
      `${this.constructIdentifier}_FrontendAppContainer`,
      {
        containerName: "app",
        image: ecs.ContainerImage.fromDockerImageAsset(ms.sd.base.frontendAppImageAsset),
        logging: ecs.LogDriver.awsLogs({
          logGroup: ms.sd.base.logGroup,
          streamPrefix: "front-app",
        }),
        environment: {
          PORT: ms.sd.base.containerPort.toString(),
          COLOR_HOST: `${ms.backendVirtualService.virtualServiceName}:${ms.sd.base.containerPort}`,
          XRAY_APP_NAME: `${ms.mesh.meshName}/${ms.frontendVirtualNode.virtualNodeName}`,
        },
        portMappings: [{ containerPort: ms.sd.base.containerPort, protocol: ecs.Protocol.TCP }],
      }
    );

    appContainer.addContainerDependencies({
      container: xrayContainer,
      condition: ecs.ContainerDependencyCondition.START,
    });
    appContainer.addContainerDependencies({
      container: envoyContainer,
      condition: ecs.ContainerDependencyCondition.HEALTHY,
    });
    envoyContainer.addContainerDependencies({
      container: xrayContainer,
      condition: ecs.ContainerDependencyCondition.START,
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
