import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Duration } from "aws-cdk-lib";
import { Construct } from "constructs";
import { MeshStack } from "../stacks/mesh-components";
import { EnvoySidecar } from "./envoy-sidecar";
import { XrayContainer } from "./xray-container";

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

    // Task Definition
    this.taskDefinition = new ecs.FargateTaskDefinition(this, `${this.constructIdentifier}_TaskDefinition`, {
      cpu: 256,
      memoryLimitMiB: 512,
      executionRole: ms.sd.base.executionRole,
      taskRole: ms.sd.base.taskRole,
      family: "green",
    });

    // Add the Envoy container
    const envoyContainer = this.taskDefinition.addContainer(
      `${this.constructIdentifier}_EnvoyContainer`,
      new EnvoySidecar(ms, `${this.constructIdentifier}_Sidecar`, {
        logStreamPrefix: "backend-v2-envoy",
        appMeshResourcePath: `mesh/${ms.mesh.meshName}/virtualNode/${ms.backendV2VirtualNode.virtualNodeName}`,
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
      new XrayContainer(ms, `${this.constructIdentifier}_XrayHelper`, { logStreamPrefix: "backend-v2-xray" })
        .options
    );

    const colorAppContainer = this.taskDefinition.addContainer(
      `${this.constructIdentifier}_ColorAppContainer`,
      {
        image: ecs.ContainerImage.fromDockerImageAsset(ms.sd.base.backendAppImageAsset),
        containerName: "app",
        environment: {
          COLOR: "green",
          PORT: ms.sd.base.containerPort.toString(),
          XRAY_APP_NAME: `${ms.mesh.meshName}/${ms.backendV2VirtualNode.virtualNodeName}`,
        },
        logging: ecs.LogDriver.awsLogs({
          logGroup: ms.sd.base.logGroup,
          streamPrefix: "backend-v2-app",
        }),
        portMappings: [
          {
            containerPort: ms.sd.base.containerPort,
            hostPort: ms.sd.base.containerPort,
            protocol: ecs.Protocol.TCP,
          },
        ],
      }
    );

    envoyContainer.addContainerDependencies({
      container: xrayContainer,
      condition: ecs.ContainerDependencyCondition.START,
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
