import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as ecs from "aws-cdk-lib/aws-ecs";
import * as logs from "aws-cdk-lib/aws-logs";
import * as iam from "aws-cdk-lib/aws-iam";
import * as service_discovery from "aws-cdk-lib/aws-servicediscovery";
import { Construct } from "constructs";
import { Stack, StackProps, RemovalPolicy } from "aws-cdk-lib";

export class BaseStack extends Stack {
  readonly vpc: ec2.Vpc;
  readonly cluster: ecs.Cluster;
  readonly dnsNameSpace: service_discovery.PrivateDnsNamespace;
  readonly logGroup: logs.LogGroup;
  readonly executionRole: iam.Role;
  readonly taskRole: iam.Role;

  readonly projectName: string;
  readonly port: number;
  readonly meshName: string;

  readonly serviceBackend = "backend";
  readonly serviceBackend1 = "backend-1";
  readonly serviceFrontend = "frontend";

  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    this.projectName = this.node.tryGetContext("PROJECT_NAME");
    this.port = parseInt(this.node.tryGetContext("CONTAINER_PORT"), 10);
    this.meshName = this.node.tryGetContext("MESH_NAME");

    this.taskRole = new iam.Role(this, `${this.stackName}TaskRole`, {
      assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
      managedPolicies: this.addManagedPolices(
        1,
        "CloudWatchFullAccess",
        "AWSXRayDaemonWriteAccess",
        "AWSAppMeshEnvoyAccess",
        "AWSAppMeshFullAccess"
      ),
    });

    this.executionRole = new iam.Role(this, `${this.stackName}ExecutionRole`, {
      assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
      managedPolicies: this.addManagedPolices(
        2,
        "CloudWatchFullAccess",
        "AWSXRayDaemonWriteAccess",
        "AWSAppMeshEnvoyAccess",
        "AWSAppMeshFullAccess"
      ),
    });

    this.vpc = new ec2.Vpc(this, `${this.stackName}Vpc`, {
      cidr: "10.0.0.0/16",
    });

    this.cluster = new ecs.Cluster(this, `${this.stackName}Cluster`, {
      clusterName: this.projectName,
      vpc: this.vpc,
    });

    this.dnsNameSpace = new service_discovery.PrivateDnsNamespace(this, `${this.stackName}DNSNamespace`, {
      name: "local",
      vpc: this.vpc,
    });

    this.logGroup = new logs.LogGroup(this, `${this.stackName}LogGroup`, {
      logGroupName: this.projectName,
      retention: logs.RetentionDays.ONE_DAY,
      removalPolicy: RemovalPolicy.DESTROY,
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
