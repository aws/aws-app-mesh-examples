import * as appmesh from "aws-cdk-lib/aws-appmesh";
import { Stack, StackProps } from "aws-cdk-lib";
import { ServiceDiscoveryStack } from "./service-discovery";

export class MeshStack extends Stack {
  mesh: appmesh.Mesh;
  virtualNodeListender: appmesh.VirtualNodeListener;

  backendV1VirtualNode: appmesh.VirtualNode;
  backendV2VirtualNode: appmesh.VirtualNode;
  backendVirtualRouter: appmesh.VirtualRouter;
  backendVirtualService: appmesh.VirtualService;
  backendRoute: appmesh.Route;

  frontendVirtualNode: appmesh.VirtualNode;
  frontendVirtualService: appmesh.VirtualService;

  sd: ServiceDiscoveryStack;

  constructor(sd: ServiceDiscoveryStack, id: string, props?: StackProps) {
    super(sd, id, props);

    this.sd = sd;

    this.mesh = new appmesh.Mesh(this, `${this.stackName}Mesh`, { meshName: sd.base.PROJECT_NAME });

    this.virtualNodeListender = appmesh.VirtualNodeListener.http({
      port: this.sd.base.PORT,
    });

    this.backendV1VirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackName}BackendV1VirtualNode`,
      this.buildVirtualNodeProps(this.sd.base.SERVICE_BACKEND_V1)
    );

    this.backendV2VirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackName}BackendV2VirtualNode`,
      this.buildVirtualNodeProps(this.sd.base.SERVICE_BACKEND_V2)
    );

    this.backendVirtualRouter = new appmesh.VirtualRouter(this, `${this.stackName}BackendVirtualRouter`, {
      mesh: this.mesh,
      virtualRouterName: `${this.sd.base.PROJECT_NAME}-backend-router`,
      listeners: [this.virtualNodeListender],
    });

    this.backendVirtualService = new appmesh.VirtualService(this, `${this.stackName}BackendVirtualService`, {
      virtualServiceProvider: appmesh.VirtualServiceProvider.virtualRouter(this.backendVirtualRouter),
      virtualServiceName: `backend.${this.sd.base.dnsHostedZone.zoneName}`,
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
      routeName: `${this.sd.base.PROJECT_NAME}-backend-route`,
      routeSpec: routeSpec,
    });

    this.frontendVirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackName}FrontendVirtualNode`,
      this.buildVirtualNodeProps(this.sd.base.SERVICE_FRONTEND)
    );
    this.frontendVirtualNode.addBackend(appmesh.Backend.virtualService(this.backendVirtualService));
  }

  private buildVirtualNodeProps = (serviceName: string): appmesh.VirtualNodeProps => {
    return {
      mesh: this.mesh,
      virtualNodeName: `${this.sd.base.PROJECT_NAME}-${serviceName}-node`,
      listeners: [this.virtualNodeListender],
      serviceDiscovery: this.sd.getServiceDiscovery(serviceName),
    };
  };
}
