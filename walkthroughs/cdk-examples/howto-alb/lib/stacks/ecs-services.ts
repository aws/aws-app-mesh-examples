import { StackProps, Stack, CfnOutput } from "aws-cdk-lib";
import { BackendServiceV2Construct } from "../constructs/backend-service-v2";
import { BackendServiceV1Construct } from "../constructs/backend-service-v1";
import { FrontEndServiceConstruct } from "../constructs/frontend-service";
import { MeshStack } from "./mesh-components";

export class ECSServicesStack extends Stack {
  constructor(ms: MeshStack, id: string, props?: StackProps) {
    super(ms, id, props);

    const backendV1 = new BackendServiceV1Construct(ms, "BackendServiceV1Construct");
    const backendV2 = new BackendServiceV2Construct(ms, "BackendServiceV2Construct");
    const frontend = new FrontEndServiceConstruct(ms, "FrontEndServiceConstruct");

    // backendV1.service.node.addDependency(backendV2.service);
    // frontend.service.node.addDependency(backendV2.service);
    // frontend.service.node.addDependency(backendV1.service);

    // frontend.taskDefinition.node.addDependency(ms.frontendVirtualNode);
    // frontend.taskDefinition.node.addDependency(ms.backendVirtualService);

    new CfnOutput(this, 'PublicEndpoint', { value: ms.sd.frontendLoadBalancer.loadBalancerDnsName, 
    description: 'Public endpoint to query the frontend load balancer', exportName: 'PublicEndpoint' });
  }
}
