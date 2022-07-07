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
  securityGroup: ec2.SecurityGroup;
  envoySidecar: ecs.ContainerDefinition;
  xrayContainer: ecs.ContainerDefinition;
  appContainer: ecs.ContainerDefinition;

  constructor(ms: MeshStack, id: string, props: AppMeshFargateServiceProps) {
    super(ms, id);

    this.securityGroup = new ec2.SecurityGroup(this, `${props.serviceName}TaskSecurityGroup`, {
      vpc: ms.sd.base.vpc,
    });
    this.securityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.allTraffic());

    this.taskDefinition = new ecs.FargateTaskDefinition(this, `${props.serviceName}TaskDefinition`, {
      proxyConfiguration: props.proxyConfiguration,
      executionRole: ms.sd.base.executionRole,
      taskRole: ms.sd.base.taskRole,
      family: props.taskDefinitionFamily,
    });

    this.appContainer = this.taskDefinition.addContainer(
      `${props.serviceName}ApplicationContainer`,
      props.applicationContainer.options
    );

    if (props.envoySidecar) {
      this.envoySidecar = this.taskDefinition.addContainer(
        `${props.serviceName}EnvoyContainer`,
        props.envoySidecar.options
      );
      this.envoySidecar.addUlimits({
        name: ecs.UlimitName.NOFILE,
        hardLimit: 15000,
        softLimit: 15000,
      });
      this.appContainer.addContainerDependencies({
        container: this.envoySidecar,
        condition: ecs.ContainerDependencyCondition.HEALTHY,
      });
    }

    if (props.xrayContainer) {
      this.xrayContainer = this.taskDefinition.addContainer(
        `${props.serviceName}XrayContainer`,
        props.xrayContainer.options
      );
      this.appContainer.addContainerDependencies({
        container: this.xrayContainer,
        condition: ecs.ContainerDependencyCondition.START,
      });
      if (this.envoySidecar) {
        this.envoySidecar.addContainerDependencies({
          container: this.xrayContainer,
          condition: ecs.ContainerDependencyCondition.START,
        });
      }
    }

    this.service = new ecs.FargateService(this, `${props.serviceName}Service`, {
      serviceName: props.serviceName,
      cluster: ms.sd.base.cluster,
      taskDefinition: this.taskDefinition,
      securityGroups: [this.securityGroup],
    });

    if (props.serviceDiscoveryType == ServiceDiscoveryType.DNS) {
      const loadBalancer = ms.sd.getAlbForService(props.serviceName);
      const listener = loadBalancer.addListener(`${props.serviceName}Listener`, {
        port: props.serviceName == ms.sd.base.SERVICE_FRONTEND ? 80 : ms.sd.base.PORT,
        open: true,
      });
      this.service.registerLoadBalancerTargets({
        containerName: this.appContainer.containerName,
        containerPort: ms.sd.base.PORT,
        newTargetGroupId: `${props.serviceName}TargetGroup`,
        listener: ecs.ListenerConfig.applicationListener(listener, {
          protocol: elbv2.ApplicationProtocol.HTTP,
          healthCheck: {
            path: "/ping",
            port: ms.sd.base.PORT.toString(),
            interval: Duration.seconds(60),
          },
        }),
      });
    } else if (props.serviceDiscoveryType == ServiceDiscoveryType.CLOUDMAP) {
      this.service.associateCloudMapService({
        container: this.appContainer,
        containerPort: ms.sd.base.PORT,
        service: ms.sd.backendV2CloudMapService,
      });
    }
  }
}
