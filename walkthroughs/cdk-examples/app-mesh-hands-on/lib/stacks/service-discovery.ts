import * as service_discovery from "aws-cdk-lib/aws-servicediscovery";
import * as appmesh from "aws-cdk-lib/aws-appmesh";
import { Stack, StackProps } from "aws-cdk-lib";
import { BaseStack } from "./base";

export class ServiceDiscoveryStack extends Stack {
  base: BaseStack;

  backendV1CloudMapService: service_discovery.Service;
  backendV2CloudMapService: service_discovery.Service;
  frontendCloudMapService: service_discovery.Service;

  constructor(base: BaseStack, id: string, props?: StackProps) {
    super(base, id, props);

    this.base = base;

    this.backendV1CloudMapService = this.base.dnsNameSpace.createService(
      `${this.stackName}BackendV1CloudMapService`,
      this.buildDnsServiceProps(base.SERVICE_BACKEND)
    );

    this.backendV2CloudMapService = this.base.dnsNameSpace.createService(
      `${this.stackName}BackendV2CloudMapService`,
      this.buildDnsServiceProps(base.SERVICE_BACKEND_1)
    );

    this.frontendCloudMapService = this.base.dnsNameSpace.createService(
      `${this.stackName}FrontendCloudMapService`,
      this.buildDnsServiceProps(base.SERVICE_FRONTEND)
    );
  }

  private buildDnsServiceProps = (serviceName: string): service_discovery.DnsServiceProps => {
    return {
      name: serviceName,
      dnsRecordType: service_discovery.DnsRecordType.A,
      customHealthCheck: {
        failureThreshold: 1,
      },
    };
  };

  public getCloudMapService(serviceName: string): service_discovery.Service {
    switch (serviceName) {
      case this.base.SERVICE_BACKEND:
        return this.backendV1CloudMapService;
      case this.base.SERVICE_BACKEND_1:
        return this.backendV2CloudMapService;
      case this.base.SERVICE_FRONTEND:
        return this.frontendCloudMapService;
      default:
        return this.backendV1CloudMapService;
    }
  }

  public getAppMeshServiceDiscovery(serviceName: string): appmesh.ServiceDiscovery {
    switch (serviceName) {
      case this.base.SERVICE_BACKEND:
        return appmesh.ServiceDiscovery.cloudMap(this.backendV1CloudMapService);
      case this.base.SERVICE_BACKEND_1:
        return appmesh.ServiceDiscovery.cloudMap(this.backendV2CloudMapService);
      case this.base.SERVICE_FRONTEND:
        return appmesh.ServiceDiscovery.cloudMap(this.frontendCloudMapService);
      default:
        return appmesh.ServiceDiscovery.cloudMap(this.backendV1CloudMapService);
    }
  }
}
