import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as iam from "aws-cdk-lib/aws-iam";
import * as logs from "aws-cdk-lib/aws-logs";
import * as assets from "aws-cdk-lib/aws-ecr-assets";

import { RemovalPolicy, Stack, StackProps } from "aws-cdk-lib";
import { Construct } from "constructs";
import { RetentionDays } from "aws-cdk-lib/aws-logs";
import { InstanceClass, InstanceSize } from "aws-cdk-lib/aws-ec2";

import * as path from "path";

export class InfraStack extends Stack {
  readonly vpc: ec2.Vpc;
  readonly cluster: ecs.Cluster;
  readonly logGroup: logs.LogGroup;
  readonly bastionSecurityGroup: ec2.SecurityGroup;
  readonly bastionHost: ec2.BastionHostLinux;
  readonly keyPair: ec2.CfnKeyPair;

  readonly customEnvoyImageAsset: assets.DockerImageAsset;
  readonly colorTellerImageAsset: assets.DockerImageAsset;

  readonly taskRole: iam.Role;
  readonly executionRole: iam.Role;

  readonly serviceWhite: string = "white";
  readonly serviceGreen: string = "green";
  readonly serviceGateway: string = "gateway";

  readonly appDir: string = "../../src";

  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    this.vpc = new ec2.Vpc(this, `${this.stackName}Vpc`, {});

    this.cluster = new ecs.Cluster(this, `${this.stackName}Cluster`, {
      vpc: this.vpc,
      clusterName: this.node.tryGetContext("ENVIRONMENT_NAME"),
    });

    this.logGroup = new logs.LogGroup(this, `${this.stackName}LogGroup`, {
      removalPolicy: RemovalPolicy.DESTROY,
      retention: RetentionDays.ONE_DAY,
    });

    this.taskRole = new iam.Role(this, `${this.stackName}TaskRole`, {
      assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
      managedPolicies: this.addManagedPolices(
        1,
        "CloudWatchFullAccess",
        "AWSXRayDaemonWriteAccess",
        "AWSAppMeshEnvoyAccess",
        "AWSAppMeshFullAccess",
        "SecretsManagerReadWrite"
      ),
    });

    this.executionRole = new iam.Role(this, `${this.stackName}ExecutionRole`, {
      assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
      managedPolicies: this.addManagedPolices(2, "AmazonEC2ContainerRegistryReadOnly", "CloudWatchLogsFullAccess"),
    });

    this.bastionSecurityGroup = new ec2.SecurityGroup(this, `${this.stackName}BastionSecurityGroup`, {
      vpc: this.vpc,
      securityGroupName: "bastion-security-group",
    });
    this.bastionSecurityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(22));

    this.bastionHost = new ec2.BastionHostLinux(this, `${this.stackName}BastionHost`, {
      vpc: this.vpc,
      securityGroup: this.bastionSecurityGroup,
      instanceName: "bastion-host",
      machineImage: ec2.MachineImage.latestAmazonLinux(),
      instanceType: ec2.InstanceType.of(InstanceClass.T2, InstanceSize.MICRO),
      subnetSelection: { subnetType: ec2.SubnetType.PUBLIC },
    });
    this.bastionHost.instance.instance.addPropertyOverride("KeyName", process.env.KEY_PAIR_NAME!);

    this.customEnvoyImageAsset = this.buildImageAsset(
      path.join(__dirname, this.appDir, "customEnvoyImage"),
      "CustomEnvoyImage",
      {
        AWS_DEFAULT_REGION: process.env.CDK_DEFAULT_REGION!,
        ENVOY_IMAGE: this.node.tryGetContext("ENVOY_IMAGE"),
      }
    );

    this.colorTellerImageAsset = this.buildImageAsset(
      path.join(__dirname, this.appDir, "colorteller"),
      "ColorTellerImage",
      {
        GO_PROXY: this.node.tryGetContext("GO_PROXY"),
      }
    );
  }

  private buildImageAsset = (
    dockerFilePath: string,
    name: string,
    args: { [key: string]: string }
  ): assets.DockerImageAsset => {
    return new assets.DockerImageAsset(this, `${this.stackName}${name}Asset`, {
      directory: dockerFilePath,
      platform: assets.Platform.LINUX_AMD64,
      buildArgs: args,
    });
  };
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
