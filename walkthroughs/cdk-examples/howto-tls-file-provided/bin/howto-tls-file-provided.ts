#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { InfraStack } from "../lib/stacks/infra";
import { SecretsStack } from "../lib/stacks/secrets";
import { MeshStack } from "../lib/stacks/mesh-components";
import { EcsServicesStack } from "../lib/stacks/ecs-services";
import { ServiceDiscoveryStack } from "../lib/stacks/service-discovery";

const app = new cdk.App();

const secrets = new SecretsStack(app, "secrets", { stackName: "secrets" });
const infra = new InfraStack(app, "infra", { stackName: "infra" });
const serviceDiscovery = new ServiceDiscoveryStack(infra, "svc-dscvry", { stackName: "svc-dscvry" });
const mesh = new MeshStack(serviceDiscovery, "mesh", { stackName: "mesh" });
const services = new EcsServicesStack(mesh, "ecs-services", { stackName: "ecs-services" });

infra.addDependency(secrets);
services.addDependency(secrets);
serviceDiscovery.addDependency(infra);
mesh.addDependency(serviceDiscovery);
services.addDependency(mesh);
