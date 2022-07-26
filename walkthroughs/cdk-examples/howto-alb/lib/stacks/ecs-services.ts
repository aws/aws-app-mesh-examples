import * as ecs from "aws-cdk-lib/aws-ecs";
import { StackProps, Stack, CfnOutput } from "aws-cdk-lib";
import { MeshStack } from "./mesh-components";
import { AppMeshFargateService } from "../constructs/appmesh-fargate-service";
import { EnvoySidecar } from "../constructs/envoy-sidecar";
import { XrayContainer } from "../constructs/xray-container";
import { ServiceDiscoveryType } from "../utils";
import { ApplicationContainer } from "../constructs/application-container";

export class ECSServicesStack extends Stack {
  constructor(ms: MeshStack, id: string, props?: StackProps) {
    super(ms, id, props);

    // backend-v1
    new AppMeshFargateService(ms, "BackendV1AppMeshFargateService", {
      serviceName: ms.sd.base.SERVICE_BACKEND_V1,
      serviceDiscoveryType: ServiceDiscoveryType.DNS,
      taskDefinitionFamily: "blue",

      xrayContainer: new XrayContainer(ms, "BackendV1XrayOpts", {
        logStreamPrefix: `${ms.sd.base.SERVICE_BACKEND_V1}-xray`,
      }),

      // Containers
      applicationContainer: new ApplicationContainer(ms, "BackendV1AppOpts", {
        image: ecs.ContainerImage.fromDockerImageAsset(ms.sd.base.backendAppImageAsset),
        env: {
          COLOR: "blue",
          PORT: `${ms.sd.base.PORT}`,
          XRAY_APP_NAME: `${ms.mesh.meshName}/${ms.backendV1VirtualNode.virtualNodeName}`,
        },
        portMappings: [
          {
            containerPort: ms.sd.base.PORT,
            hostPort: ms.sd.base.PORT,
            protocol: ecs.Protocol.TCP,
          },
        ],
        logStreamPrefix: `${ms.sd.base.SERVICE_BACKEND_V1}-app`,
      }),
    });

    // backend-v2
    new AppMeshFargateService(ms, "BackendV2AppMeshFargateService", {
      serviceName: ms.sd.base.SERVICE_BACKEND_V2,
      serviceDiscoveryType: ServiceDiscoveryType.CLOUDMAP,
      taskDefinitionFamily: "green",
      // Containers
      envoyConfiguration: {
        container: new EnvoySidecar(ms, `${this.stackName}BackendV2EnvoySidecar`, {
          logStreamPrefix: `${ms.sd.base.SERVICE_BACKEND_V2}-envoy`,
          appMeshResourceArn: ms.backendV2VirtualNode.virtualNodeArn,
          enableXrayTracing: true,
        }),
        proxyConfiguration: EnvoySidecar.buildAppMeshProxy(ms.sd.base.PORT),
      },

      xrayContainer: new XrayContainer(ms, "BackendV2AppMeshXrayOpts", {
        logStreamPrefix: `${ms.sd.base.SERVICE_BACKEND_V2}-xray`,
      }),

      applicationContainer: new ApplicationContainer(ms, "BackendV2AppOpts", {
        image: ecs.ContainerImage.fromDockerImageAsset(ms.sd.base.backendAppImageAsset),
        env: {
          COLOR: "green",
          PORT: `${ms.sd.base.PORT}`,
          XRAY_APP_NAME: `${ms.mesh.meshName}/${ms.backendV2VirtualNode.virtualNodeName}`,
        },
        portMappings: [
          {
            containerPort: ms.sd.base.PORT,
            hostPort: ms.sd.base.PORT,
            protocol: ecs.Protocol.TCP,
          },
        ],
        logStreamPrefix: `${ms.sd.base.SERVICE_BACKEND_V2}-app`,
      }),
    });

    // frontend
    new AppMeshFargateService(ms, "FrontendAppMeshFargateService", {
      serviceName: ms.sd.base.SERVICE_FRONTEND,
      serviceDiscoveryType: ServiceDiscoveryType.DNS,
      taskDefinitionFamily: "front",

      // Containers
      envoyConfiguration: {
        container: new EnvoySidecar(ms, `${this.stackName}FrontendEnvoySidecar`, {
          logStreamPrefix: `${ms.sd.base.SERVICE_FRONTEND}-envoy`,
          appMeshResourceArn: ms.frontendVirtualNode.virtualNodeArn,
          enableXrayTracing: true,
        }),
        proxyConfiguration: EnvoySidecar.buildAppMeshProxy(ms.sd.base.PORT),
      },

      xrayContainer: new XrayContainer(ms, "FrontendXrayOpts", {
        logStreamPrefix: `${ms.sd.base.SERVICE_FRONTEND}-xray`,
      }),

      applicationContainer: new ApplicationContainer(ms, "FrontendAppOpts", {
        image: ecs.ContainerImage.fromDockerImageAsset(ms.sd.base.frontendAppImageAsset),
        logStreamPrefix: `${ms.sd.base.SERVICE_FRONTEND}-app`,
        env: {
          COLOR_HOST: `${ms.backendVirtualService.virtualServiceName}:${ms.sd.base.PORT}`,
          PORT: `${ms.sd.base.PORT}`,
          XRAY_APP_NAME: `${ms.mesh.meshName}/${ms.frontendVirtualNode.virtualNodeName}`,
        },
        portMappings: [{ containerPort: ms.sd.base.PORT, protocol: ecs.Protocol.TCP }],
      }),
    });

    new CfnOutput(this, "URL", {
      value: ms.sd.frontendLoadBalancer.loadBalancerDnsName,
      description: "Public endpoint to query the frontend load balancer",
      exportName: "FrontendURL",
    });
  }
}
