import * as ecs from "aws-cdk-lib/aws-ecs";
import { StackProps } from "aws-cdk-lib";
import { ApplicationContainer } from "./constructs/application-container";
import { EnvoySidecar } from "./constructs/envoy-sidecar";

export enum MeshUpdateChoice {
  ADD_GREEN_VN = "add-green-vn",
  TRUST_ONLY_CA1 = "trust-only-ca1",
  TRUST_CA1_CA2 = "trust-ca1-ca2",
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
  certificateName: string;
  appMeshResourceArn: string;
  enableXrayTracing: boolean;
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
