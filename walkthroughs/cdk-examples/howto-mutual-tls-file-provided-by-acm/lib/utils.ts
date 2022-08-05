import * as ecs from "aws-cdk-lib/aws-ecs";
import { StackProps } from "aws-cdk-lib";
import { ApplicationContainer } from "./constructs/application-container";
import { EnvoySidecar } from "./constructs/envoy-sidecar";
import { AcmStack } from "./stacks/acm";
import { IManagedPolicy, ManagedPolicy } from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";

export interface CustomStackProps extends StackProps {
  acmStack: AcmStack;
}

export enum MeshUpdateChoice {
  NO_TLS = "no-tls",
  ONE_WAY_TLS = "one-way-tls",
  MUTUAL_TLS = "mtls",
}

export enum ServiceDiscoveryType {
  DNS = "DNS",
  CLOUDMAP = "CLOUDMAP",
}

export enum LambdaType {
  INIT_CERT = "initcert",
  ROTATE_CERT = "rotatecert",
}

export interface CustomContainerProps {
  logStreamPrefix: string;
}

export interface CustomStackProps extends StackProps {
  addMesh?: boolean;
}

export interface EnvoyContainerProps extends CustomContainerProps {
  appMeshResourceArn: string;
  enableXrayTracing?: boolean;
  secrets?: { [key: string]: ecs.Secret };
}

export interface ApplicationContainerProps extends CustomContainerProps {
  image: ecs.ContainerImage;
  env?: { [key: string]: string };
  portMappings: ecs.PortMapping[];
  secrets?: { [key: string]: ecs.Secret };
}

export interface EnvoyConfiguration {
  container: EnvoySidecar;
  proxyConfiguration?: ecs.ProxyConfiguration;
}

export interface AppMeshFargateServiceProps {
  serviceName: string;
  taskDefinitionFamily: string;
  serviceDiscoveryType?: ServiceDiscoveryType;
  applicationContainer?: ApplicationContainer;
  envoyConfiguration?: EnvoyConfiguration;
}

export function addManagedPolices(
  parentStack: Construct,
  cfnLogicalName: string,
  ...policyNames: string[]
): IManagedPolicy[] {
  const policies: IManagedPolicy[] = [];
  policyNames.forEach((policyName) =>
    policies.push(
      ManagedPolicy.fromManagedPolicyArn(
        parentStack,
        `${policyName}${cfnLogicalName}Arn`,
        `arn:aws:iam::aws:policy/${policyName}`
      )
    )
  );
  return policies;
}
