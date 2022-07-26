import * as ecs from "aws-cdk-lib/aws-ecs";
import { StackProps, Stack, CfnOutput } from "aws-cdk-lib";
import { MeshStack } from "./mesh-components";
import { AppMeshFargateService } from "../constructs/appmesh-fargate-service";
import { EnvoySidecar } from "../constructs/envoy-sidecar";
import { XrayContainer } from "../constructs/xray-container";
import { ApplicationContainer } from "../constructs/application-container";

export class EcsServicesStack extends Stack {
  constructor(ms: MeshStack, id: string, props?: StackProps) {
    super(ms, id, props);

    const meshify = this.node.tryGetContext("meshify") === "true";

    // backend
    const backend = new AppMeshFargateService(ms, `${this.stackName}BackendV1AppMeshFargateService`, {
      serviceName: ms.sd.base.SERVICE_BACKEND,
      taskDefinitionFamily: ms.sd.base.SERVICE_BACKEND,
      envoyConfiguration: meshify
        ? {
            container: new EnvoySidecar(ms, `${this.stackName}BackendV1EnvoySidecar`, {
              logStreamPrefix: `${ms.sd.base.SERVICE_BACKEND}-envoy`,
              appMeshResourceArn: ms.backendV1VirtualNode.virtualNodeArn,
              enableXrayTracing: true,
            }),
            proxyConfiguration: EnvoySidecar.buildAppMeshProxy(ms.sd.base.PORT),
          }
        : undefined,

      xrayContainer: meshify
        ? new XrayContainer(ms, `${this.stackName}BackendV1XrayOpts`, {
            logStreamPrefix: `${ms.sd.base.SERVICE_BACKEND}-xray`,
          })
        : undefined,

      applicationContainer: new ApplicationContainer(ms, `${this.stackName}BackendV1AppOpts`, {
        image: ecs.ContainerImage.fromRegistry(this.node.tryGetContext("IMAGE_BACKEND")),
        logStreamPrefix: `${ms.sd.base.SERVICE_BACKEND}-app`,
        portMappings: [
          {
            containerPort: ms.sd.base.PORT,
            protocol: ecs.Protocol.TCP,
          },
        ],
      }),
    });

    // backend-1
    const backend1 = new AppMeshFargateService(ms, `${this.stackName}BackendV2AppMeshFargateService`, {
      serviceName: ms.sd.base.SERVICE_BACKEND_1,
      taskDefinitionFamily: ms.sd.base.SERVICE_BACKEND_1,
      envoyConfiguration: meshify
        ? {
            container: new EnvoySidecar(ms, `${this.stackName}BackendV2EnvoySidecar`, {
              logStreamPrefix: `${ms.sd.base.SERVICE_BACKEND_1}-envoy`,
              appMeshResourceArn: ms.backendV2VirtualNode.virtualNodeArn,
              enableXrayTracing: true,
            }),
            proxyConfiguration: EnvoySidecar.buildAppMeshProxy(ms.sd.base.PORT),
          }
        : undefined,

      xrayContainer: meshify
        ? new XrayContainer(ms, `${this.stackName}BackendV2XrayOpts`, {
            logStreamPrefix: `${ms.sd.base.SERVICE_BACKEND_1}-xray`,
          })
        : undefined,
      applicationContainer: new ApplicationContainer(ms, `${this.stackName}BackendV2AppOpts`, {
        image: ecs.ContainerImage.fromRegistry(this.node.tryGetContext("IMAGE_BACKEND_1")),
        logStreamPrefix: `${ms.sd.base.SERVICE_BACKEND_1}-app`,
        portMappings: [
          {
            containerPort: ms.sd.base.PORT,
            protocol: ecs.Protocol.TCP,
          },
        ],
      }),
    });

    // frontend
    const frontend = new AppMeshFargateService(ms, `${this.stackName}FrontendAppMeshFargateService`, {
      serviceName: ms.sd.base.SERVICE_FRONTEND,
      taskDefinitionFamily: ms.sd.base.SERVICE_FRONTEND,
      envoyConfiguration: meshify
        ? {
            container: new EnvoySidecar(ms, `${this.stackName}FrontendEnvoySidecar`, {
              logStreamPrefix: `${ms.sd.base.SERVICE_FRONTEND}-envoy`,
              appMeshResourceArn: ms.frontendVirtualNode.virtualNodeArn,
              enableXrayTracing: true,
            }),
            proxyConfiguration: EnvoySidecar.buildAppMeshProxy(ms.sd.base.PORT),
          }
        : undefined,

      xrayContainer: meshify
        ? new XrayContainer(ms, `${this.stackName}FrontendXrayOpts`, {
            logStreamPrefix: `${ms.sd.base.SERVICE_FRONTEND}-xray`,
          })
        : undefined,
      applicationContainer: new ApplicationContainer(ms, `${this.stackName}AppOpts`, {
        image: ecs.ContainerImage.fromRegistry(this.node.tryGetContext("IMAGE_FRONTEND")),
        logStreamPrefix: `${ms.sd.base.SERVICE_FRONTEND}-app`,
        portMappings: [{ containerPort: ms.sd.base.PORT, protocol: ecs.Protocol.TCP }],
      }),
    });

    frontend.service.node.addDependency(backend.service);
    frontend.service.node.addDependency(backend1.service);
  }
}
