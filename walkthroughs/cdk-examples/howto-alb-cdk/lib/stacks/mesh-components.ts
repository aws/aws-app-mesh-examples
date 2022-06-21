import * as appmesh from "aws-cdk-lib/aws-appmesh";
import { Stack, StackProps } from "aws-cdk-lib";
import { ServiceDiscoveryStack } from "./service-discovery";

export class MeshStack extends Stack {
  //readonly mesh: appmesh.Mesh;
  virtualNodeListender: appmesh.VirtualNodeListener;
  backendV1VirtualNode: appmesh.VirtualNode;
  backendV2VirtualNode: appmesh.VirtualNode;
  backendVirtualRouter: appmesh.VirtualRouter;
  backendVirtualService: appmesh.VirtualService;
  backendRoute: appmesh.Route;

  frontendVirtualNode: appmesh.VirtualNode;
  frontendVirtualService: appmesh.VirtualService;

  sd: ServiceDiscoveryStack;
  prefix: string = "Mesh";

  constructor(sd: ServiceDiscoveryStack, id: string, props?: StackProps) {
    super(sd, id, props);

    this.sd = sd;

    this.virtualNodeListender = appmesh.VirtualNodeListener.http({
      port: this.sd.base.containerPort,
    });

    this.backendV1VirtualNode = new appmesh.VirtualNode(
      this,
      `${this.prefix}BackendV1VirtualNode`,
      {
        mesh: this.sd.base.mesh,
        virtualNodeName: `${this.sd.base.projectName}-backend-v1-node`,
        listeners: [this.virtualNodeListender],
        serviceDiscovery: appmesh.ServiceDiscovery.dns(
          sd.backendV1LoadBalancer.loadBalancerDnsName
        ),
      }
    );

    this.backendV2VirtualNode = new appmesh.VirtualNode(
      this,
      `${this.prefix}BackendV2VirtualNode`,
      {
        mesh: this.sd.base.mesh,
        virtualNodeName: `${this.sd.base.projectName}-backend-v2-node`,
        listeners: [this.virtualNodeListender],
        serviceDiscovery: appmesh.ServiceDiscovery.cloudMap(sd.backendV2CloudMapService, {
          ECS_TASK_DEFINITION_FAMILY: "green",
        }),
      }
    );

    this.backendVirtualRouter = new appmesh.VirtualRouter(
      this,
      `${this.prefix}BackendVirtualRouter`,
      {
        mesh: this.sd.base.mesh,
        virtualRouterName: `${this.sd.base.projectName}-backend-router`,
        listeners: [this.virtualNodeListender],
      }
    );

    this.backendVirtualService = new appmesh.VirtualService(
      this,
      `${this.prefix}BackendVirtualService`,
      {
        virtualServiceProvider: appmesh.VirtualServiceProvider.virtualRouter(
          this.backendVirtualRouter
        ),
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

    this.backendRoute = new appmesh.Route(this, `${this.prefix}BackendRoute`, {
      mesh: this.sd.base.mesh,
      virtualRouter: this.backendVirtualRouter,
      routeName: `${this.sd.base.projectName}-backend-route`,
      routeSpec: routeSpec,
    });
    this.backendRoute.node.addDependency(this.backendVirtualRouter);
    this.backendRoute.node.addDependency(this.backendV1VirtualNode);
    this.backendRoute.node.addDependency(this.backendV2VirtualNode);

    this.frontendVirtualNode = new appmesh.VirtualNode(
      this,
      `${this.prefix}FrontendVirtualNode`,
      {
        mesh: this.sd.base.mesh,
        virtualNodeName: `${this.sd.base.projectName}-front-node`,
        listeners: [this.virtualNodeListender],
        serviceDiscovery: appmesh.ServiceDiscovery.dns(
          sd.frontendLoadBalancer.loadBalancerDnsName
        ),
      }
    );
    this.frontendVirtualNode.addBackend(
      appmesh.Backend.virtualService(this.backendVirtualService)
    );
    this.frontendVirtualNode.node.addDependency(this.backendVirtualService);
  }
}
