import * as service_discovery from "aws-cdk-lib/aws-servicediscovery";
import * as appmesh from "aws-cdk-lib/aws-appmesh";
import { Stack, StackProps } from "aws-cdk-lib";
import { BaseStack } from "./base";

export class ServiceDiscoveryStack extends Stack {
  readonly base: BaseStack;

  readonly backendV1CloudMapService: service_discovery.Service;
  readonly backendV2CloudMapService: service_discovery.Service;
  readonly frontendCloudMapService: service_discovery.Service;

  constructor(base: BaseStack, id: string, props?: StackProps) {
    super(base, id, props);

    this.base = base;

    this.backendV1CloudMapService = this.base.dnsNameSpace.createService(
      `${this.stackName}BackendV1CloudMapService`,
      this.buildDnsServiceProps(base.serviceBackend)
    );

    this.backendV2CloudMapService = this.base.dnsNameSpace.createService(
      `${this.stackName}BackendV2CloudMapService`,
      this.buildDnsServiceProps(base.serviceBackend1)
    );

    this.frontendCloudMapService = this.base.dnsNameSpace.createService(
      `${this.stackName}FrontendCloudMapService`,
      this.buildDnsServiceProps(base.serviceFrontend)
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
      case this.base.serviceBackend:
        return this.backendV1CloudMapService;
      case this.base.serviceBackend1:
        return this.backendV2CloudMapService;
      case this.base.serviceFrontend:
        return this.frontendCloudMapService;
      default:
        return this.backendV1CloudMapService;
    }
  }

  public getAppMeshServiceDiscovery(serviceName: string): appmesh.ServiceDiscovery {
    return appmesh.ServiceDiscovery.cloudMap(this.getCloudMapService(serviceName));
  }
}
