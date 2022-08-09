import * as iam from "aws-cdk-lib/aws-iam";
import * as appmesh from "aws-cdk-lib/aws-appmesh";
import * as acm_pca from "aws-cdk-lib/aws-acmpca";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as assets from "aws-cdk-lib/aws-ecr-assets";

import { Stack, Duration, triggers } from "aws-cdk-lib";
import { ServiceDiscoveryStack } from "./service-discovery";
import { addManagedPolicies, CustomStackProps, getCertLambdaPolicies, MeshUpdateChoice } from "../utils";

import * as path from "path";

export class MeshStack extends Stack {
  readonly serviceDiscovery: ServiceDiscoveryStack;
  readonly mesh: appmesh.Mesh;

  readonly virtualNode: appmesh.VirtualNode;
  readonly virtualGateway: appmesh.VirtualGateway;
  readonly virtualService: appmesh.VirtualService;

  readonly updateServicesRole: iam.Role;
  readonly updateServicesFunc: lambda.Function;
  readonly updateServicesTrigger: triggers.Trigger;

  readonly gatewayCertChainPath: string = "/keys/colorgateway_endpoint_cert_chain.pem";
  readonly gatwayPrivateKeyPath: string = "/keys/colorgateway_endpoint_dec_pri_key.pem";

  constructor(serviceDiscovery: ServiceDiscoveryStack, id: string, props?: CustomStackProps) {
    super(serviceDiscovery, id, props);

    this.serviceDiscovery = serviceDiscovery;

    let meshUpdateChoice = this.node.tryGetContext("mesh-update");

    this.mesh = new appmesh.Mesh(this, `${this.stackName}Mesh`, {
      meshName: this.node.tryGetContext("MESH_NAME"),
    });

    if (meshUpdateChoice != undefined && !Object.values(MeshUpdateChoice).includes(meshUpdateChoice)) {
      meshUpdateChoice = MeshUpdateChoice.MUTUAL_TLS;
      console.log("\n\n -------------------------------------------------------- \n\n");
      console.log("Invalid choice for mesh-update, valid choices are: \n", Object.values(MeshUpdateChoice));
      console.log("Defaulting to mesh-update = ", MeshUpdateChoice.MUTUAL_TLS);
      console.log("\n\n -------------------------------------------------------- \n\n");
    }

    this.virtualGateway = new appmesh.VirtualGateway(this, `${this.stackName}VirtualGateway`, {
      mesh: this.mesh,
      virtualGatewayName: "ColorGateway",
      listeners: [appmesh.VirtualGatewayListener.http({ port: this.serviceDiscovery.infra.port })],
      backendDefaults: this.buildGatewayBackendDefaults(meshUpdateChoice, props!),
    });

    this.virtualNode = this.buildVirtualNode("ColorTellerWhite", this.serviceDiscovery.infra.serviceColorTeller, meshUpdateChoice, props!);

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

    this.updateServicesRole = new iam.Role(this, `${this.stackName}UpdateSvcsRole`, {
      assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
      managedPolicies: getCertLambdaPolicies(this, "updateLambdaPol"),
    });

    this.updateServicesFunc = new lambda.DockerImageFunction(this, `${this.stackName}InitCertFunc`, {
      functionName: "update-ecs-services",
      timeout: Duration.seconds(900),
      code: lambda.DockerImageCode.fromImageAsset(path.join(__dirname, "../../lambda_update_svc"), {
        platform: assets.Platform.LINUX_AMD64,
      }),
      role: this.updateServicesRole,
      environment: {
        SVC_GATEWAY: this.serviceDiscovery.infra.serviceGateway,
        SVC_TELLER: this.serviceDiscovery.infra.serviceColorTeller,
        CLUSTER: this.serviceDiscovery.infra.cluster.clusterName,
        MESH_UPDATE: meshUpdateChoice,
      },
    });

    this.updateServicesTrigger = new triggers.Trigger(this, `${this.stackName}UpdateSvcTrg`, {
      handler: this.updateServicesFunc,
      executeAfter: [this.virtualGateway, this.virtualNode],
    });
  }

  private buildGatewayBackendDefaults = (choice: string, props: CustomStackProps): appmesh.BackendDefaults | undefined => {
    return choice == MeshUpdateChoice.NO_TLS
      ? undefined
      : {
          tlsClientPolicy: {
            enforce: true,
            validation: {
              trust: appmesh.TlsValidationTrust.acm([
                acm_pca.CertificateAuthority.fromCertificateAuthorityArn(
                  this,
                  `${this.stackName}Trust`,
                  props.acmStack.colorTellerRootCa.attrArn
                ),
              ]),
            },
            mutualTlsCertificate:
              choice == MeshUpdateChoice.MUTUAL_TLS
                ? appmesh.MutualTlsCertificate.file(this.gatewayCertChainPath, this.gatwayPrivateKeyPath)
                : undefined,
          },
        };
  };

  private buildVirtualNode = (
    virtualNodeName: string,
    serviceName: string,
    choice: MeshUpdateChoice,
    props: CustomStackProps
  ): appmesh.VirtualNode => {
    return new appmesh.VirtualNode(this, `${this.stackName}${virtualNodeName}`, {
      mesh: this.mesh,
      virtualNodeName: virtualNodeName,
      serviceDiscovery: this.serviceDiscovery.getAppMeshServiceDiscovery(serviceName),
      listeners: [
        appmesh.VirtualNodeListener.http({
          port: this.serviceDiscovery.infra.port,
          tls:
            choice == MeshUpdateChoice.NO_TLS
              ? undefined
              : {
                  mode: appmesh.TlsMode.STRICT,
                  certificate: appmesh.TlsCertificate.acm(props.acmStack.colorTellerEndpointCert),
                  mutualTlsValidation:
                    choice == MeshUpdateChoice.MUTUAL_TLS
                      ? {
                          trust: appmesh.MutualTlsValidationTrust.file(this.gatewayCertChainPath),
                        }
                      : undefined,
                },
        }),
      ],
    });
  };
}
