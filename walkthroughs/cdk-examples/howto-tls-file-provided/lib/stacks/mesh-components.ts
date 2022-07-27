import * as appmesh from "aws-cdk-lib/aws-appmesh";
import { StackProps, Stack } from "aws-cdk-lib";
import { ServiceDiscoveryStack } from "./service-discovery";
import { MeshUpdateChoice } from "../utils";

export class MeshStack extends Stack {
  readonly serviceDiscovery: ServiceDiscoveryStack;
  readonly mesh: appmesh.Mesh;

  readonly virtualNodeWhite: appmesh.VirtualNode;
  readonly virtualNodeGreen: appmesh.VirtualNode;

  readonly virtualGateway: appmesh.VirtualGateway;

  readonly virtualRouter: appmesh.VirtualRouter;
  readonly route: appmesh.Route;

  readonly virtualService: appmesh.VirtualService;

  readonly whiteCertChainPath: string = "/keys/colorteller_white_cert_chain.pem";
  readonly whitePrivateKeyPath: string = "/keys/colorteller_white_key.pem";

  readonly greenCertChainPath: string = "/keys/colorteller_green_cert_chain.pem";
  readonly greenPrivateKeyPath: string = "/keys/colorteller_green_key.pem";

  readonly ca1CertPath: string = "/keys/ca_1_cert.pem";
  readonly bundleCertPath: string = "/keys/ca_1_ca_2_bundle.pem";

  constructor(serviceDiscovery: ServiceDiscoveryStack, id: string, props?: StackProps) {
    super(serviceDiscovery, id, props);

    this.serviceDiscovery = serviceDiscovery;

    const meshUpdateChoice = this.node.tryGetContext("mesh-update");
    this.mesh = new appmesh.Mesh(this, `${this.stackName}Mesh`, {
      meshName: this.node.tryGetContext("MESH_NAME"),
    });

    const greenVnWeight: number = meshUpdateChoice ? 50 : 0;
    const whiteVnWeight: number = greenVnWeight == 0 ? 100 : 50;

    console.log(
      "\n\n",
      " ------- ",
      `Green VN Weight = ${greenVnWeight}`,
      `White VN Weight = ${whiteVnWeight}`,
      " ------- "
    );

    this.virtualGateway = new appmesh.VirtualGateway(this, `${this.stackName}VirtualGateway`, {
      mesh: this.mesh,
      virtualGatewayName: "ColorGateway",
      listeners: [appmesh.VirtualGatewayListener.http({ port: 8080 })],
      backendDefaults:
        meshUpdateChoice == MeshUpdateChoice.ADD_GREEN_VN
          ? undefined
          : {
              tlsClientPolicy: {
                validation: {
                  trust: appmesh.TlsValidationTrust.file(this.fetchClientTlsCert(meshUpdateChoice)),
                },
              },
            },
    });

    this.virtualNodeWhite = this.buildTlsEnabledVirtualNode(
      "ColorTellerWhite",
      this.serviceDiscovery.infra.serviceWhite,
      this.whiteCertChainPath,
      this.whitePrivateKeyPath
    );

    this.virtualNodeGreen = this.buildTlsEnabledVirtualNode(
      "ColorTellerGreen",
      this.serviceDiscovery.infra.serviceGreen,
      this.greenCertChainPath,
      this.greenPrivateKeyPath
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
            weight: whiteVnWeight,
          },
          {
            virtualNode: this.virtualNodeGreen,
            weight: greenVnWeight,
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
  private fetchClientTlsCert = (meshUpdateChoice: MeshUpdateChoice): string => {
    return meshUpdateChoice == MeshUpdateChoice.ADD_BUNDLE ? this.bundleCertPath : this.ca1CertPath;
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
