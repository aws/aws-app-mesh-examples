#!/usr/bin/env node
import * as cdk from "aws-cdk-lib";
import { InfraStack } from "../lib/stacks/infra";
import { AcmStack } from "../lib/stacks/acm";
import { ServiceDiscoveryStack } from "../lib/stacks/service-discovery";
import { MeshStack } from "../lib/stacks/mesh-components";
import { EcsServicesStack } from "../lib/stacks/ecs-services";

const app = new cdk.App();
const acm = new AcmStack(app, "acm", { stackName: "acm" });
const infra = new InfraStack(app, "infra", { stackName: "infra" });
const serviceDiscovery = new ServiceDiscoveryStack(infra, "svc-dscry", { stackName: "svc-dscry" });
const mesh = new MeshStack(serviceDiscovery, "mesh", { stackName: "mesh", acmStack: acm });
const ecsServices = new EcsServicesStack(mesh, "ecs-servcies", { stackName: "ecs-services", acmStack: acm });

// Dependencies
serviceDiscovery.addDependency(infra);

mesh.addDependency(serviceDiscovery);
mesh.addDependency(acm);

ecsServices.addDependency(mesh);
ecsServices.addDependency(acm);
