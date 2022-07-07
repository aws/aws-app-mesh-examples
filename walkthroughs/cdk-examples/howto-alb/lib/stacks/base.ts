import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as ecs from "aws-cdk-lib/aws-ecs";
import * as assets from "aws-cdk-lib/aws-ecr-assets";
import * as route53 from "aws-cdk-lib/aws-route53";
import * as logs from "aws-cdk-lib/aws-logs";
import * as iam from "aws-cdk-lib/aws-iam";
import * as service_discovery from "aws-cdk-lib/aws-servicediscovery";
import { Construct } from "constructs";
import { Stack, StackProps, RemovalPolicy } from "aws-cdk-lib";

export class BaseStack extends Stack {
  readonly vpc: ec2.Vpc;
  readonly cluster: ecs.Cluster;
  readonly dnsHostedZone: route53.HostedZone;
  readonly dnsNameSpace: service_discovery.PrivateDnsNamespace;

  readonly backendAppImageAsset: assets.DockerImageAsset;
  readonly frontendAppImageAsset: assets.DockerImageAsset;

  readonly logGroup: logs.LogGroup;

  readonly executionRole: iam.Role;
  readonly taskRole: iam.Role;

  readonly PROJECT_NAME: string;
  readonly PORT: number;

  public readonly SERVICE_BACKEND_V1 = "backend-v1";
  public readonly SERVICE_BACKEND_V2 = "backend-v2";
  public readonly SERVICE_FRONTEND = "frontend";

  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    this.PROJECT_NAME = this.node.tryGetContext("PROJECT_NAME");
    this.PORT = this.node.tryGetContext("CONTAINER_PORT");

    this.taskRole = new iam.Role(this, `${this.stackName}TaskRole`, {
      assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
      managedPolicies: this.addManagedPolices(
        1,
        "CloudWatchFullAccess",
        "AWSXRayDaemonWriteAccess",
        "AWSAppMeshEnvoyAccess"
      ),
    });

    this.executionRole = new iam.Role(this, `${this.stackName}ExecutionRole`, {
      assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
      managedPolicies: this.addManagedPolices(2, "CloudWatchFullAccess"),
    });

    this.vpc = new ec2.Vpc(this, `${this.stackName}Vpc`, {
      cidr: "10.0.0.0/16",
    });

    this.cluster = new ecs.Cluster(this, `${this.stackName}Cluster`, {
      clusterName: this.PROJECT_NAME,
      vpc: this.vpc,
    });

    this.dnsHostedZone = new route53.HostedZone(this, `${this.stackName}DNSHostedZone`, {
      zoneName: `${this.PROJECT_NAME}.hosted.local`,
      vpcs: [this.vpc],
    });

    this.dnsNameSpace = new service_discovery.PrivateDnsNamespace(this, `${this.stackName}DNSNamespace`, {
      name: `${this.PROJECT_NAME}.pvt.local`,
      vpc: this.vpc,
    });

    this.logGroup = new logs.LogGroup(this, `${this.stackName}_LogGroup`, {
      logGroupName: `${this.PROJECT_NAME}-log-group`,
      retention: logs.RetentionDays.ONE_DAY,
      removalPolicy: RemovalPolicy.DESTROY,
    });

    this.backendAppImageAsset = new assets.DockerImageAsset(this, `${this.stackName}ColorAppImageAsset`, {
      directory: ".././howto-alb/colorapp",
      platform: assets.Platform.LINUX_AMD64,
    });

    this.frontendAppImageAsset = new assets.DockerImageAsset(this, `${this.stackName}FrontAppImageAsset`, {
      directory: ".././howto-alb/feapp",
      platform: assets.Platform.LINUX_AMD64,
    });
  }

  private addManagedPolices = (logicalId: number, ...policyNames: string[]): iam.IManagedPolicy[] => {
    const policies: iam.IManagedPolicy[] = [];
    policyNames.forEach((policyName) =>
      policies.push(
        iam.ManagedPolicy.fromManagedPolicyArn(
          this,
          `${policyName}${logicalId}Arn`,
          `arn:aws:iam::aws:policy/${policyName}`
        )
      )
    );
    return policies;
  };
}
