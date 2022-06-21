import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import { Construct } from 'constructs';
import { MeshStack } from './mesh';
import { Duration } from 'aws-cdk-lib';


export class BackendServiceV1Construct extends Construct {

  taskDefinition: ecs.TaskDefinition;
  service: ecs.FargateService;
  prefix: string = 'BackendServiceV1';

  constructor(ms: MeshStack, id: string) {
    super(ms, id);

    // Task Definition
    this.taskDefinition = new ecs.FargateTaskDefinition(this, `${this.prefix}TaskDefinition`, {
      cpu: 256,
      memoryLimitMiB: 512,
      executionRole: ms.sd.base.executionRole,
      taskRole: ms.sd.base.taskRole,
      family: 'blue'
    });

    // Add the colorApp container
    // https://github.com/aws/aws-cdk/issues/12371
    const colorAppContainer = this.taskDefinition.addContainer(`${this.prefix}ColorContainer`, {
      containerName: 'app',
      image: ecs.ContainerImage.fromDockerImageAsset(ms.sd.base.backendAppImageAsset),
      environment: {
        COLOR: 'blue',
        PORT: ms.sd.base.containerPort.toString(),
        XRAY_APP_NAME: `${ms.sd.base.mesh.meshName}/${ms.backendV1VirtualNode.virtualNodeName}`,
      },
      logging: ecs.LogDriver.awsLogs({ logGroup: ms.sd.base.logGroup, streamPrefix: 'backend-v1-app' })
    })

    colorAppContainer.addPortMappings({
      containerPort: ms.sd.base.containerPort,
      hostPort: ms.sd.base.containerPort,
      protocol: ecs.Protocol.TCP
    });

    // Add the Xray container
    const xrayContainer  = this.taskDefinition.addContainer(`${this.prefix}XrayContainer`, {
      image: ms.sd.base.xrayDaemonImage,
      containerName: 'xray',
      logging: ecs.LogDriver.awsLogs({ logGroup: ms.sd.base.logGroup, streamPrefix: 'backend-v1-xray' }),
      user: '1337'
    });
  
    xrayContainer.addPortMappings({
        containerPort: 2000,
        protocol: ecs.Protocol.UDP,
    });

    // Define container dependencies
    colorAppContainer.addContainerDependencies(
      {
        container: xrayContainer,
        condition: ecs.ContainerDependencyCondition.START
      }
    );

    // Condfigure load balancer listener
    const listener = ms.sd.backendV1LoadBalancer.addListener('BackendV1LBListener', {
      port: ms.sd.base.containerPort,
      open: true,
    });

    // Define the fargate service and register it to the ALB
    this.service = new ecs.FargateService(this, 'BackendV1FargateService', {
      serviceName: 'backend-v1',
      cluster: ms.sd.base.cluster,
      taskDefinition: this.taskDefinition,
      desiredCount: 1,
      maxHealthyPercent: 200,
      minHealthyPercent: 100,
      enableExecuteCommand: true,
    });

    this.service.registerLoadBalancerTargets(
      {
        containerName: 'app',
        containerPort: ms.sd.base.containerPort,
        newTargetGroupId: 'BackendV1App',
        listener: ecs.ListenerConfig.applicationListener(listener, {
          protocol: elbv2.ApplicationProtocol.HTTP,
          healthCheck: {
            path: '/ping',
            port: ms.sd.base.containerPort.toString(),
            timeout: Duration.seconds(5),
            interval: Duration.seconds(60),
          }
        }),
      },
    );
  }
}