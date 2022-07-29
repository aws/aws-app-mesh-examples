import * as ecs from "aws-cdk-lib/aws-ecs";
import { StackProps, Stack, CfnOutput } from "aws-cdk-lib";
import { MeshStack } from "./mesh-components";
import { AppMeshFargateService } from "../constructs/appmesh-fargate-service";
import { EnvoySidecar } from "../constructs/envoy-sidecar";
import { ApplicationContainer } from "../constructs/application-container";

export class EcsServicesStack extends Stack {
  constructor(mesh: MeshStack, id: string, props?: StackProps) {
    super(mesh, id, props);

    const colorTeller = new AppMeshFargateService(mesh, `${this.stackName}WhiteService`, {
      serviceName: mesh.serviceDiscovery.infra.serviceColorTeller,
      taskDefinitionFamily: mesh.serviceDiscovery.infra.serviceColorTeller,
      applicationContainer: new ApplicationContainer(mesh, `${this.stackName}WhiteAppContainer`, {
        image: ecs.ContainerImage.fromDockerImageAsset(mesh.serviceDiscovery.infra.colorTellerImageAsset),
        logStreamPrefix: mesh.serviceDiscovery.infra.serviceColorTeller,
        env: {
          SERVER_PORT: "9080",
          COLOR: "WHITE",
        },
        portMappings: [{ containerPort: 9080, protocol: ecs.Protocol.TCP }],
      }),
      envoyConfiguration: {
        container: new EnvoySidecar(mesh, `${this.stackName}WhiteEnvoySidecar`, {
          logStreamPrefix: "white-envoy",
          appMeshResourceArn: mesh.virtualNode.virtualNodeArn,
        }),
        proxyConfiguration: EnvoySidecar.buildAppMeshProxy(9080),
      },
    });

    const gateway = new AppMeshFargateService(mesh, `${this.stackName}GatewayService`, {
      serviceName: mesh.serviceDiscovery.infra.serviceGateway,
      taskDefinitionFamily: mesh.serviceDiscovery.infra.serviceGateway,
      envoyConfiguration: {
        container: new EnvoySidecar(mesh, `${this.stackName}GatewayEnvoySidecar`, {
          logStreamPrefix: "gateway-envoy",
          appMeshResourceArn: mesh.virtualGateway.virtualGatewayArn,
          enableXrayTracing: false,
        }),
      },
    });

    gateway.node.addDependency(colorTeller);

    new CfnOutput(this, "BastionIP", { value: mesh.serviceDiscovery.infra.bastionHost.instancePublicIp });
    new CfnOutput(this, "URL", { value: mesh.serviceDiscovery.publicLoadBalancer.loadBalancerDnsName });
  }
}
