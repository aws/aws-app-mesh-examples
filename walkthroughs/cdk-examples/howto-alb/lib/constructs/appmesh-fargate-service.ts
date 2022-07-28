import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import { Duration } from "aws-cdk-lib";
import { Construct } from "constructs";
import { MeshStack } from "../stacks/mesh-components";
import { AppMeshFargateServiceProps, ServiceDiscoveryType } from "../utils";

export class AppMeshFargateService extends Construct {
  readonly taskDefinition: ecs.FargateTaskDefinition;
  readonly service: ecs.FargateService;
  readonly securityGroup: ec2.SecurityGroup;
  readonly envoySidecar: ecs.ContainerDefinition;
  readonly xrayContainer: ecs.ContainerDefinition;
  readonly appContainer: ecs.ContainerDefinition;

  constructor(mesh: MeshStack, id: string, props: AppMeshFargateServiceProps) {
    super(mesh, id);

    this.securityGroup = new ec2.SecurityGroup(this, `${props.serviceName}TaskSecurityGroup`, {
      vpc: mesh.serviceDiscovery.base.vpc,
    });
    this.allowIpv4IngressForTcpPorts([80, 8080]);

    const proxyConfiguration =
      props.envoyConfiguration && props.envoyConfiguration.container && props.envoyConfiguration.proxyConfiguration
        ? props.envoyConfiguration.proxyConfiguration
        : undefined;

    this.taskDefinition = new ecs.FargateTaskDefinition(this, `${props.serviceName}TaskDefinition`, {
      proxyConfiguration: proxyConfiguration,
      executionRole: mesh.serviceDiscovery.base.executionRole,
      taskRole: mesh.serviceDiscovery.base.taskRole,
      family: props.taskDefinitionFamily,
    });

    this.appContainer = this.taskDefinition.addContainer(
      `${props.serviceName}ApplicationContainer`,
      props.applicationContainer.options
    );

    if (props.envoyConfiguration && props.envoyConfiguration.container) {
      this.envoySidecar = this.taskDefinition.addContainer(
        `${props.serviceName}EnvoyContainer`,
        props.envoyConfiguration.container.options
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
      cluster: mesh.serviceDiscovery.base.cluster,
      taskDefinition: this.taskDefinition,
      securityGroups: [this.securityGroup],
    });

    if (props.serviceDiscoveryType == ServiceDiscoveryType.DNS) {
      const loadBalancer = mesh.serviceDiscovery.getAlbForService(props.serviceName);
      const listener = loadBalancer.addListener(`${props.serviceName}Listener`, {
        port: props.serviceName == mesh.serviceDiscovery.base.serviceFrontend ? 80 : mesh.serviceDiscovery.base.port,
        open: true,
      });
      this.service.registerLoadBalancerTargets({
        containerName: this.appContainer.containerName,
        containerPort: mesh.serviceDiscovery.base.port,
        newTargetGroupId: `${props.serviceName}TargetGroup`,
        listener: ecs.ListenerConfig.applicationListener(listener, {
          protocol: elbv2.ApplicationProtocol.HTTP,
          healthCheck: {
            path: "/ping",
            port: mesh.serviceDiscovery.base.port.toString(),
            interval: Duration.seconds(60),
          },
        }),
      });
    } else if (props.serviceDiscoveryType == ServiceDiscoveryType.CLOUDMAP) {
      this.service.associateCloudMapService({
        container: this.appContainer,
        containerPort: mesh.serviceDiscovery.base.port,
        service: mesh.serviceDiscovery.backendV2CloudMapService,
      });
    }
  }
  private allowIpv4IngressForTcpPorts = (ports: number[]): void => {
    ports.forEach((port) => this.securityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(port)));
  };
}
