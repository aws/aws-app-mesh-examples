import * as appmesh from "aws-cdk-lib/aws-appmesh";
import { Stack, StackProps } from "aws-cdk-lib";
import { ServiceDiscoveryStack } from "./service-discovery";

export class MeshStack extends Stack {
  readonly mesh: appmesh.Mesh;
  readonly virtualNodeListender: appmesh.VirtualNodeListener;

  readonly backendV1VirtualNode: appmesh.VirtualNode;
  readonly backendV2VirtualNode: appmesh.VirtualNode;
  readonly backendVirtualRouter: appmesh.VirtualRouter;
  readonly backendVirtualService: appmesh.VirtualService;
  readonly backendRoute: appmesh.Route;

  readonly frontendVirtualNode: appmesh.VirtualNode;
  readonly frontendVirtualService: appmesh.VirtualService;

  readonly serviceDiscovery: ServiceDiscoveryStack;

  constructor(serviceDiscovery: ServiceDiscoveryStack, id: string, props?: StackProps) {
    super(serviceDiscovery, id, props);

    this.serviceDiscovery = serviceDiscovery;

    this.mesh = new appmesh.Mesh(this, `${this.stackName}Mesh`, { meshName: serviceDiscovery.base.projectName });

    this.virtualNodeListender = appmesh.VirtualNodeListener.http({
      port: this.serviceDiscovery.base.port,
    });

    this.backendV1VirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackName}BackendV1VirtualNode`,
      this.buildVirtualNodeProps(this.serviceDiscovery.base.serviceBackend1)
    );

    this.backendV2VirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackName}BackendV2VirtualNode`,
      this.buildVirtualNodeProps(this.serviceDiscovery.base.serviceBackend2)
    );

    this.backendVirtualRouter = new appmesh.VirtualRouter(this, `${this.stackName}BackendVirtualRouter`, {
      mesh: this.mesh,
      virtualRouterName: `${this.serviceDiscovery.base.projectName}-backend-router`,
      listeners: [this.virtualNodeListender],
    });

    this.backendVirtualService = new appmesh.VirtualService(this, `${this.stackName}BackendVirtualService`, {
      virtualServiceProvider: appmesh.VirtualServiceProvider.virtualRouter(this.backendVirtualRouter),
      virtualServiceName: `backend.${this.serviceDiscovery.base.dnsHostedZone.zoneName}`,
    });

    const routeSpec = appmesh.RouteSpec.http({
      match: { path: appmesh.HttpRoutePathMatch.startsWith("/") },
      weightedTargets: [
        {
          virtualNode: this.backendV1VirtualNode,
          weight: 50,
        },
        {
          virtualNode: this.backendV2VirtualNode,
          weight: 50,
        },
      ],
    });

    this.backendRoute = new appmesh.Route(this, `${this.stackName}BackendRoute`, {
      mesh: this.mesh,
      virtualRouter: this.backendVirtualRouter,
      routeName: `${this.serviceDiscovery.base.projectName}-backend-route`,
      routeSpec: routeSpec,
    });

    this.frontendVirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackName}FrontendVirtualNode`,
      this.buildVirtualNodeProps(this.serviceDiscovery.base.serviceFrontend)
    );
    this.frontendVirtualNode.addBackend(appmesh.Backend.virtualService(this.backendVirtualService));
  }

  private buildVirtualNodeProps = (serviceName: string): appmesh.VirtualNodeProps => {
    return {
      mesh: this.mesh,
      virtualNodeName: `${this.serviceDiscovery.base.projectName}-${serviceName}-node`,
      listeners: [this.virtualNodeListender],
      serviceDiscovery: this.serviceDiscovery.getServiceDiscovery(serviceName),
    };
  };
}
