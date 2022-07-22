import * as ecs from "aws-cdk-lib/aws-ecs";
import { StackProps, Stack, CfnOutput } from "aws-cdk-lib";
import { MeshStack } from "./mesh-components";
import { AppMeshFargateService } from "../constructs/appmesh-fargate-service";
import { EnvoySidecar } from "../constructs/envoy-sidecar";
import { ApplicationContainer } from "../constructs/application-container";
import { ServiceDiscoveryType } from "../utils";

export class EcsServicesStack extends Stack {
  constructor(ms: MeshStack, id: string, props?: StackProps) {
    super(ms, id, props);

    const white = new AppMeshFargateService(ms, `${this.stackName}WhiteService`, {
      serviceName: ms.serviceDiscovery.infra.SERVICE_WHITE,
      taskDefinitionFamily: ms.serviceDiscovery.infra.SERVICE_WHITE,
      serviceDiscoveryType: ServiceDiscoveryType.CLOUDMAP,
      applicationContainer: new ApplicationContainer(ms, `${this.stackName}WhiteAppContainer`, {
        image: ecs.ContainerImage.fromDockerImageAsset(ms.serviceDiscovery.infra.colorTellerImageAsset),
        logStreamPrefix: ms.serviceDiscovery.infra.SERVICE_WHITE,
        env: {
          SERVER_PORT: "80",
          COLOR: "WHITE",
        },
        portMappings: [{ containerPort: 80, protocol: ecs.Protocol.TCP }],
      }),
      envoyConfiguration: {
        container: new EnvoySidecar(ms, `${this.stackName}WhiteEnvoySidecar`, {
          logStreamPrefix: "white-envoy",
          certificateName: "colorteller_white",
          appMeshResourceArn: ms.virtualNodeWhite.virtualNodeArn,
          enableXrayTracing: false,
        }),
        proxyConfiguration: EnvoySidecar.buildAppMeshProxy(80),
      },
    });

    const green = new AppMeshFargateService(ms, `${this.stackName}GreenService`, {
      serviceName: ms.serviceDiscovery.infra.SERVICE_GREEN,
      taskDefinitionFamily: ms.serviceDiscovery.infra.SERVICE_GREEN,
      serviceDiscoveryType: ServiceDiscoveryType.CLOUDMAP,
      applicationContainer: new ApplicationContainer(ms, `${this.stackName}GreenAppContainer`, {
        image: ecs.ContainerImage.fromDockerImageAsset(ms.serviceDiscovery.infra.colorTellerImageAsset),
        logStreamPrefix: ms.serviceDiscovery.infra.SERVICE_GREEN,
        env: {
          SERVER_PORT: "80",
          COLOR: "GREEN",
        },
        portMappings: [{ containerPort: 80, protocol: ecs.Protocol.TCP }],
      }),
      envoyConfiguration: {
        container: new EnvoySidecar(ms, `${this.stackName}GreenEnvoySidecar`, {
          logStreamPrefix: "green-envoy",
          certificateName: "colorteller_green",
          appMeshResourceArn: ms.virtualNodeGreen.virtualNodeArn,
          enableXrayTracing: false,
        }),
        proxyConfiguration: EnvoySidecar.buildAppMeshProxy(80),
      },
    });

    const gateway = new AppMeshFargateService(ms, `${this.stackName}GatewayService`, {
      serviceName: ms.serviceDiscovery.infra.SERVICE_GATEWAY,
      taskDefinitionFamily: ms.serviceDiscovery.infra.SERVICE_GATEWAY,
      serviceDiscoveryType: ServiceDiscoveryType.CLOUDMAP,
      envoyConfiguration: {
        container: new EnvoySidecar(ms, `${this.stackName}GatewayEnvoySidecar`, {
          logStreamPrefix: "gateway-envoy",
          certificateName: "colorgateway",
          appMeshResourceArn: ms.virtualGateway.virtualGatewayArn,
          enableXrayTracing: false,
        }),
      },
    });

    gateway.node.addDependency(white);
    gateway.node.addDependency(green);

    new CfnOutput(this, "URL", { value: ms.serviceDiscovery.publicLoadBalancer.loadBalancerDnsName });
  }
}
