#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { MeshStack } from '../lib/stacks/mesh-components';
import { BaseStack } from '../lib/stacks/base';
import { ServiceDiscoveryStack } from '../lib/stacks/service-discovery';
import { ECSServicesStack } from '../lib/stacks/ecs-services';

const app = new cdk.App();

const baseStack = new BaseStack(app, 'BaseStack');
const serviceDiscoveryStack = new ServiceDiscoveryStack(baseStack, 'ServiceDiscoveryStack');
const meshStack = new MeshStack(serviceDiscoveryStack, 'MeshStack');
const ecsServicesStack = new ECSServicesStack(meshStack, 'ECSServicesStack');

// Dependencies
serviceDiscoveryStack.addDependency(baseStack);
meshStack.addDependency(serviceDiscoveryStack);
ecsServicesStack.addDependency(meshStack);