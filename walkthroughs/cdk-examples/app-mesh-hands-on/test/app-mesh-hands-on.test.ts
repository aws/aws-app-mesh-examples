import * as cdk from "aws-cdk-lib";
import { Template, Match } from "aws-cdk-lib/assertions";
import { BaseStack } from "../lib/stacks/base";
import { MeshStack } from "../lib/stacks/mesh-components";
import { ServiceDiscoveryStack } from "../lib/stacks/service-discovery";

const app = new cdk.App();
const base = new BaseStack(app, "base");
const serviceDiscovery = new ServiceDiscoveryStack(base, "service-discovery");
const mesh = new MeshStack(serviceDiscovery, "mesh");

const baseTemplate = Template.fromStack(base);
const meshTemplate = Template.fromStack(mesh);

// Test Base
describe(`When I create ${base.stackName}`, () => {
  test("There should be 2 IAM roles", () => {
    baseTemplate.resourceCountIs("AWS::IAM::Role", 2);
  });

  test("The IAM roles should have proper policies attached to them", () => {
    baseTemplate.hasResourceProperties("AWS::IAM::Role", {
      ManagedPolicyArns: Match.arrayWith([
        "arn:aws:iam::aws:policy/CloudWatchFullAccess",
        "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess",
        "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess",
        "arn:aws:iam::aws:policy/AWSAppMeshFullAccess",
      ]),
    });
  });
  baseTemplate.hasResourceProperties("AWS::IAM::Role", {
    ManagedPolicyArns: Match.arrayWith([
      "arn:aws:iam::aws:policy/CloudWatchFullAccess",
      "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess",
      "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess",
      "arn:aws:iam::aws:policy/AWSAppMeshFullAccess",
    ]),
  });

  test("There should be 3 CloudMap services", () => {
    baseTemplate.resourceCountIs("AWS::ServiceDiscovery::Service", 3);
  });

  test("The names of the services should be: 'backend', 'backend-1 and 'frontend '", () => {
    baseTemplate.hasResourceProperties("AWS::ServiceDiscovery::Service", {
      Name: "backend",
    });
    baseTemplate.hasResourceProperties("AWS::ServiceDiscovery::Service", {
      Name: "backend-1",
    });
    baseTemplate.hasResourceProperties("AWS::ServiceDiscovery::Service", {
      Name: "frontend",
    });
  });
});

describe(`When I create ${mesh.stackName}`, () => {
  test("The should be 1 mesh, 1 route, 1 virtual service, 1 virtual router and  3 virtual nodes", () => {
    meshTemplate.resourceCountIs("AWS::AppMesh::Mesh", 1);
    meshTemplate.resourceCountIs("AWS::AppMesh::Route", 1);
    meshTemplate.resourceCountIs("AWS::AppMesh::VirtualNode", 3);
    meshTemplate.resourceCountIs("AWS::AppMesh::VirtualRouter", 1);
    meshTemplate.resourceCountIs("AWS::AppMesh::VirtualService", 1);
  });

  test("The name of the virtual nodes should be properly configured", () => {
    meshTemplate.hasResourceProperties("AWS::AppMesh::VirtualNode", {
      VirtualNodeName: "backend-vn",
    });
    meshTemplate.hasResourceProperties("AWS::AppMesh::VirtualNode", {
      VirtualNodeName: "backend-1-vn",
    });
    meshTemplate.hasResourceProperties("AWS::AppMesh::VirtualNode", {
      VirtualNodeName: "frontend-vn",
    });
  });

  test("The name of the virtual service should be properly configured", () => {
    meshTemplate.hasResourceProperties("AWS::AppMesh::VirtualService", {
      VirtualServiceName: "backend.local",
    });
  });

  test("The virtual route should match with the '/' prefix", () => {
    meshTemplate.hasResourceProperties("AWS::AppMesh::Route", {
      Spec: { HttpRoute: Match.objectLike({ Match: { Prefix: "/" } }) },
    });
  });
});
