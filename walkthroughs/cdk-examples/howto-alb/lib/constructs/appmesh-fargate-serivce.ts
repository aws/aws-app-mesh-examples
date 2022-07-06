import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import { Duration } from "aws-cdk-lib";
import { Construct } from "constructs";
import { MeshStack } from "../stacks/mesh-components";
import { AppMeshFargateServiceProps, ServiceDiscoveryType } from "../utils";

export class AppMeshFargateService extends Construct {
  taskDefinition: ecs.FargateTaskDefinition;
  service: ecs.FargateService;
  taskSecGroup: ec2.SecurityGroup;
  envoySidecar: ecs.ContainerDefinition;
  xrayContainer: ecs.ContainerDefinition;

  constructor(ms: MeshStack, id: string, props: AppMeshFargateServiceProps) {
    super(ms, id);

    this.taskSecGroup = new ec2.SecurityGroup(this, `${props.serviceName}_TaskSecurityGroup`, {
      vpc: ms.sd.base.vpc,
    });
    this.taskSecGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.allTraffic());

    this.taskDefinition = new ecs.FargateTaskDefinition(this, `${props.serviceName}_TaskDefinition`, {
      proxyConfiguration: props.proxyConfiguration,
      executionRole: ms.sd.base.executionRole,
      taskRole: ms.sd.base.taskRole,
      family: props.taskDefinitionFamily,
    });

    if (props.envoySidecar) {
      this.envoySidecar = this.taskDefinition.addContainer(
        `${props.serviceName}_EnvoyContainer`,
        props.envoySidecar.options
      );
      this.envoySidecar.addUlimits({
        name: ecs.UlimitName.NOFILE,
        hardLimit: 15000,
        softLimit: 15000,
      });
    }

    this.xrayContainer = this.taskDefinition.addContainer(
      `${props.serviceName}_XrayContainer`,
      props.xrayContainer.options
    );

    const appContainer = this.taskDefinition.addContainer(
      `${props.serviceName}AppContainer`,
      props.applicationContainerProps
    );

    appContainer.addContainerDependencies({
      container: this.xrayContainer,
      condition: ecs.ContainerDependencyCondition.START,
    });
    appContainer.addContainerDependencies({
      container: this.envoySidecar,
      condition: ecs.ContainerDependencyCondition.HEALTHY,
    });

    if (this.envoySidecar) {
      this.envoySidecar.addContainerDependencies({
        container: this.xrayContainer,
        condition: ecs.ContainerDependencyCondition.START,
      });
    }

    this.service = new ecs.FargateService(this, `${props.serviceName}_Service`, {
      serviceName: props.serviceName,
      cluster: ms.sd.base.cluster,
      taskDefinition: this.taskDefinition,
      securityGroups: [this.taskSecGroup],
    });
    if (props.serviceDiscoveryType == ServiceDiscoveryType.DNS) {
      const listener = ms.sd.frontendLoadBalancer.addListener(`${props.serviceName}_Listener`, {
        port: props.serviceName == ms.sd.base.SERVICE_FRONTEND ? 80 : ms.sd.base.containerPort,
        open: true,
      });

      this.service.registerLoadBalancerTargets({
        containerName: appContainer.containerName,
        containerPort: ms.sd.base.containerPort,
        newTargetGroupId: `${props.serviceName}_TargetGroup`,
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
    } else if (props.serviceDiscoveryType == ServiceDiscoveryType.CLOUDMAP) {
      this.service.associateCloudMapService({
        container: appContainer,
        containerPort: ms.sd.base.containerPort,
        service: ms.sd.backendV2CloudMapService,
      });
    }
  }
}
