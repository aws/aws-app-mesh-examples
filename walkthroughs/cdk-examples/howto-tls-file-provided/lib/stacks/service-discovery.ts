import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as appmesh from "aws-cdk-lib/aws-appmesh";
import * as service_discovery from "aws-cdk-lib/aws-servicediscovery";

import { Duration, Stack, StackProps } from "aws-cdk-lib";
import { InfraStack } from "./infra";

export class ServiceDiscoveryStack extends Stack {
  readonly infra: InfraStack;
  readonly namespace: service_discovery.PrivateDnsNamespace;
  readonly colorTellerWhiteServiceDiscovery: service_discovery.Service;
  readonly colorTellerGreenServiceDiscovery: service_discovery.Service;
  readonly colorTellerGatewayServiceDiscovery: service_discovery.Service;

  readonly publicLoadBalancer: elbv2.ApplicationLoadBalancer;
  readonly loadBalancerSecGroup: ec2.SecurityGroup;

  constructor(infra: InfraStack, id: string, props?: StackProps) {
    super(infra, id, props);

    this.infra = infra;

    this.namespace = new service_discovery.PrivateDnsNamespace(this, `${this.stackName}Nmspc`, {
      vpc: this.infra.vpc,
      name: this.node.tryGetContext("SERVICES_DOMAIN"),
    });

    this.colorTellerGatewayServiceDiscovery = this.namespace.createService(
      `${this.stackName}GwSvc`,
      this.buildDnsServiceProps("colorgateway", true)
    );
    this.colorTellerWhiteServiceDiscovery = this.namespace.createService(
      `${this.stackName}WhiteSvc`,
      this.buildDnsServiceProps("colorteller", false)
    );
    this.colorTellerGreenServiceDiscovery = this.namespace.createService(
      `${this.stackName}GreenSvc`,
      this.buildDnsServiceProps("colorteller-green", false)
    );

    this.loadBalancerSecGroup = new ec2.SecurityGroup(this, `${this.stackName}AlbSec`, {
      vpc: this.infra.vpc,
    });
    this.loadBalancerSecGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.allTraffic());

    this.publicLoadBalancer = new elbv2.ApplicationLoadBalancer(this, "Alb", {
      loadBalancerName: "public-load-balancer",
      vpc: this.infra.vpc,
      internetFacing: true,
      vpcSubnets: {
        subnetType: ec2.SubnetType.PUBLIC,
      },
    });
    this.publicLoadBalancer.addSecurityGroup(this.loadBalancerSecGroup);

    this.colorTellerGatewayServiceDiscovery.registerLoadBalancer("Rg", this.publicLoadBalancer);
  }

  private buildDnsServiceProps = (serviceName: string, lb: boolean): service_discovery.DnsServiceProps => {
    return {
      name: serviceName,
      dnsRecordType: service_discovery.DnsRecordType.A,
      loadBalancer: lb,
      dnsTtl: Duration.seconds(300),
      customHealthCheck: {
        failureThreshold: 1,
      },
    };
  };

  public getCloudMapSerivce = (serviceName: string): service_discovery.Service => {
    switch (serviceName.toLowerCase()) {
      case this.infra.SERVICE_GATEWAY:
        return this.colorTellerGatewayServiceDiscovery;
      case this.infra.SERVICE_WHITE:
        return this.colorTellerWhiteServiceDiscovery;
      case this.infra.SERVICE_GREEN:
        return this.colorTellerGreenServiceDiscovery;
      default:
        return this.colorTellerWhiteServiceDiscovery;
    }
  };

  public getAppMeshServiceDiscovery = (serviceName: string): appmesh.ServiceDiscovery => {
    switch (serviceName.toLowerCase()) {
      case this.infra.SERVICE_WHITE:
        return appmesh.ServiceDiscovery.cloudMap(this.colorTellerWhiteServiceDiscovery);
      case this.infra.SERVICE_GREEN:
        return appmesh.ServiceDiscovery.cloudMap(this.colorTellerGreenServiceDiscovery);
      default:
        return appmesh.ServiceDiscovery.cloudMap(this.colorTellerWhiteServiceDiscovery);
    }
  };
}
