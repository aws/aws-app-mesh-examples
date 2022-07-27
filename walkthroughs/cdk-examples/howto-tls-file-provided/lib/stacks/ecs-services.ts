import * as ecs from "aws-cdk-lib/aws-ecs";
import { StackProps, Stack, CfnOutput } from "aws-cdk-lib";
import { MeshStack } from "./mesh-components";
import { AppMeshFargateService } from "../constructs/appmesh-fargate-service";
import { EnvoySidecar } from "../constructs/envoy-sidecar";
import { ApplicationContainer } from "../constructs/application-container";

export class EcsServicesStack extends Stack {
  constructor(mesh: MeshStack, id: string, props?: StackProps) {
    super(mesh, id, props);

    const white = new AppMeshFargateService(mesh, `${this.stackName}WhiteService`, {
      serviceName: mesh.serviceDiscovery.infra.serviceWhite,
      taskDefinitionFamily: mesh.serviceDiscovery.infra.serviceWhite,
      applicationContainer: new ApplicationContainer(mesh, `${this.stackName}WhiteAppContainer`, {
        image: ecs.ContainerImage.fromDockerImageAsset(mesh.serviceDiscovery.infra.colorTellerImageAsset),
        logStreamPrefix: mesh.serviceDiscovery.infra.serviceWhite,
        env: {
          SERVER_PORT: "80",
          COLOR: "WHITE",
        },
        portMappings: [{ containerPort: 80, protocol: ecs.Protocol.TCP }],
      }),
      envoyConfiguration: {
        container: new EnvoySidecar(mesh, `${this.stackName}WhiteEnvoySidecar`, {
          logStreamPrefix: "white-envoy",
          certificateName: "colorteller_white",
          appMeshResourceArn: mesh.virtualNodeWhite.virtualNodeArn,
          enableXrayTracing: false,
        }),
        proxyConfiguration: EnvoySidecar.buildAppMeshProxy(80),
      },
    });

    const green = new AppMeshFargateService(mesh, `${this.stackName}GreenService`, {
      serviceName: mesh.serviceDiscovery.infra.serviceGreen,
      taskDefinitionFamily: mesh.serviceDiscovery.infra.serviceGreen,
      applicationContainer: new ApplicationContainer(mesh, `${this.stackName}GreenAppContainer`, {
        image: ecs.ContainerImage.fromDockerImageAsset(mesh.serviceDiscovery.infra.colorTellerImageAsset),
        logStreamPrefix: mesh.serviceDiscovery.infra.serviceGreen,
        env: {
          SERVER_PORT: "80",
          COLOR: "GREEN",
        },
        portMappings: [{ containerPort: 80, protocol: ecs.Protocol.TCP }],
      }),
      envoyConfiguration: {
        container: new EnvoySidecar(mesh, `${this.stackName}GreenEnvoySidecar`, {
          logStreamPrefix: "green-envoy",
          certificateName: "colorteller_green",
          appMeshResourceArn: mesh.virtualNodeGreen.virtualNodeArn,
          enableXrayTracing: false,
        }),
        proxyConfiguration: EnvoySidecar.buildAppMeshProxy(80),
      },
    });

    const gateway = new AppMeshFargateService(mesh, `${this.stackName}GatewayService`, {
      serviceName: mesh.serviceDiscovery.infra.serviceGateway,
      taskDefinitionFamily: mesh.serviceDiscovery.infra.serviceGateway,
      envoyConfiguration: {
        container: new EnvoySidecar(mesh, `${this.stackName}GatewayEnvoySidecar`, {
          logStreamPrefix: "gateway-envoy",
          certificateName: "colorgateway",
          appMeshResourceArn: mesh.virtualGateway.virtualGatewayArn,
          enableXrayTracing: false,
        }),
      },
    });

    gateway.node.addDependency(white);
    gateway.node.addDependency(green);


    const bastionIp = mesh.serviceDiscovery.infra.bastionHost.instancePublicIp;
    const url = mesh.serviceDiscovery.publicLoadBalancer.loadBalancerDnsName;

    new CfnOutput(this, "BastionIP", { value: mesh.serviceDiscovery.infra.bastionHost.instancePublicIp });
    new CfnOutput(this, "URL", { value: mesh.serviceDiscovery.publicLoadBalancer.loadBalancerDnsName });
  }
}
