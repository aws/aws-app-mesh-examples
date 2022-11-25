import * as ecs from "aws-cdk-lib/aws-ecs";
import { StackProps, Stack } from "aws-cdk-lib";
import { MeshStack } from "./mesh-components";
import { AppMeshFargateService } from "../constructs/appmesh-fargate-service";
import { EnvoySidecar } from "../constructs/envoy-sidecar";
import { XrayContainer } from "../constructs/xray-container";
import { ApplicationContainer } from "../constructs/application-container";

export class EcsServicesStack extends Stack {
  constructor(mesh: MeshStack, id: string, props?: StackProps) {
    super(mesh, id, props);

    const meshify = this.node.tryGetContext("meshify") === "true";

    // backend
    const backend = new AppMeshFargateService(mesh, `${this.stackName}BackendV1AppMeshFargateService`, {
      serviceName: mesh.serviceDiscovery.base.serviceBackend,
      taskDefinitionFamily: mesh.serviceDiscovery.base.serviceBackend,
      envoyConfiguration: meshify
        ? {
            container: new EnvoySidecar(mesh, `${this.stackName}BackendV1EnvoySidecar`, {
              logStreamPrefix: `${mesh.serviceDiscovery.base.serviceBackend}-envoy`,
              appMeshResourceArn: mesh.backendV1VirtualNode.virtualNodeArn,
              enableXrayTracing: true,
            }),
            proxyConfiguration: EnvoySidecar.buildAppMeshProxy(mesh.serviceDiscovery.base.port),
          }
        : undefined,

      xrayContainer: meshify
        ? new XrayContainer(mesh, `${this.stackName}BackendV1XrayOpts`, {
            logStreamPrefix: `${mesh.serviceDiscovery.base.serviceBackend}-xray`,
          })
        : undefined,

      applicationContainer: new ApplicationContainer(mesh, `${this.stackName}BackendV1AppOpts`, {
        image: ecs.ContainerImage.fromRegistry(this.node.tryGetContext("IMAGE_BACKEND")),
        logStreamPrefix: `${mesh.serviceDiscovery.base.serviceBackend}-app`,
        portMappings: [
          {
            containerPort: mesh.serviceDiscovery.base.port,
            protocol: ecs.Protocol.TCP,
          },
        ],
      }),
    });

    // backend-1
    const backend1 = new AppMeshFargateService(mesh, `${this.stackName}BackendV2AppMeshFargateService`, {
      serviceName: mesh.serviceDiscovery.base.serviceBackend1,
      taskDefinitionFamily: mesh.serviceDiscovery.base.serviceBackend1,
      envoyConfiguration: meshify
        ? {
            container: new EnvoySidecar(mesh, `${this.stackName}BackendV2EnvoySidecar`, {
              logStreamPrefix: `${mesh.serviceDiscovery.base.serviceBackend1}-envoy`,
              appMeshResourceArn: mesh.backendV2VirtualNode.virtualNodeArn,
              enableXrayTracing: true,
            }),
            proxyConfiguration: EnvoySidecar.buildAppMeshProxy(mesh.serviceDiscovery.base.port),
          }
        : undefined,

      xrayContainer: meshify
        ? new XrayContainer(mesh, `${this.stackName}BackendV2XrayOpts`, {
            logStreamPrefix: `${mesh.serviceDiscovery.base.serviceBackend1}-xray`,
          })
        : undefined,
      applicationContainer: new ApplicationContainer(mesh, `${this.stackName}BackendV2AppOpts`, {
        image: ecs.ContainerImage.fromRegistry(this.node.tryGetContext("IMAGE_BACKEND_1")),
        logStreamPrefix: `${mesh.serviceDiscovery.base.serviceBackend1}-app`,
        portMappings: [
          {
            containerPort: mesh.serviceDiscovery.base.port,
            protocol: ecs.Protocol.TCP,
          },
        ],
      }),
    });

    // frontend
    const frontend = new AppMeshFargateService(mesh, `${this.stackName}FrontendAppMeshFargateService`, {
      serviceName: mesh.serviceDiscovery.base.serviceFrontend,
      taskDefinitionFamily: mesh.serviceDiscovery.base.serviceFrontend,
      envoyConfiguration: meshify
        ? {
            container: new EnvoySidecar(mesh, `${this.stackName}FrontendEnvoySidecar`, {
              logStreamPrefix: `${mesh.serviceDiscovery.base.serviceFrontend}-envoy`,
              appMeshResourceArn: mesh.frontendVirtualNode.virtualNodeArn,
              enableXrayTracing: true,
            }),
            proxyConfiguration: EnvoySidecar.buildAppMeshProxy(mesh.serviceDiscovery.base.port),
          }
        : undefined,

      xrayContainer: meshify
        ? new XrayContainer(mesh, `${this.stackName}FrontendXrayOpts`, {
            logStreamPrefix: `${mesh.serviceDiscovery.base.serviceFrontend}-xray`,
          })
        : undefined,
      applicationContainer: new ApplicationContainer(mesh, `${this.stackName}AppOpts`, {
        image: ecs.ContainerImage.fromRegistry(this.node.tryGetContext("IMAGE_FRONTEND")),
        logStreamPrefix: `${mesh.serviceDiscovery.base.serviceFrontend}-app`,
        portMappings: [{ containerPort: mesh.serviceDiscovery.base.port, protocol: ecs.Protocol.TCP }],
      }),
    });

    frontend.service.node.addDependency(backend.service);
    frontend.service.node.addDependency(backend1.service);
  }
}
