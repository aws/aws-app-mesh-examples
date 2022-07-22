import * as appmesh from "aws-cdk-lib/aws-appmesh";
import { StackProps, Stack } from "aws-cdk-lib";
import { ServiceDiscoveryStack } from "./service-discovery";
import { MeshUpdateChoices } from "../utils";

export class MeshStack extends Stack {
  serviceDiscovery: ServiceDiscoveryStack;
  mesh: appmesh.Mesh;

  virtualNodeWhite: appmesh.VirtualNode;
  virtualNodeGreen: appmesh.VirtualNode;

  virtualGateway: appmesh.VirtualGateway;

  virtualRouter: appmesh.VirtualRouter;
  route: appmesh.Route;

  virtualService: appmesh.VirtualService;

  constructor(serviceDiscovery: ServiceDiscoveryStack, id: string, props?: StackProps) {
    super(serviceDiscovery, id, props);

    this.serviceDiscovery = serviceDiscovery;

    const meshUpdate = this.node.tryGetContext("meshupdate");

    this.mesh = new appmesh.Mesh(this, `${this.stackName}Mesh`, {
      meshName: this.node.tryGetContext("MESH_NAME"),
    });

    this.virtualGateway = new appmesh.VirtualGateway(this, `${this.stackName}VirtualGateway`, {
      mesh: this.mesh,
      virtualGatewayName: "ColorGateway",
      listeners: [appmesh.VirtualGatewayListener.http({ port: 8080 })],
      backendDefaults:
        meshUpdate == MeshUpdateChoices.ADD_GREEN_VN
          ? undefined
          : {
              tlsClientPolicy: {
                validation: {
                  trust: appmesh.TlsValidationTrust.file(this.fetchClientTlsCert(meshUpdate)),
                },
              },
            },
    });

    this.virtualNodeWhite = this.buildTlsEnabledVirtualNode(
      "ColorTellerWhite",
      this.serviceDiscovery.infra.SERVICE_WHITE,
      "/keys/colorteller_white_cert_chain.pem",
      "/keys/colorteller_white_key.pem"
    );

    this.virtualNodeGreen = this.buildTlsEnabledVirtualNode(
      "ColorTellerGreen",
      this.serviceDiscovery.infra.SERVICE_GREEN,
      "/keys/colorteller_green_cert_chain.pem",
      "/keys/colorteller_green_key.pem"
    );

    this.virtualRouter = new appmesh.VirtualRouter(this, `${this.stackName}VritualRouter`, {
      mesh: this.mesh,
      virtualRouterName: "ColorTellerVirtualRouter",
      listeners: [appmesh.VirtualRouterListener.http(80)],
    });

    this.route = new appmesh.Route(this, `${this.stackName}BackendRoute`, {
      mesh: this.mesh,
      virtualRouter: this.virtualRouter,
      routeName: "ColorTellerRoute",
      routeSpec: appmesh.RouteSpec.http({
        weightedTargets: [
          {
            virtualNode: this.virtualNodeWhite,
            weight: 1,
          },
          {
            virtualNode: this.virtualNodeGreen,
            weight: meshUpdate ? 1 : 0,
          },
        ],
      }),
    });

    this.virtualService = new appmesh.VirtualService(this, `${this.stackName}VirtualService`, {
      virtualServiceName: `colorteller.${this.node.tryGetContext("SERVICES_DOMAIN")}`,
      virtualServiceProvider: appmesh.VirtualServiceProvider.virtualRouter(this.virtualRouter),
    });

    this.virtualGateway.addGatewayRoute(`${this.stackName}VirtualGatewayRoute`, {
      gatewayRouteName: "gateway-gr",
      routeSpec: appmesh.GatewayRouteSpec.http({
        routeTarget: this.virtualService,
      }),
    });
  }

  private fetchClientTlsCert = (meshUpdate: MeshUpdateChoices): string => {
    return meshUpdate == MeshUpdateChoices.ENABLE_BUNDLE ? "/keys/ca_1_ca_2_bundle.pem" : "/keys/ca_1_cert.pem";
  };

  private buildTlsEnabledVirtualNode = (
    virtualNodeName: string,
    serviceName: string,
    certChainPath: string,
    privateKeyPath: string
  ): appmesh.VirtualNode => {
    return new appmesh.VirtualNode(this, `${this.stackName}${virtualNodeName}`, {
      mesh: this.mesh,
      virtualNodeName: virtualNodeName,
      serviceDiscovery: this.serviceDiscovery.getAppMeshServiceDiscovery(serviceName),
      listeners: [
        appmesh.VirtualNodeListener.http({
          port: 80,
          healthCheck: appmesh.HealthCheck.http({
            healthyThreshold: 2,
            unhealthyThreshold: 3,
            path: "/ping",
          }),
          tls: {
            mode: appmesh.TlsMode.STRICT,
            certificate: appmesh.TlsCertificate.file(certChainPath, privateKeyPath),
          },
        }),
      ],
    });
  };
}
