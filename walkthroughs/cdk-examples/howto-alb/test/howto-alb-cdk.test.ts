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
const ecsServices = new ECSServicesStack(mesh, "ecs-services");

const baseTemplate = Template.fromStack(base);
const serviceDiscoveryTemplate = Template.fromStack(serviceDiscovery);
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
      ]),
    });
  });
  baseTemplate.hasResourceProperties("AWS::IAM::Role", {
    ManagedPolicyArns: Match.arrayWith(["arn:aws:iam::aws:policy/CloudWatchFullAccess"]),
  });
});

// Test ServiceDiscovery
describe(`When I create ${serviceDiscovery.stackName}`, () => {
  test("There should be 2 load balancers and 1 record set", () => {
    serviceDiscoveryTemplate.resourceCountIs("AWS::ElasticLoadBalancingV2::LoadBalancer", 2);
    serviceDiscoveryTemplate.resourceCountIs("AWS::Route53::RecordSet", 1);
  });

  test("There should be 1 internal load balancer and 1 internet facing load balancer", () => {
    serviceDiscoveryTemplate.hasResourceProperties("AWS::ElasticLoadBalancingV2::LoadBalancer", {
      Scheme: "internal",
    });
    serviceDiscoveryTemplate.hasResourceProperties("AWS::ElasticLoadBalancingV2::LoadBalancer", {
      Scheme: "internet-facing",
    });
  });

  test("The name of the record set should be properly configured", () => {
    serviceDiscoveryTemplate.hasResourceProperties("AWS::Route53::RecordSet", {
      Name: `backend.${base.PROJECT_NAME}.hosted.local.`,
    });
  });
});

// Test Mesh
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
      VirtualNodeName: `${base.PROJECT_NAME}-${base.SERVICE_BACKEND_V1}-node`,
    });
    meshTemplate.hasResourceProperties("AWS::AppMesh::VirtualNode", {
      VirtualNodeName: `${base.PROJECT_NAME}-${base.SERVICE_BACKEND_V2}-node`,
    });
    meshTemplate.hasResourceProperties("AWS::AppMesh::VirtualNode", {
      VirtualNodeName: `${base.PROJECT_NAME}-${base.SERVICE_FRONTEND}-node`,
    });
  });

  test("The name of the virtual service should be properly configured", () => {
    meshTemplate.hasResourceProperties("AWS::AppMesh::VirtualService", {
      VirtualServiceName: `backend.${base.PROJECT_NAME}.hosted.local`,
    });
  });

  test("The virtual route should match with the '/' prefix", () => {
    meshTemplate.hasResourceProperties("AWS::AppMesh::Route", {
      Spec: { HttpRoute: Match.objectLike({ Match: { Prefix: "/" } }) },
    });
  });
});
