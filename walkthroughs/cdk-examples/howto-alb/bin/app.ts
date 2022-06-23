#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { MeshStack } from '../lib/stacks/mesh-components';
import { BaseStack } from '../lib/stacks/base';
import { ServiceDiscoveryStack } from '../lib/stacks/service-discovery';
import { ECSServicesStack } from '../lib/stacks/ecs-services';

const app = new cdk.App();

const baseStack = new BaseStack(app, 'BaseStack',{
    stackName: 'BaseStack',
    description: "Provisions the network infrastructure and container images."
});
const serviceDiscoveryStack = new ServiceDiscoveryStack(baseStack, 'ServiceDiscoveryStack', {
    stackName: 'ServiceDiscoveryStack',
    description: "Provisions the application load balancers and the CloudMap service."
});
const meshStack = new MeshStack(serviceDiscoveryStack, 'MeshStack', {
    stackName: 'MeshStack',
    description: "Provisions mesh components like the virtual nodes, routers and services."
});
const ecsServicesStack = new ECSServicesStack(meshStack, 'ECSServicesStack', {
    stackName: 'ECSServicesStack',
    description: "Provisions the Fargate services using their task definitons."
});

// Dependencies
serviceDiscoveryStack.addDependency(baseStack);
meshStack.addDependency(serviceDiscoveryStack);
ecsServicesStack.addDependency(meshStack);