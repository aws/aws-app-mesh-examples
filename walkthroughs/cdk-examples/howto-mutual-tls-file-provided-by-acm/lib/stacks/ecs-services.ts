import * as ecs from "aws-cdk-lib/aws-ecs";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as iam from "aws-cdk-lib/aws-iam";
import * as events from "aws-cdk-lib/aws-events";
import * as targets from "aws-cdk-lib/aws-events-targets";
import * as assets from "aws-cdk-lib/aws-ecr-assets";
import * as logs from "aws-cdk-lib/aws-logs";

import { Stack, CfnOutput, Duration } from "aws-cdk-lib";
import { MeshStack } from "./mesh-components";
import { AppMeshFargateService } from "../constructs/appmesh-fargate-service";
import { EnvoySidecar } from "../constructs/envoy-sidecar";
import { ApplicationContainer } from "../constructs/application-container";
import { CustomStackProps, getCertLambdaPolicies } from "../utils";

import * as path from "path";

export class EcsServicesStack extends Stack {
  readonly rotateCertFunc: lambda.Function;
  readonly rotateCertRole: iam.Role;
  readonly rotateCertExpriationEvent: events.Rule;

  constructor(mesh: MeshStack, id: string, props?: CustomStackProps) {
    super(mesh, id, props);

    const colorTellerServiceName = mesh.serviceDiscovery.infra.serviceColorTeller;
    const colorGatewayServiceName = mesh.serviceDiscovery.infra.serviceGateway;
    const certSecret = { CertSecret: ecs.Secret.fromSecretsManager(props!.acmStack.certificateSecret) };

    const colorTeller = new AppMeshFargateService(mesh, `${this.stackName}WhiteService`, {
      serviceName: colorTellerServiceName,
      taskDefinitionFamily: colorTellerServiceName,
      applicationContainer: new ApplicationContainer(mesh, `${this.stackName}WhiteAppContainer`, {
        image: ecs.ContainerImage.fromDockerImageAsset(mesh.serviceDiscovery.infra.colorTellerImageAsset),
        logStreamPrefix: colorTellerServiceName,
        env: {
          PORT: mesh.serviceDiscovery.infra.port.toString(),
          COLOR: "YELLOW",
        },
        portMappings: [{ containerPort: mesh.serviceDiscovery.infra.port, protocol: ecs.Protocol.TCP }],
        secrets: certSecret,
      }),
      envoyConfiguration: {
        container: new EnvoySidecar(mesh, `${this.stackName}WhiteEnvoySidecar`, {
          logStreamPrefix: `${colorTellerServiceName}-envoy`,
          appMeshResourceArn: mesh.virtualNode.virtualNodeArn,
          secrets: certSecret,
        }),
        proxyConfiguration: EnvoySidecar.buildAppMeshProxy(mesh.serviceDiscovery.infra.port),
      },
    });

    const gateway = new AppMeshFargateService(mesh, `${this.stackName}GatewayService`, {
      serviceName: colorGatewayServiceName,
      taskDefinitionFamily: colorGatewayServiceName,
      envoyConfiguration: {
        container: new EnvoySidecar(mesh, `${this.stackName}GatewayEnvoySidecar`, {
          logStreamPrefix: `${colorGatewayServiceName}-envoy`,
          appMeshResourceArn: mesh.virtualGateway.virtualGatewayArn,
          enableXrayTracing: false,
          secrets: certSecret,
        }),
      },
    });

    this.rotateCertRole = new iam.Role(this, `${this.stackName}LambdaCertRole`, {
      assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
      managedPolicies: getCertLambdaPolicies(this, "rotateCertPols"),
    });

    this.rotateCertFunc = new lambda.DockerImageFunction(this, `${this.stackName}RotateCertFunc`, {
      functionName: "rotate-cert",
      logRetention: logs.RetentionDays.ONE_DAY,
      timeout: Duration.seconds(900),
      code: lambda.DockerImageCode.fromImageAsset(path.join(__dirname, "../../lambdas/"), {
        platform: assets.Platform.LINUX_AMD64,
        cmd: ["rotatecert.lambda_handler"],
        buildArgs: { FILE: "rotatecert.py" },
      }),
      role: this.rotateCertRole,
      environment: {
        COLOR_GATEWAY_ACM_ARN: props!.acmStack.colorGatewayEndpointCert.certificateArn,
        COLOR_TELLER_ACM_ARN: props!.acmStack.colorTellerEndpointCert.certificateArn,
        SVC_TELLER: colorTeller.service.serviceArn,
        SVC_GATEWAY: gateway.service.serviceArn,
        CLUSTER: mesh.serviceDiscovery.infra.cluster.clusterArn,
        SECRET: props!.acmStack.certificateSecret.secretArn,
      },
    });

    this.rotateCertExpriationEvent = new events.Rule(this, `${this.stackName}EvRule`, {
      enabled: true,
      eventPattern: {
        detailType: ["ACM Certificate Approaching Expiration"],
        source: ["aws.acm"],
        resources: [props!.acmStack.colorGatewayEndpointCert.certificateArn, props!.acmStack.colorTellerEndpointCert.certificateArn],
      },
    });
    this.rotateCertExpriationEvent.addTarget(new targets.LambdaFunction(this.rotateCertFunc));

    gateway.node.addDependency(colorTeller);
    const colorTellerServiceDns = `${mesh.serviceDiscovery.infra.serviceColorTeller}.${this.node.tryGetContext("SERVICES_DOMAIN")}`;

    new CfnOutput(this, "BastionIP", { value: `export BASTION_IP=${mesh.serviceDiscovery.infra.bastionHost.instancePublicIp}` });
    new CfnOutput(this, "URL", { value: `export URL=${mesh.serviceDiscovery.publicLoadBalancer.loadBalancerDnsName}` });
    new CfnOutput(this, "BastionEndpoint", {
      value: `curl -s ${colorTellerServiceDns}:9901/stats | grep -E 'ssl.handshake|ssl.no_certificate'`,
    });
  }
}
