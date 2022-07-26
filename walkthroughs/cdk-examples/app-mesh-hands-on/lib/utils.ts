import * as ecs from "aws-cdk-lib/aws-ecs";
import { StackProps } from "aws-cdk-lib";
import { ApplicationContainer } from "./constructs/application-container";
import { EnvoySidecar } from "./constructs/envoy-sidecar";
import { XrayContainer } from "./constructs/xray-container";

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
  enableXrayTracing: boolean;
}

export interface EnvoyConfiguration {
  container?: EnvoySidecar;
  proxyConfiguration?: ecs.ProxyConfiguration;
}

export interface XrayContainerProps extends CustomContainerProps {}

export interface ApplicationContainerProps extends CustomContainerProps {
  image: ecs.ContainerImage;
  env?: { [key: string]: string };
  portMappings: ecs.PortMapping[];
}

export interface AppMeshFargateServiceProps {
  serviceName: string;
  taskDefinitionFamily: string;
  serviceDiscoveryType?: ServiceDiscoveryType;
  applicationContainer: ApplicationContainer;
  envoyConfiguration?: EnvoyConfiguration;
  xrayContainer?: XrayContainer;
}