# AWS App Mesh

## Introduction

App Mesh makes it easy to run microservices by providing consistent visibility and network traffic controls for every microservice in an application. App Mesh separates the logic needed for monitoring and controlling communications into a proxy that runs next to every microservice. App Mesh removes the need to coordinate across teams or update application code to change how monitoring data is collected or traffic is routed. This allows you to quickly pinpoint the exact location of errors and automatically re-route network traffic when there are failures or when code changes need to be deployed.

You can use App Mesh with AWS Fargate, Amazon ECS, Amazon EKS, and Kubernetes on EC2 to better run containerized microservices at scale. App Mesh uses [Envoy](https://www.envoyproxy.io/), an open source proxy, making it compatible with a wide range of AWS partner and open source tools for monitoring microservices.

Learn more at https://aws.amazon.com/app-mesh

### Why use  App Mesh?

1. Streamline operations by offloading communication management logic from application code and libraries into configurable infrastructure.
2. Reduce troubleshooting time required by having end-to-end visibility into service-level logs, metrics and traces across your application.
3. Easily roll out of new code by configuring routes to new application versions.
4. Ensure high-availability with custom routing rules that help ensure every service is highly available during deployments, after failures, and as your application scales.
5. Manage all service to service traffic using one set of APIs regardless of how the services are implemented.

### What makes AWS App Mesh unique?

App Mesh is built in direct response to our customers needs implementing a 'service mesh' for their applications. Our customers asked us to: 

* Make it easy to manage microservices deployed across accounts, clusters, container orchestration tools, and compute services with simple and consistent abstractions.
* Minimize the cognitive and operational overhead in running a microservices application and handling its monitoring and traffic control. 
* Remove the need to build or operate a control plane for service mesh.
* Use open source software to allow extension to new tools and different use cases.

In order to best meet the needs of our customers, we have invested into building a service that includes a control plane and API that follows the AWS best practices. Specifically, App Mesh: 

* Is an AWS managed service that works across container services with a design that allows us to add support for other computer services in the future.
* Works with open source Envoy proxy, and over time support most of its capabilities
* Is designed to pluggable and can support bringing your own Envoy and Istio Mixer in the future.
* Implemented as a multi-tenant control plane to be scalable, robust, cost-effective, and efficient.
* Built to work independently of any particular container orchestration system. Today, App Mesh works with both Kubernetes and Amazon ECS.

## Availability

### App Mesh is in Preview

Today, AWS App Mesh is available in preview. During the preview we will add new features, improve the user and operational experience, and incorporate the feedback you give us. We will actively share how you can use App Mesh, what you can use it for, and provide example applications to help you get started. We have a big vision and aggressive roadmap to support all your use cases and we want your input to tell us what makes sense and what we may have missed. We expect App Mesh to be generally available in late Q1 2019.

Today, you can use AWS App Mesh with services running on Amazon ECS (with awsvpc networking mode) or Amazon EKS. You can:

* connect applications using API, 
* Bootstrap Envoy and connect to XDS endpoint provided by App Mesh.
* Configure routes 
* ~~[optional] configure dashboards using cloudwatch or grafana etc.~~ To be added later based on what Tony provides

### Roadmap

Here is what we are working on between preview and GA [GA Roadmap](https://github.com/awslabs/aws-app-mesh/issues?utf8=%E2%9C%93&q=is%3Aissue+is%3Aopen+label%3A%22GA%22+label%3A%22Roadmap%22) and [post-GA Roadmap](https://github.com/awslabs/aws-app-mesh/issues?utf8=%E2%9C%93&q=is%3Aissue+is%3Aopen+label%3A%22post-GA%22+label%3A%22Roadmap%22)

Here are some [FAQs about Preview](FAQ.md)

### Questions?

* About Features/Use cases: (https://github.com/awslabs/aws-app-mesh/issues)
* About Usage clarifications/ Issues: (https://github.com/awslabs/aws-app-mesh/issues)
* Other discussion: [Get invited to #containers on AWS Developers [awsdevelopers.slack.com]](slack)

## License Summary

This sample code is made available under a modified MIT license. See the LICENSE file.
