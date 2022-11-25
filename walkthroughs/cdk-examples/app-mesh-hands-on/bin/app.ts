#!/usr/bin/env node
import * as cdk from "aws-cdk-lib";
import { MeshStack } from "../lib/stacks/mesh-components";
import { BaseStack } from "../lib/stacks/base";
import { ServiceDiscoveryStack } from "../lib/stacks/service-discovery";
import { EcsServicesStack } from "../lib/stacks/ecs-services";
import { CfnParameter } from "aws-cdk-lib";

const app = new cdk.App();

const baseStack = new BaseStack(app, "BaseStack", {
  stackName: "base",
  description: "Defines the network infrastructure, container images and ECS Cluster.",
});
const serviceDiscoveryStack = new ServiceDiscoveryStack(baseStack, "ServiceDiscoveryStack", {
  stackName: "service-discovery",
  description: "Defines the application load balancers and the CloudMap service.",
});
const meshStack = new MeshStack(serviceDiscoveryStack, "MeshStack", {
  stackName: "mesh-components",
  description: "Defines mesh components like the virtual nodes, routers and services.",
});
const ecsServicesStack = new EcsServicesStack(meshStack, "ECSServicesStack", {
  stackName: "ecs-services",
  description: "Defines the Fargate services and their task definitions.",
});

serviceDiscoveryStack.addDependency(baseStack);
meshStack.addDependency(serviceDiscoveryStack);
ecsServicesStack.addDependency(meshStack);
