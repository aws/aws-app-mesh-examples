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

    this.mesh = new appmesh.Mesh(this, `${this.stackName}Mesh`, { meshName: sd.base.MESH_NAME });

    this.virtualNodeListender = appmesh.VirtualNodeListener.http({
      port: 80,
    });

    this.backendV1VirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackName}BackendV1VirtualNode`,
      this.buildVirtualNodeProps(this.sd.base.SERVICE_BACKEND)
    );

    this.backendV2VirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackName}BackendV2VirtualNode`,
      this.buildVirtualNodeProps(this.sd.base.SERVICE_BACKEND_1)
    );

    this.frontendVirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackName}FrontendVirtualNode`,
      this.buildVirtualNodeProps(this.sd.base.SERVICE_FRONTEND)
    );

    this.backendVirtualRouter = new appmesh.VirtualRouter(this, `${this.stackName}BackendVirtualRouter`, {
      mesh: this.mesh,
      virtualRouterName: `backend-vr`,
      listeners: [this.virtualNodeListender],
    });

    this.backendVirtualService = new appmesh.VirtualService(this, `${this.stackName}BackendVirtualService`, {
      virtualServiceProvider: appmesh.VirtualServiceProvider.virtualRouter(this.backendVirtualRouter),
      virtualServiceName: "backend.local",
    });

    const routeSpec = appmesh.RouteSpec.http({
      match: { path: appmesh.HttpRoutePathMatch.startsWith("/") },
      weightedTargets: [
        {
          virtualNode: this.backendV1VirtualNode,
          weight: 1,
        },
        {
          virtualNode: this.backendV2VirtualNode,
          weight: 1,
        },
      ],
    });

    this.backendRoute = new appmesh.Route(this, `${this.stackName}BackendRoute`, {
      mesh: this.mesh,
      virtualRouter: this.backendVirtualRouter,
      routeName: `backend-route`,
      routeSpec: routeSpec,
    });

    this.frontendVirtualNode.addBackend(appmesh.Backend.virtualService(this.backendVirtualService));
  }

  private buildVirtualNodeProps = (serviceName: string): appmesh.VirtualNodeProps => {
    return {
      mesh: this.mesh,
      virtualNodeName: `${serviceName}-vn`,
      listeners: [this.virtualNodeListender],
      serviceDiscovery: this.sd.getAppMeshServiceDiscovery(serviceName),
    };
  };
}
