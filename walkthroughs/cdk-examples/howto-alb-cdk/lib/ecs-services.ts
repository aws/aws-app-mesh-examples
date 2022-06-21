import { StackProps, Stack } from 'aws-cdk-lib';
import { BackendServiceV2Construct } from './backend-service-v2';
import { BackendServiceV1Construct } from './backend-service-v1';
import { FrontEndServiceConstruct } from './frontend-service';
import { MeshStack } from './mesh';


export class ECSServicesStack extends Stack {
    constructor(ms: MeshStack, id: string, props?: StackProps) {
        super(ms, id, props);
        
        const backendV1 = new BackendServiceV1Construct(ms,'BackendServiceV1Construct');
        const backendV2 = new BackendServiceV2Construct(ms, 'BackendServiceV2Construct');
        const frontend = new FrontEndServiceConstruct(ms, 'FrontEndServiceConstruct');


        backendV1.service.node.addDependency(backendV2.service);
        frontend.service.node.addDependency(backendV2.service);
        frontend.service.node.addDependency(backendV1.service);
        
        frontend.taskDefinition.node.addDependency(ms.frontendVirtualNode);
        frontend.taskDefinition.node.addDependency(ms.backendVirtualService);

    }
}