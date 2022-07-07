import * as cdk from "aws-cdk-lib";
import { Template, Match } from "aws-cdk-lib/assertions";
import { BaseStack } from "../lib/stacks/base";
import { ECSServicesStack } from "../lib/stacks/ecs-services";
import { MeshStack } from "../lib/stacks/mesh-components";
import { ServiceDiscoveryStack } from "../lib/stacks/service-discovery";

// Define stacks and templates
const app = new cdk.App();
const base = new BaseStack(app, "base");
const serviceDiscovery = new ServiceDiscoveryStack(base, "service-discovery");
const mesh = new MeshStack(serviceDiscovery, "mesh");
// const ecs = new ECSServicesStack()
const baseTemplate = Template.fromStack(base);
const serviceDiscoveryTemplate = Template.fromStack(serviceDiscovery);
const meshTemplate = Template.fromStack(mesh);
// Test BaseStack
console.log(`Running tests for ${base.stackName}`);
test("Base Stack has 2 IAM Roles", () => {
  baseTemplate.resourceCountIs("AWS::IAM::Role", 2);
});

test("Task role has CloudWatch, App Mesh and Xray Access", () => {
  baseTemplate.hasResourceProperties("AWS::IAM::Role", {
    ManagedPolicyArns: Match.arrayWith([
      "arn:aws:iam::aws:policy/CloudWatchFullAccess",
      "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess",
      "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess",
    ]),
  });
});

test("Task execution role has CloudWatch access", () => {
  baseTemplate.hasResourceProperties("AWS::IAM::Role", {
    ManagedPolicyArns: Match.arrayWith(["arn:aws:iam::aws:policy/CloudWatchFullAccess"]),
  });
});

// Test ServiceDiscoveryStack
console.log(`Running tests for ${serviceDiscovery.stackName}`);
test("There are 2 ALBs and 1 RecordSet", () => {
  serviceDiscoveryTemplate.resourceCountIs("AWS::ElasticLoadBalancingV2::LoadBalancer", 2);
  serviceDiscoveryTemplate.resourceCountIs("AWS::Route53::RecordSet", 1);
});

test("There is 1 public and 1 internal ALB", () => {
  serviceDiscoveryTemplate.hasResourceProperties("AWS::ElasticLoadBalancingV2::LoadBalancer", {
    Scheme: "internal",
  });
  serviceDiscoveryTemplate.hasResourceProperties("AWS::ElasticLoadBalancingV2::LoadBalancer", {
    Scheme: "internet-facing",
  });
});

test("The name of the backend record set is proper", () => {
  serviceDiscoveryTemplate.hasResourceProperties("AWS::Route53::RecordSet", {
    Name: `backend.${base.PROJECT_NAME}.hosted.local.`,
  });
});

// Test MeshStack
console.log(`Running tests for ${mesh.stackName}`);
test("The number of mesh components is proper", () => {
  meshTemplate.resourceCountIs("AWS::AppMesh::Mesh", 1);
  meshTemplate.resourceCountIs("AWS::AppMesh::Route", 1);
  meshTemplate.resourceCountIs("AWS::AppMesh::VirtualNode", 3);
  meshTemplate.resourceCountIs("AWS::AppMesh::VirtualRouter", 1);
  meshTemplate.resourceCountIs("AWS::AppMesh::VirtualService", 1);
});

test("All virtual nodes have proper names", () => {
  meshTemplate.hasResourceProperties("AWS::AppMesh::VirtualNode", {
    VirtualNodeName: `${base.PROJECT_NAME}-${base.SERVICE_BACKEND_V1}-node`,
  });
  meshTemplate.hasResourceProperties("AWS::AppMesh::VirtualNode", {
    VirtualNodeName: `${base.PROJECT_NAME}-${base.SERVICE_BACKEND_V2}-node`,
  });
  meshTemplate.hasResourceProperties("AWS::AppMesh::VirtualNode", {
    VirtualNodeName: `${base.PROJECT_NAME}-${base.SERVICE_FRONTEND}-node`,
  });
});

test("The virtual service name is proper", () => {
  meshTemplate.hasResourceProperties("AWS::AppMesh::VirtualService", {
    VirtualServiceName: `backend.${base.PROJECT_NAME}.hosted.local`,
  });
});

test("The virtual route has a proper prefix match", () => {
  meshTemplate.hasResourceProperties("AWS::AppMesh::Route", {
    Spec: { HttpRoute: Match.objectLike({ Match: { Prefix: "/" } }) },
  });
});