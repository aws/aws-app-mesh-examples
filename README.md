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
* ~~[optional] configure dashboards using cloudwatch or grafana etc. ~~To be added later based on what Tony provides

### Roadmap

Here is what we are working on between preview and GA [Link to a list of Issues which tag [Roadmap] and [pre-GA]] and [Link to Issues which tag [Roadmap] and [post-GA]]

Here are some FAQs about Preview [New page on FAQs for preview]

### Questions?

About Features/Use cases: [Link to Github Issues]
About Usage clarifications/ Issues: [Link to Github Issues]
Other discussion: [Get invited to #containers on AWS Developers [awsdevelopers.slack.com]]

## App Mesh Examples (Details on Preview  Workflows) [To be updated]

Note: This is not a replacement for the docs. Start with docs here: Link to Docs

Refer to these tutorials for a high level workflow on how to get started and use with ECS/EKS: 

### ECS: Canary routing on an ECS-App Mesh ready example app  [AWS App Mesh: Bug Bash Instructions](https://quip-amazon.com/uV6EAF1d0Vvr)

### ECS: Make your ECS example app ready for App Mesh <Link>

### EKS: Canary routing on an ECS-App Mesh ready example app  <Link>

### EKS: Make your ECS example app ready for App Mesh <Link>

Outline for Canary routing examples

    * Prerequisites
    * CloudFormation for stack that includes Envoy, routemgr images, config
    * Instructions on how to create Lattice config: nodes, router and routes 
    * Update routes to do canary routing
    * Instructions on how to check/validate what is going on 
    * Cleanup

Outline for ECS/EKS example app to get them to be App Mesh ready 

    * prerequisites
    * CloudFormation for stack that does not include Envoy, routemgr
    * List of environment variables etc to be set
    * Instructions on how to create nodes, router and routes 
    * Update routes to do canary routing
    * Instructions on how to check what is going on 
    * Cleanup

## Issues to pre-create 

### to indicate roadmap (Preview to GA) 

1. Observability Integrations
    1. Integration with X-Ray [Link] [high priority]
    2. Integration with CloudWatch [Link]
    3. Integration with DataDog [Link] [high priority]
    4. Other partner integrations
2. Traffic Routing
    1. HTTP Header and cookie based
    2. GRPC
    3. TCP, UDP
3. Service Discovery
    1.  EDS implementation - Integrated with AWS Cloud Map. Details: AWS Cloud Map to act as cross-service service registry for service endpoints and metadata. ECS already integrates with Cloud Map and we plan to build EKS connector to Cloud Map. 
    2. Bring your own SD: Primary mechanism will be via AWS Cloud Map. We are working with Hashicorp to build two-way sync between Consul and Skymap. 
4. Envoy Bootstrap
    1. CNI plugin based
    2. Build your own Envoy from source - Requires upstreaming Sigv4 Auth for Envoy and documentation on startup parameters
5. Traffic Shaping
    1. Retries,  Circuit Breaks, Health-checks, Mirroring, Fault-injection [High Priority]
6. Other
    1. Console workflows 
    2. Higher resource limits
    3. CloudTrail integration [High Priority]
    4. Tag based resource management [High Priority]
    5. Fargate support for initializing Envoy
    6. ECS integration with new controls for initializing Envoy into your tasks and better control over deployments of a service
    7. EKS controller/webhook
    8. CloudFormation support for App Mesh APIs
    9. Region expansion

### to indicate Post GA Roadmap

1. Security: End to End encryption of traffic 
    1. customer provided certs 
    2. integrations with ACM
2. Modeling routes at Ingress

### to ask for customer input

1. I want to use the mesh at ingress, not just between services <Please leave us a note below with details on your use cases (e.g.: use case not currently supported by ALB? as a layer behind my ALB to get consistent end to end metrics>
2. I want to bring my own Envoy image <Please leave us a note below with details on your use cases>
3. I want to use custom Envoy traffic filters <Please leave us a note below with details on your filters and what initialization/input configuration they would require>
4. I want to use mesh across services that are deployed in different accounts <Please leave us a note below with details on your networking setup between accounts (e.g.: currently using ALBs or VPC peering)>
5. Using ECS with other networking modes today (Bridge or Host) and need this density of ENIs per host to migrate to awsvpc <Leave us a note on the number of tasks per ECS instance you would like to run>
6. I use other networking modes today: <e.g.: my own CNIs, multiple VPCs within a cluster etc.>

## App Mesh Preview FAQs

1. **Q: Why should I use App Mesh? 
    **A: App Mesh makes it easy to get visibility and control over the communications between your microservices without writing new code or running additional AWS infrastructure. Using App Mesh, you can standardize how microservices communicate, implement rules for communications between microservices, and capture metrics, logs, and traces directly into AWS services and third-party tools of your choice.
2. **Q: How does App Mesh work? 
    **A: App Mesh sets up and manages a service mesh for your microservices. To do this, App Mesh runs the open source Envoy proxy alongside each microservice container and configures the proxy to handle all communications into and out of each container. 
3. **What is a service mesh?** A service mesh is a new software layer that handles all communication between microservices. It provides new features to connect, manage and secure interactions between microservices that is independent of application code as this software can be configured separately from applications.
4. **What can I do with App Mesh now when it is preview? **App Mesh makes it easier to debug and identify the root cause of communication issues between your services. App Mesh collects metrics including latencies, error rates, and connections per second, which can be exported to Amazon CloudWatch using a statsd collector or Prometheus. App Mesh also makes it easier to test new versions of your services before rolling out new deployments to all users. Using App Mesh APIs, you can route traffic based on HTTP path or weights to specific microservice versions, enabling canary style deployments. App Mesh now works with Amazon Elastic Container Services (ECS) and Amazon Elastic Container Service for Kubernetes (EKS).
5. **What can I do with App Mesh when it is generally available? **You can use App Mesh to send metrics, logs and traces to services of your choice. You can insert tracing to visualize a service map with details of API calls between services. You can also configure traffic policies like health checks, retries and circuit breaks for the clients that connect to your services. You can also perform traffic routing on several other protocols, and based on HTTP headers and query parameters.
6. **How do I get started with using App Mesh APIs? **You first use App Mesh APIs to create the mesh, virtual nodes, virtual routers and routes required to represent your services and to configure traffic routes between these services. You then setup endpoints (statsd or Prometheus) to export metrics and logs from the mesh proxy and configure these endpoints in the Envoy bootstrap configuration. Then, you add Lattice Envoy image into ECS task definition or EKS pod specification along with the parameter to connect it with the Lattice representation of this service, a virtual node. When this ECS service is deployed, Lattice configures Envoy to handle all inbound and outbound task traffic and applies the traffic controls configured using Lattice APIs. 
7. ****How does Lattice work with ?**** You first use Lattice APIs to create the mesh, virtual nodes, virtual routers and routes required to configure traffic routes between services that are mesh-enabled. You then setup endpoints (statsd or Prometheus) to export metrics, logs and traces from the mesh proxy and configure these endpoints in the Lattice Envoy bootstrap configuration. Then, you add Lattice Envoy image into K8S Pod Spec along with a parameter to connect it with the Lattice representation of this deployment, a virtual node. When this deployment is active, Lattice configures Envoy to handle all inbound and outbound pod traffic and applies the traffic controls configured using Lattice APIs. 
8. **Q: Is App Mesh managed Istio? Why are you not using Istio?
    **A: AWS App Mesh was built from the ground up to meet the needs of AWS customers that are running containers using AWS Fargate, Amazon ECS, Amazon EKS, and managing their own container orchestration system, e.g. self-managed Kubernetes. We also leveraged years of AWS expertise building managed control planes for large-scale services to create a service mesh that works for all customers building microservices on AWS. Based on our experience at AWS managing and operating services, single-tenant control-planes are not scalable, cost-effective and efficient. Therefore, we have started with building a robust, scalable service that meets the operational needs of our customers. We're continuing to build new features and add new capabilities to App Mesh. If there's a feature that you think is important we include, let us know [link]. 
9. **Q: Which version of Envoy do you use? Which versions do you plan to support? 
    **A: Today, App Mesh is using version 1.8.0.2. During the preview we will add support for X.
10. **Q: How do you authenticate that a malicious service on my cluster doesn't connect itself to the mesh? 
    **A: We have added Sigv4 based Authentication for Envoy proxies that connect to App Mesh. We plan to upstream this change to Envoy shortly.
11. **Q: Can I use App Mesh with Windows containers?
    **A: No. Today, Envoy is not yet supported by Windows.
12. **Q: What are the service limits at preview? **A: You can create 1 mesh per account with 10 virtual nodes (10 versioned services or 10 deployments) and 10 virtual routers per mesh and 1 route in each virtual router. If you need more, let us know [link]

1. **Q: Is there a performance impact from having Envoy in the data path?**
    A: Envoy is built for high performance. Using App Mesh should incur the same overhead as using Envoy without App Mesh.
2. **Q: What does App Mesh cost? 
    **A: There is no additional charge for using AWS App Mesh. You pay only for the AWS resources (i.e. EC2 instances or requested Fargate CPU and memory) consumed by the App Mesh proxy that runs alongside your containers. You pay only for what you use, as you use it; there are no minimum fees and no upfront commitment.
3. **Q: How do I start using App Mesh?
    ** A: App Mesh is available today as a pubic preview. You can start using App Mesh from the AWS CLI or SDK. Learn more at aws.amazon.com/appmesh/getting-started


Internal

Tagging structure
[Roadmap] → [pre-GA] or [post-GA]
[Bug]



