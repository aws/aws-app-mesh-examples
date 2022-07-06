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
  readonly stackIdentifier: string = "MeshStack";

  constructor(sd: ServiceDiscoveryStack, id: string, props?: StackProps) {
    super(sd, id, props);

    this.sd = sd;

    this.mesh = new appmesh.Mesh(this, `${this.stackIdentifier}_Mesh`, { meshName: sd.base.projectName });

    this.virtualNodeListender = appmesh.VirtualNodeListener.http({
      port: this.sd.base.containerPort,
    });

    this.backendV1VirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackIdentifier}_BackendV1VirtualNode`,
      this.buildVirtualNodeProps(this.sd.base.SERVICE_BACKEND_V1)
    );

    this.backendV2VirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackIdentifier}_BackendV2VirtualNode`,
      this.buildVirtualNodeProps(this.sd.base.SERVICE_BACKEND_V2)
    );

    this.backendVirtualRouter = new appmesh.VirtualRouter(
      this,
      `${this.stackIdentifier}_BackendVirtualRouter`,
      {
        mesh: this.mesh,
        virtualRouterName: `${this.sd.base.projectName}-backend-router`,
        listeners: [this.virtualNodeListender],
      }
    );

    this.backendVirtualService = new appmesh.VirtualService(
      this,
      `${this.stackIdentifier}_BackendVirtualService`,
      {
        virtualServiceProvider: appmesh.VirtualServiceProvider.virtualRouter(this.backendVirtualRouter),
        virtualServiceName: `backend.${this.sd.base.dnsHostedZone.zoneName}`,
      }
    );

    this.backendVirtualService.node.addDependency(this.backendVirtualRouter);

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

    this.backendRoute = new appmesh.Route(this, `${this.stackIdentifier}_BackendRoute`, {
      mesh: this.mesh,
      virtualRouter: this.backendVirtualRouter,
      routeName: `${this.sd.base.projectName}-backend-route`,
      routeSpec: routeSpec,
    });
    this.backendRoute.node.addDependency(this.backendVirtualRouter);
    this.backendRoute.node.addDependency(this.backendV1VirtualNode);
    this.backendRoute.node.addDependency(this.backendV2VirtualNode);

    this.frontendVirtualNode = new appmesh.VirtualNode(
      this,
      `${this.stackIdentifier}_FrontendVirtualNode`,
      this.buildVirtualNodeProps(this.sd.base.SERVICE_FRONTEND)
    );
    this.frontendVirtualNode.addBackend(appmesh.Backend.virtualService(this.backendVirtualService));
    this.frontendVirtualNode.node.addDependency(this.backendVirtualService);
  }

  private buildVirtualNodeProps = (serviceName: string): appmesh.VirtualNodeProps => {
    return {
      mesh: this.mesh,
      virtualNodeName: `${this.sd.base.projectName}-${serviceName}-node`,
      listeners: [this.virtualNodeListender],
      serviceDiscovery: this.sd.getServiceDiscovery(serviceName),
    };
  };
}
