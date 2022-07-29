import * as appmesh from "aws-cdk-lib/aws-appmesh";
import { StackProps, Stack } from "aws-cdk-lib";
import { ServiceDiscoveryStack } from "./service-discovery";
import { MeshUpdateChoice } from "../utils";

export class MeshStack extends Stack {
  readonly serviceDiscovery: ServiceDiscoveryStack;
  readonly mesh: appmesh.Mesh;

  readonly virtualNode: appmesh.VirtualNode;
  readonly virtualGateway: appmesh.VirtualGateway;
  readonly virtualService: appmesh.VirtualService;

  constructor(serviceDiscovery: ServiceDiscoveryStack, id: string, props?: StackProps) {
    super(serviceDiscovery, id, props);

    this.serviceDiscovery = serviceDiscovery;

    let meshUpdateChoice = this.node.tryGetContext("mesh-update");

    this.mesh = new appmesh.Mesh(this, `${this.stackName}Mesh`, {
      meshName: this.node.tryGetContext("MESH_NAME"),
    });

    if (meshUpdateChoice != undefined && !Object.values(MeshUpdateChoice).includes(meshUpdateChoice)) {
      meshUpdateChoice = undefined;
      console.log("\n\n -------------------------------------------------------- \n\n");
      console.log(
        "Invalid choice for mesh-update, valid choices are: \n",
        Object.values(MeshUpdateChoice),
        " or undefined\n"
      );
      console.log("Defaulting to mesh-update = undefined");
      console.log("\n\n -------------------------------------------------------- \n\n");
    }

    this.virtualGateway = new appmesh.VirtualGateway(this, `${this.stackName}VirtualGateway`, {
      mesh: this.mesh,
      virtualGatewayName: "ColorGateway",
      listeners: [appmesh.VirtualGatewayListener.http({ port: 9080 })],
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

    this.virtualNode = this.buildTlsEnabledVirtualNode(
      "ColorTellerWhite",
      this.serviceDiscovery.infra.serviceColorTeller,
      this.whiteCertChainPath,
      this.whitePrivateKeyPath
    );

    this.virtualService = new appmesh.VirtualService(this, `${this.stackName}VirtualService`, {
      virtualServiceName: `colorteller.${this.node.tryGetContext("SERVICES_DOMAIN")}`,
      virtualServiceProvider: appmesh.VirtualServiceProvider.virtualNode(this.virtualNode),
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
