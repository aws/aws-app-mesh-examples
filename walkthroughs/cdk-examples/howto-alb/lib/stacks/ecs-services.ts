import { StackProps, Stack, CfnOutput } from "aws-cdk-lib";
import { BackendServiceV2Construct } from "../constructs/backend-service-v2";
import { BackendServiceV1Construct } from "../constructs/backend-service-v1";
import { FrontEndServiceConstruct } from "../constructs/frontend-service";
import { MeshStack } from "./mesh-components";
import { AppMeshFargateService } from "../constructs/appmesh-fargate-serivce";
import { EnvoySidecar } from "../constructs/envoy-sidecar";
import { XrayContainer } from "../constructs/xray-container";
import * as ecs from "aws-cdk-lib/aws-ecs";

export class ECSServicesStack extends Stack {
  constructor(ms: MeshStack, id: string, props?: StackProps) {
    super(ms, id, props);

    const backendV1 = new BackendServiceV1Construct(ms, "BackendServiceV1Construct");
    const backendV2 = new BackendServiceV2Construct(ms, "BackendServiceV2Construct");
    const frontend = new FrontEndServiceConstruct(ms, "FrontEndServiceConstruct");
    new CfnOutput(this, "PublicEndpoint", {
      value: ms.sd.frontendLoadBalancer.loadBalancerDnsName,
      description: "Public endpoint to query the frontend load balancer",
      exportName: "PublicEndpoint",
    });

    // Backend V1
    // new AppMeshFargateService(ms, "BackendV1AppMeshFargateService", {
    //   serviceName: ms.sd.base.SERVICE_BACKEND_V1,
    //   serviceDiscoveryType: "ALB_DNS",
    //   taskDefinitionFamily: "blue",
    //   xrayContainer: new XrayContainer(ms, "BackendV1XrayOpts", {
    //     logStreamPrefix: "backend-v1-xray",
    //   }),
    //   applicationContainerProps: {
    //     containerName: "app",
    //     image: ecs.ContainerImage.fromDockerImageAsset(ms.sd.base.backendAppImageAsset),
    //     environment: {
    //       COLOR: "blue",
    //       PORT: ms.sd.base.containerPort.toString(),
    //       XRAY_APP_NAME: `${ms.mesh.meshName}/${ms.backendV1VirtualNode.virtualNodeName}`,
    //     },
    //     logging: ecs.LogDriver.awsLogs({
    //       logGroup: ms.sd.base.logGroup,
    //       streamPrefix: "backend-v1-app",
    //     }),
    //     portMappings: [
    //       {
    //         containerPort: ms.sd.base.containerPort,
    //         hostPort: ms.sd.base.containerPort,
    //         protocol: ecs.Protocol.TCP,
    //       },
    //     ],
    //   },
    // });

    // // Backend V2
    // new AppMeshFargateService(ms, "BackendV2AppMeshFargateService", {
    //   serviceName: ms.sd.base.SERVICE_FRONTEND,
    //   serviceDiscoveryType: "ALB_DNS",
    //   taskDefinitionFamily: "front",

    //   envoySidecar: new EnvoySidecar(ms, "BackendV2AppMeshFargateService", {
    //     logStreamPrefix: "backend-v2-envoy",
    //     appMeshResourcePath: `mesh/${ms.mesh.meshName}/virtualNode/${ms.backendV2VirtualNode.virtualNodeName}`,
    //     enableXrayTracing: true,
    //   }),

    //   xrayContainer: new XrayContainer(ms, "BackendV2AppMeshFargateService", {
    //     logStreamPrefix: "backend-v2-xray",
    //   }),
    //   applicationContainerProps:  {
      //   image: ecs.ContainerImage.fromDockerImageAsset(ms.sd.base.backendAppImageAsset),
      //   containerName: "app",
      //   environment: {
      //     COLOR: "green",
      //     PORT: ms.sd.base.containerPort.toString(),
      //     XRAY_APP_NAME: `${ms.mesh.meshName}/${ms.backendV2VirtualNode.virtualNodeName}`,
      //   },
      //   logging: ecs.LogDriver.awsLogs({
      //     logGroup: ms.sd.base.logGroup,
      //     streamPrefix: "backend-v2-app",
      //   }),
      //   portMappings: [
      //     {
      //       containerPort: ms.sd.base.containerPort,
      //       hostPort: ms.sd.base.containerPort,
      //       protocol: ecs.Protocol.TCP,
      //     },
      //   ],
      // }
    // });

    // // Frontend
    // new AppMeshFargateService(ms, "FrontendAppMeshFargateService", {
    //   serviceName: ms.sd.base.SERVICE_FRONTEND,
    //   serviceDiscoveryType: "ALB_DNS",
    //   taskDefinitionFamily: "front",

    //   envoySidecar: new EnvoySidecar(ms, "FrontendAppMeshEnvoySidecar", {
    //     logStreamPrefix: "front-envoy",
    //     appMeshResourcePath: `mesh/${ms.mesh.meshName}/virtualNode/${ms.frontendVirtualNode.virtualNodeName}`,
    //     enableXrayTracing: true,
    //   }),

    //   xrayContainer: new XrayContainer(ms, "FrontendXrayOpts", {
    //     logStreamPrefix: "frontend-xray",
    //   }),
    //   applicationContainerProps: {
    //     containerName: "app",
    //     image: ecs.ContainerImage.fromDockerImageAsset(ms.sd.base.frontendAppImageAsset),
    //     logging: ecs.LogDriver.awsLogs({
    //       logGroup: ms.sd.base.logGroup,
    //       streamPrefix: "front-app",
    //     }),
    //     environment: {
    //       PORT: ms.sd.base.containerPort.toString(),
    //       COLOR_HOST: `${ms.backendVirtualService.virtualServiceName}:${ms.sd.base.containerPort}`,
    //       XRAY_APP_NAME: `${ms.mesh.meshName}/${ms.frontendVirtualNode.virtualNodeName}`,
    //     },
    //     portMappings: [{ containerPort: ms.sd.base.containerPort, protocol: ecs.Protocol.TCP }],
    //   },
    // });
  }
}
