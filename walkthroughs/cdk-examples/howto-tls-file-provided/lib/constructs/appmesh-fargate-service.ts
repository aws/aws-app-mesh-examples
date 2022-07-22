import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";

import { Construct } from "constructs";
import { MeshStack } from "../stacks/mesh-components";
import { AppMeshFargateServiceProps } from "../utils";
import { Duration } from "aws-cdk-lib";

export class AppMeshFargateService extends Construct {
  taskDefinition: ecs.FargateTaskDefinition;
  service: ecs.FargateService;
  securityGroup: ec2.SecurityGroup;
  envoySidecar: ecs.ContainerDefinition;
  xrayContainer: ecs.ContainerDefinition;

  appContainer: ecs.ContainerDefinition;
  cfnService: ecs.CfnService;

  constructor(ms: MeshStack, id: string, props: AppMeshFargateServiceProps) {
    super(ms, id);

    this.securityGroup = new ec2.SecurityGroup(this, `${props.serviceName}TaskSecurityGroup`, {
      vpc: ms.serviceDiscovery.infra.vpc,
    });
    this.securityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.allTraffic());

    const isGatewayService = props.serviceName == ms.serviceDiscovery.infra.SERVICE_GATEWAY;
    const proxyConfiguration =
      props.envoyConfiguration && props.envoyConfiguration.container && props.envoyConfiguration.proxyConfiguration
        ? props.envoyConfiguration.proxyConfiguration
        : undefined;

    this.taskDefinition = new ecs.FargateTaskDefinition(this, `${props.serviceName}TaskDefinition`, {
      proxyConfiguration: proxyConfiguration,
      executionRole: ms.serviceDiscovery.infra.executionRole,
      taskRole: ms.serviceDiscovery.infra.taskRole,
      family: props.taskDefinitionFamily,
    });

    if (props.applicationContainer) {
      this.appContainer = this.taskDefinition.addContainer(
        `${props.serviceName}ApplicationContainer`,
        props.applicationContainer.options
      );
    }

    if (props.envoyConfiguration && props.envoyConfiguration.container) {
      this.envoySidecar = this.taskDefinition.addContainer(
        `${props.serviceName}EnvoyContainer`,
        props.envoyConfiguration.container.options
      );

      if (isGatewayService) {
        this.envoySidecar.addPortMappings({
          containerPort: 8080,
          protocol: ecs.Protocol.TCP,
        });
      }

      this.envoySidecar.addUlimits({
        name: ecs.UlimitName.NOFILE,
        hardLimit: 15000,
        softLimit: 15000,
      });
      if (this.appContainer) {
        this.appContainer.addContainerDependencies({
          container: this.envoySidecar,
          condition: ecs.ContainerDependencyCondition.HEALTHY,
        });
      }
    }

    this.service = new ecs.FargateService(this, `${props.serviceName}Service`, {
      serviceName: props.serviceName,
      cluster: ms.serviceDiscovery.infra.cluster,
      taskDefinition: this.taskDefinition,
      securityGroups: [this.securityGroup],
      assignPublicIp: isGatewayService,
      enableExecuteCommand: true,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_NAT },
    });

    if (isGatewayService) {
      const listener = ms.serviceDiscovery.publicLoadBalancer.addListener(`${props.serviceName}Listener`, {
        port: 80,
        open: true,
      });
      this.service.registerLoadBalancerTargets({
        containerName: this.envoySidecar.containerName,
        containerPort: 8080,
        newTargetGroupId: `${props.serviceName}TargetGroup`,
        listener: ecs.ListenerConfig.applicationListener(listener, {
          protocol: elbv2.ApplicationProtocol.HTTP,
          healthCheck: {
            path: "/ready",
            port: "9901",
            interval: Duration.seconds(6),
          },
        }),
      });
    } else {
      this.service.associateCloudMapService({
        container: this.appContainer,
        containerPort: 80,
        service: ms.serviceDiscovery.getCloudMapSerivce(props.serviceName),
      });
    }
  }
}
