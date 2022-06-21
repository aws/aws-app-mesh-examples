import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as appmesh from 'aws-cdk-lib/aws-appmesh';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as assets from 'aws-cdk-lib/aws-ecr-assets';
import * as route53 from 'aws-cdk-lib/aws-route53';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as service_discovery from 'aws-cdk-lib/aws-servicediscovery';
import { Construct } from 'constructs';
import { Stack, StackProps, RemovalPolicy } from 'aws-cdk-lib';

export class BaseStack extends Stack {

    readonly vpc: ec2.Vpc;
    readonly accountId: string;
    readonly cluster: ecs.Cluster;
    readonly dnsHostedZone: route53.HostedZone;
    readonly dnsNameSpace: service_discovery.PrivateDnsNamespace;
    //readonly cloudMapService: service_discovery.Service;
    readonly mesh: appmesh.Mesh;
    readonly backendAppImageAsset: assets.DockerImageAsset;
    readonly frontendAppImageAsset: assets.DockerImageAsset;
    readonly envoyImage: ecs.ContainerImage;
    readonly xrayDaemonImage: ecs.ContainerImage;

    readonly logGroup: logs.LogGroup;

    readonly executionRole: iam.Role;
    readonly taskRole: iam.Role;

    readonly projectName: string;
    readonly containerPort: number;
    readonly prefix: string = "Base";

    constructor(scope: Construct, id: string, props?: StackProps) {
        super(scope, id, props);

        this.projectName = this.node.tryGetContext('PROJECT_NAME');
        this.containerPort = this.node.tryGetContext('CONTAINER_PORT');

        const cloudWatchArn = iam.ManagedPolicy.
            fromManagedPolicyArn(this, 'CloudWatchFullAccessArn', 'arn:aws:iam::aws:policy/CloudWatchFullAccess');

        this.taskRole = new iam.Role(this, 'TaskRole', {
            assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
            managedPolicies: [
                cloudWatchArn,
                iam.ManagedPolicy.fromManagedPolicyArn(this, 'AWSXRayDaemonWriteAccessArn', 'arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess'),
                iam.ManagedPolicy.fromManagedPolicyArn(this, 'AWSAppMeshEnvoyAccessArn', 'arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess'),
            ],
        });

        this.executionRole = new iam.Role(this, 'ExecRole', {
            assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
            managedPolicies: [
                cloudWatchArn,
                iam.ManagedPolicy.
                    fromManagedPolicyArn(this, 'AmazonEC2ContainerRegistryReadOnlyArn', 'arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly'),
            ],
        });

        this.vpc = new ec2.Vpc(this, 'EcrVpc')

        this.cluster = new ecs.Cluster(this, 'Cluster',
            {
                clusterName: this.projectName,
                vpc: this.vpc,
                // executeCommandConfiguration: {
                //     logging: ecs.ExecuteCommandLogging.OVERRIDE,
                // }
            });

        this.dnsHostedZone = new route53.HostedZone(this, 'DnsHostedZone', {
            zoneName: `${this.projectName}.hosted.local`,
            vpcs: [this.vpc],
        });

        this.dnsNameSpace = new service_discovery.PrivateDnsNamespace(this, 'DnsNameSpace', {
            name: `${this.projectName}.pvt.local`,
            vpc: this.vpc,
        });

        this.mesh = new appmesh.Mesh(this, 'Mesh', { meshName: this.projectName });

        this.backendAppImageAsset = new assets.DockerImageAsset(this, 'ColorAppImageAsset', {
            directory: './colorapp',
            platform: assets.Platform.LINUX_AMD64,
        });

        this.frontendAppImageAsset = new assets.DockerImageAsset(this, 'FeAppImageAsset', {
            directory: './feapp',
            platform: assets.Platform.LINUX_AMD64,
        });

        this.logGroup = new logs.LogGroup(this, 'LogGroup', {
            logGroupName: `${this.projectName}-log-group`,
            retention: logs.RetentionDays.ONE_DAY,
            removalPolicy: RemovalPolicy.DESTROY
        })

        this.envoyImage = ecs.ContainerImage.fromRegistry('public.ecr.aws/appmesh/aws-appmesh-envoy:v1.21.2.0-prod');
        this.xrayDaemonImage = ecs.ContainerImage.fromRegistry('public.ecr.aws/xray/aws-xray-daemon:3.3.3');
    }
}