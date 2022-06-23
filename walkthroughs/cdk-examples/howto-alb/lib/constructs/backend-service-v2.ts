import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Duration } from "aws-cdk-lib";
import { Construct } from "constructs";
import { MeshStack } from "../stacks/mesh-components";

export class BackendServiceV2Construct extends Construct {
  taskDefinition: ecs.FargateTaskDefinition;
  service: ecs.FargateService;
  taskSecGroup: ec2.SecurityGroup;
  readonly constructIdentifier: string = "BackendServiceV2";

  constructor(ms: MeshStack, id: string) {
    super(ms, id);

    this.taskSecGroup = new ec2.SecurityGroup(this, `${this.constructIdentifier}_TaskSecurityGroup`, {
      vpc: ms.sd.base.vpc,
    });
    this.taskSecGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.allTraffic());

    // // Task Definition
    this.taskDefinition = new ecs.FargateTaskDefinition(
      this,
      `${this.constructIdentifier}_TaskDefinition`,
      {
        cpu: 256,
        memoryLimitMiB: 512,
        executionRole: ms.sd.base.executionRole,
        taskRole: ms.sd.base.taskRole,
        family: "green",
      }
    );

    // Add the Envoy container
    const envoyContainer = this.taskDefinition.addContainer(
      `${this.constructIdentifier}_EnvoyContainer`,
      {
        image: ms.sd.base.envoyImage,
        containerName: "envoy",
        environment: {
          ENVOY_LOG_LEVEL: "debug",
          ENABLE_ENVOY_XRAY_TRACING: "1",
          ENABLE_ENVOY_STATS_TAGS: "1",
          APPMESH_VIRTUAL_NODE_NAME: `mesh/${ms.sd.base.projectName}/virtualNode/${ms.backendV2VirtualNode.virtualNodeName}`,
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
        logging: ecs.LogDriver.awsLogs({
          logGroup: ms.sd.base.logGroup,
          streamPrefix: "backend-v2-envoy",
        }),
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

    //Add the Xray container
    const xrayContainer = this.taskDefinition.addContainer(
      `${this.constructIdentifier}_XrayContainer`,
      {
        image: ms.sd.base.xrayDaemonImage,
        containerName: "xray",
        logging: ecs.LogDriver.awsLogs({
          logGroup: ms.sd.base.logGroup,
          streamPrefix: "backend-v2-xray",
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

    // Add the colorApp Container
    const colorAppContainer = this.taskDefinition.addContainer(
      `${this.constructIdentifier}_ColorAppContainer`,
      {
        image: ecs.ContainerImage.fromDockerImageAsset(ms.sd.base.backendAppImageAsset),
        containerName: "app",
        environment: {
          COLOR: "green",
          PORT: ms.sd.base.containerPort.toString(),
          XRAY_APP_NAME: `${ms.sd.base.mesh.meshName}/${ms.backendV2VirtualNode.virtualNodeName}`,
        },
        logging: ecs.LogDriver.awsLogs({
          logGroup: ms.sd.base.logGroup,
          streamPrefix: "backend-v2-app",
        }),
      }
    );
    colorAppContainer.addPortMappings({
      containerPort: ms.sd.base.containerPort,
      hostPort: ms.sd.base.containerPort,
      protocol: ecs.Protocol.TCP,
    });

    colorAppContainer.addContainerDependencies({
      container: xrayContainer,
      condition: ecs.ContainerDependencyCondition.START,
    });
    colorAppContainer.addContainerDependencies({
      container: envoyContainer,
      condition: ecs.ContainerDependencyCondition.HEALTHY,
    });

    // Define the Fargate Service and link it to CloudMap service discovery
    this.service = new ecs.FargateService(this, `${this.constructIdentifier}_Service`, {
      cluster: ms.sd.base.cluster,
      serviceName: ms.sd.backendV2CloudMapService.serviceName,
      taskDefinition: this.taskDefinition,
      assignPublicIp: false,
      desiredCount: 1,
      maxHealthyPercent: 200,
      minHealthyPercent: 100,
      enableExecuteCommand: true,
      securityGroups: [this.taskSecGroup],
    });

    this.service.associateCloudMapService({
      container: colorAppContainer,
      containerPort: ms.sd.base.containerPort,
      service: ms.sd.backendV2CloudMapService,
    });
  }
}
