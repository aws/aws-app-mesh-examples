import * as ecs from "aws-cdk-lib/aws-ecs";
import { StackProps } from "aws-cdk-lib";
import { ApplicationContainer } from "./constructs/application-container";
import { EnvoySidecar } from "./constructs/envoy-sidecar";

export enum MeshUpdateChoice {
  NO_TLS = "no-tls",
  ONE_WAY_TLS = "one-way-tls",
  MUTUAL_TLS = "mtls",
}

export enum ServiceDiscoveryType {
  DNS = "DNS",
  CLOUDMAP = "CLOUDMAP",
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
}

export interface ApplicationContainerProps extends CustomContainerProps {
  image: ecs.ContainerImage;
  env?: { [key: string]: string };
  portMappings: ecs.PortMapping[];
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
