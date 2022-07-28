import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";
import { MeshStack } from "../stacks/mesh-components";
import { AppMeshFargateServiceProps } from "../utils";

export class AppMeshFargateService extends Construct {
  taskDefinition: ecs.FargateTaskDefinition;
  service: ecs.FargateService;
  securityGroup: ec2.SecurityGroup;
  envoySidecar: ecs.ContainerDefinition;
  xrayContainer: ecs.ContainerDefinition;

  appContainer: ecs.ContainerDefinition;

  constructor(mesh: MeshStack, id: string, props: AppMeshFargateServiceProps) {
    super(mesh, id);

    this.securityGroup = new ec2.SecurityGroup(this, `${props.serviceName}TaskSecurityGroup`, {
      vpc: mesh.serviceDiscovery.base.vpc,
    });
    this.securityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(mesh.serviceDiscovery.base.port));

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

    const serviceNamePrefix = this.envoySidecar ? "meshified-" : "";
    this.service = new ecs.FargateService(this, `${props.serviceName}Service`, {
      serviceName: `${serviceNamePrefix}${props.serviceName}`,
      cluster: mesh.serviceDiscovery.base.cluster,
      taskDefinition: this.taskDefinition,
      securityGroups: [this.securityGroup],
      assignPublicIp: true,
    });
    this.service.associateCloudMapService({
      container: this.appContainer,
      containerPort: mesh.serviceDiscovery.base.port,
      service: mesh.serviceDiscovery.getCloudMapService(props.serviceName),
    });
  }
}
