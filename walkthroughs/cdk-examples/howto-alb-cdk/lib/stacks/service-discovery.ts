import * as route53 from "aws-cdk-lib/aws-route53";
import * as route53_targets from "aws-cdk-lib/aws-route53-targets";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import * as service_discovery from "aws-cdk-lib/aws-servicediscovery";
import { Stack, StackProps, Duration } from "aws-cdk-lib";
import { BaseStack } from "./base";

export class ServiceDiscoveryStack extends Stack {
  base: BaseStack;
  frontendLoadBalancer: elbv2.ApplicationLoadBalancer;
  backendV1LoadBalancer: elbv2.ApplicationLoadBalancer;
  backendRecordSet: route53.RecordSet;
  backendV2CloudMapService: service_discovery.Service;

  constructor(base: BaseStack, id: string, props?: StackProps) {
    super(base, id, props);

    this.base = base;

    // Internal Load balancer for backend service v1
    this.backendV1LoadBalancer = new elbv2.ApplicationLoadBalancer(
      this,
      "BackendV1LoadBalancer",
      {
        loadBalancerName: "backend-v1",
        vpc: this.base.vpc,
        internetFacing: false,
      }
    );

    this.backendRecordSet = new route53.RecordSet(this, "BackendRecordSet", {
      recordType: route53.RecordType.A,
      zone: this.base.dnsHostedZone,
      target: route53.RecordTarget.fromAlias(
        new route53_targets.LoadBalancerTarget(this.backendV1LoadBalancer)
      ),
      recordName: `backend.${this.base.dnsHostedZone.zoneName}`,
    });

    // CloudMap registry for backend service v2
    this.backendV2CloudMapService = this.base.dnsNameSpace.createService(
      `BackendV2CloudMapService`,
      {
        name: "backend-v2",
        dnsRecordType: service_discovery.DnsRecordType.A,
        dnsTtl: Duration.seconds(300),
        customHealthCheck: {
          failureThreshold: 1,
        },
      }
    );

    // Public Load balancer for front end service
    this.frontendLoadBalancer = new elbv2.ApplicationLoadBalancer(
      this,
      "FrontendLoadBalancer",
      {
        loadBalancerName: "frontend",
        vpc: this.base.vpc,
        internetFacing: true,
      }
    );
  }
}
