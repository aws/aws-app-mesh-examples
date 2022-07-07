import * as route53 from "aws-cdk-lib/aws-route53";
import * as route53_targets from "aws-cdk-lib/aws-route53-targets";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import * as service_discovery from "aws-cdk-lib/aws-servicediscovery";
import * as appmesh from "aws-cdk-lib/aws-appmesh";
import { Stack, StackProps, Duration } from "aws-cdk-lib";
import { BaseStack } from "./base";

export class ServiceDiscoveryStack extends Stack {
  base: BaseStack;
  frontendLoadBalancer: elbv2.ApplicationLoadBalancer;
  backendV1LoadBalancer: elbv2.ApplicationLoadBalancer;
  backendRecordSet: route53.RecordSet;
  backendV2CloudMapService: service_discovery.Service;

  readonly stackIdentifier: string = "ServiceDiscoveryStack";

  constructor(base: BaseStack, id: string, props?: StackProps) {
    super(base, id, props);

    this.base = base;

    this.backendV1LoadBalancer = new elbv2.ApplicationLoadBalancer(
      this,
      `${this.stackIdentifier}_BackendV1LoadBalancer`,
      this.buildAlbProps(this.base.SERVICE_BACKEND_V1, false)
    );

    this.backendRecordSet = new route53.RecordSet(this, `${this.stackIdentifier}_BackendRecordSet`, {
      recordType: route53.RecordType.A,
      zone: this.base.dnsHostedZone,
      target: route53.RecordTarget.fromAlias(
        new route53_targets.LoadBalancerTarget(this.backendV1LoadBalancer)
      ),
      recordName: `backend.${this.base.dnsHostedZone.zoneName}`,
    });

    this.backendV2CloudMapService = this.base.dnsNameSpace.createService(
      `${this.stackIdentifier}_BackendV2CloudMapService`,
      {
        name: this.base.SERVICE_BACKEND_V2,
        dnsRecordType: service_discovery.DnsRecordType.A,
        dnsTtl: Duration.seconds(300),
        customHealthCheck: {
          failureThreshold: 1,
        },
      }
    );

    this.frontendLoadBalancer = new elbv2.ApplicationLoadBalancer(
      this,
      `${this.stackIdentifier}_FrontendLoadBalancer`,
      this.buildAlbProps(this.base.SERVICE_FRONTEND, true)
    );
  }

  private buildAlbProps = (name: string, isInternetFacing: boolean): elbv2.ApplicationLoadBalancerProps => {
    return {
      loadBalancerName: name,
      vpc: this.base.vpc,
      internetFacing: isInternetFacing,
    };
  };

  public getAlbForService = (serviceName: string): elbv2.ApplicationLoadBalancer => {
    switch (serviceName) {
      case this.base.SERVICE_BACKEND_V1:
        return this.backendV1LoadBalancer;
      case this.base.SERVICE_FRONTEND:
        return this.frontendLoadBalancer;
      default:
        return this.backendV1LoadBalancer;
    }
  };

  public getServiceDiscovery(serviceName: string): appmesh.ServiceDiscovery {
    switch (serviceName) {
      case this.base.SERVICE_BACKEND_V1:
        return appmesh.ServiceDiscovery.dns(this.backendV1LoadBalancer.loadBalancerDnsName);
      case this.base.SERVICE_BACKEND_V2:
        return appmesh.ServiceDiscovery.cloudMap(this.backendV2CloudMapService);
      case this.base.SERVICE_FRONTEND:
        return appmesh.ServiceDiscovery.dns(this.frontendLoadBalancer.loadBalancerDnsName);
      default:
        return appmesh.ServiceDiscovery.dns(this.backendV1LoadBalancer.loadBalancerDnsName);
    }
  }
}
