import * as ecs from "aws-cdk-lib/aws-ecs";
import { EnvoySidecar } from "./constructs/envoy-sidecar";
import { XrayContainer } from "./constructs/xray-container";

export interface CustomContainerProps {
  logStreamPrefix: string;
}

export interface EnvoyContainerProps extends CustomContainerProps {
  appMeshResourcePath: string;
  enableXrayTracing: boolean;
}

export interface XrayContainerProps extends CustomContainerProps {}

export interface ApplicationContainerProps extends CustomContainerProps {
  image: ecs.ContainerImage;
  env: { [key: string]: string };
  portMappings: ecs.PortMapping[];
}

export enum ServiceDiscoveryType {
  DNS = "DNS",
  CLOUDMAP = "CLOUDMAP",
}

export interface AppMeshFargateServiceProps {
  serviceName: string;
  taskDefinitionFamily: string;
  serviceDiscoveryType: ServiceDiscoveryType;
  applicationContainerProps: ecs.ContainerDefinitionOptions;
  envoySidecar?: EnvoySidecar;
  xrayContainer: XrayContainer;
  proxyConfiguration?: ecs.AppMeshProxyConfiguration;
}

export function buildAppMeshProxy(...applicationPorts: number[]): ecs.AppMeshProxyConfiguration {
  return new ecs.AppMeshProxyConfiguration({
    containerName: "envoy",
    properties: {
      proxyIngressPort: 15000,
      proxyEgressPort: 15001,
      appPorts: applicationPorts,
      ignoredUID: 1337,
      egressIgnoredIPs: ["169.254.170.2", "169.254.169.254"],
    },
  });
}
