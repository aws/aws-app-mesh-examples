import * as ecs from "aws-cdk-lib/aws-ecs";
import { StackProps, Stack, CfnOutput } from "aws-cdk-lib";
import { MeshStack } from "./mesh-components";
import { AppMeshFargateService } from "../constructs/appmesh-fargate-service";
import { EnvoySidecar } from "../constructs/envoy-sidecar";
import { XrayContainer } from "../constructs/xray-container";
import { ServiceDiscoveryType } from "../utils";
import { ApplicationContainer } from "../constructs/application-container";

export class ECSServicesStack extends Stack {
  constructor(mesh: MeshStack, id: string, props?: StackProps) {
    super(mesh, id, props);

    // backend-v1
    new AppMeshFargateService(mesh, "BackendV1AppMeshFargateService", {
      serviceName: mesh.serviceDiscovery.base.serviceBackend1,
      serviceDiscoveryType: ServiceDiscoveryType.DNS,
      taskDefinitionFamily: "blue",

      xrayContainer: new XrayContainer(mesh, "BackendV1XrayOpts", {
        logStreamPrefix: `${mesh.serviceDiscovery.base.serviceBackend1}-xray`,
      }),

      // Containers
      applicationContainer: new ApplicationContainer(mesh, "BackendV1AppOpts", {
        image: ecs.ContainerImage.fromDockerImageAsset(mesh.serviceDiscovery.base.backendAppImageAsset),
        env: {
          COLOR: "blue",
          PORT: `${mesh.serviceDiscovery.base.port}`,
          XRAY_APP_NAME: `${mesh.mesh.meshName}/${mesh.backendV1VirtualNode.virtualNodeName}`,
        },
        portMappings: [
          {
            containerPort: mesh.serviceDiscovery.base.port,
            hostPort: mesh.serviceDiscovery.base.port,
            protocol: ecs.Protocol.TCP,
          },
        ],
        logStreamPrefix: `${mesh.serviceDiscovery.base.serviceBackend1}-app`,
      }),
    });

    // backend-v2
    new AppMeshFargateService(mesh, "BackendV2AppMeshFargateService", {
      serviceName: mesh.serviceDiscovery.base.serviceBackend2,
      serviceDiscoveryType: ServiceDiscoveryType.CLOUDMAP,
      taskDefinitionFamily: "green",
      // Containers
      envoyConfiguration: {
        container: new EnvoySidecar(mesh, `${this.stackName}BackendV2EnvoySidecar`, {
          logStreamPrefix: `${mesh.serviceDiscovery.base.serviceBackend2}-envoy`,
          appMeshResourceArn: mesh.backendV2VirtualNode.virtualNodeArn,
          enableXrayTracing: true,
        }),
        proxyConfiguration: EnvoySidecar.buildAppMeshProxy(mesh.serviceDiscovery.base.port),
      },

      xrayContainer: new XrayContainer(mesh, "BackendV2AppMeshXrayOpts", {
        logStreamPrefix: `${mesh.serviceDiscovery.base.serviceBackend2}-xray`,
      }),

      applicationContainer: new ApplicationContainer(mesh, "BackendV2AppOpts", {
        image: ecs.ContainerImage.fromDockerImageAsset(mesh.serviceDiscovery.base.backendAppImageAsset),
        env: {
          COLOR: "green",
          PORT: `${mesh.serviceDiscovery.base.port}`,
          XRAY_APP_NAME: `${mesh.mesh.meshName}/${mesh.backendV2VirtualNode.virtualNodeName}`,
        },
        portMappings: [
          {
            containerPort: mesh.serviceDiscovery.base.port,
            hostPort: mesh.serviceDiscovery.base.port,
            protocol: ecs.Protocol.TCP,
          },
        ],
        logStreamPrefix: `${mesh.serviceDiscovery.base.serviceBackend2}-app`,
      }),
    });

    // frontend
    new AppMeshFargateService(mesh, "FrontendAppMeshFargateService", {
      serviceName: mesh.serviceDiscovery.base.serviceFrontend,
      serviceDiscoveryType: ServiceDiscoveryType.DNS,
      taskDefinitionFamily: "front",

      // Containers
      envoyConfiguration: {
        container: new EnvoySidecar(mesh, `${this.stackName}FrontendEnvoySidecar`, {
          logStreamPrefix: `${mesh.serviceDiscovery.base.serviceFrontend}-envoy`,
          appMeshResourceArn: mesh.frontendVirtualNode.virtualNodeArn,
          enableXrayTracing: true,
        }),
        proxyConfiguration: EnvoySidecar.buildAppMeshProxy(mesh.serviceDiscovery.base.port),
      },

      xrayContainer: new XrayContainer(mesh, "FrontendXrayOpts", {
        logStreamPrefix: `${mesh.serviceDiscovery.base.serviceFrontend}-xray`,
      }),

      applicationContainer: new ApplicationContainer(mesh, "FrontendAppOpts", {
        image: ecs.ContainerImage.fromDockerImageAsset(mesh.serviceDiscovery.base.frontendAppImageAsset),
        logStreamPrefix: `${mesh.serviceDiscovery.base.serviceFrontend}-app`,
        env: {
          COLOR_HOST: `${mesh.backendVirtualService.virtualServiceName}:${mesh.serviceDiscovery.base.port}`,
          PORT: `${mesh.serviceDiscovery.base.port}`,
          XRAY_APP_NAME: `${mesh.mesh.meshName}/${mesh.frontendVirtualNode.virtualNodeName}`,
        },
        portMappings: [{ containerPort: mesh.serviceDiscovery.base.port, protocol: ecs.Protocol.TCP }],
      }),
    });

    new CfnOutput(this, "URL", {
      value: mesh.serviceDiscovery.frontendLoadBalancer.loadBalancerDnsName,
      description: "Public endpoint to query the frontend load balancer",
      exportName: "FrontendURL",
    });
  }
}
