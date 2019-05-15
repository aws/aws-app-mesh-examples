# AWS App Mesh

## Introduction

App Mesh makes it easy to run microservices by providing consistent visibility and network traffic controls for every microservice in an application. App Mesh separates the logic needed for monitoring and controlling communications into a proxy that runs next to every microservice. App Mesh removes the need to coordinate across teams or update application code to change how monitoring data is collected or traffic is routed. This allows you to quickly pinpoint the exact location of errors and automatically re-route network traffic when there are failures or when code changes need to be deployed.

You can use App Mesh with AWS Fargate, Amazon Elastic Container Service (ECS), Amazon Elastic Container Service for Kubernetes (EKS), and Kubernetes on EC2 to better run containerized microservices at scale. App Mesh uses [Envoy](https://www.envoyproxy.io/), an open source proxy, making it compatible with a wide range of AWS partner and open source tools for monitoring microservices.

Learn more at https://aws.amazon.com/app-mesh

## Availability

Today, AWS App Mesh is generally available for production use. You can use App Mesh with AWS Fargate, Amazon Elastic Container Service (ECS), Amazon Elastic Container Service for Kubernetes (EKS), applications running on Amazon EC2, and Kubernetes on EC2 to better run containerized microservices at scale. App Mesh uses Envoy, an open source proxy, making it compatible with a wide range of AWS partner and open source tools for monitoring microservices.

Learn more at https://aws.amazon.com/app-mesh

## Getting started

For help getting started with App Mesh, take a look at the [examples](https://github.com/aws/aws-app-mesh-examples/tree/master/examples) in this repo.

### Roadmap

The AWS App Mesh team maintains a [public roadmap](https://github.com/aws/aws-app-mesh-roadmap).

### Participate

If you have a suggestion, request, submission, or bug fix for the examples in this repo, please open it as an [Issue](https://github.com/aws/aws-app-mesh-examples/issues).  

If you have a feature request for AWS App Mesh, please open an Issue on the [public roadmap](https://github.com/aws/aws-app-mesh-roadmap).

## Security disclosures

If you think you’ve found a potential security issue, please do not post it in the Issues.  Instead, please follow the instructions [here](https://aws.amazon.com/security/vulnerability-reporting/) or [email AWS security directly](mailto:aws-security@amazon.com).

### Why use  App Mesh?

1. Streamline operations by offloading communication management logic from application code and libraries into configurable infrastructure.
2. Reduce troubleshooting time required by having end-to-end visibility into service-level logs, metrics and traces across your application.
3. Easily roll out of new code by dynamically configuring routes to new application versions.
4. Ensure high-availability with custom routing rules that help ensure every service is highly available during deployments, after failures, and as your application scales.
5. Manage all service to service traffic using one set of APIs regardless of how the services are implemented.

### What makes AWS App Mesh unique?

AWS App Mesh is built in direct response to our customers needs implementing a 'service mesh' for their applications. Our customers asked us to:

* Make it easy to manage microservices deployed across accounts, clusters, container orchestration tools, and compute services with simple and consistent abstractions.
* Minimize the cognitive and operational overhead in running a microservices application and handling its monitoring and traffic control.
* Remove the need to build or operate a control plane for service mesh.
* Use open source software to allow extension to new tools and different use cases.

In order to best meet the needs of our customers, we have invested into building a service that includes a control plane and API that follows the AWS best practices. Specifically, App Mesh:

* Is an AWS managed service that works across container services with a design that allows us to add support for other computer services in the future.
* Works with the open source Envoy proxy
* Is designed to pluggable and will support bringing your own Envoy images and Istio Mixer in the future.
* Implemented as a multi-tenant control plane to be scalable, robust, cost-effective, and efficient.
* Built to work independently of any particular container orchestration system. Today, App Mesh works with both Kubernetes and Amazon ECS.
