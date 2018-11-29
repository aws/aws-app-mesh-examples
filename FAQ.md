## App Mesh Preview FAQs

1. **Why should I use App Mesh?**<br/>
App Mesh makes it easy to get visibility and control over the communications between your microservices without writing new code or running additional AWS infrastructure. Using App Mesh, you can standardize how microservices communicate, implement rules for communications between microservices, and capture metrics, logs, and traces directly into AWS services and third-party tools of your choice.<br/>
1. **How does App Mesh work?**<br/>
App Mesh sets up and manages a service mesh for your microservices. To do this, App Mesh runs the open source Envoy proxy alongside each microservice container and configures the proxy to handle all communications into and out of each container. <br/>
1. **What can I do with App Mesh now when it is preview?** <br/>
App Mesh makes it easier to debug and identify the root cause of communication issues between your services. App Mesh collects logs and metrics including latencies, error rates, and connections per second, which can be exported to Amazon CloudWatch or Prometheus using a statsd collector. App Mesh enables you to connect and test new versions of your microservices before rolling it out to all users. App Mesh APIs provide traffic routing controls to enable canary style deployments. You can now route traffic based on HTTP path or weights to specific service versions. App Mesh now works with Amazon Elastic Container Services (ECS) and Amazon Elastic Container Service for Kubernetes (EKS).<br/>
1. **What can I do with App Mesh when it is generally available?**<br/>
You can use App Mesh to send metrics, logs and traces to services of your choice. You can insert tracing to visualize a service map with details of API calls between services. You can configure traffic policies like health checks, retries and circuit breaks for the clients that connect to your services. You can also perform traffic routing on several other protocols, and based on HTTP headers and query parameters.<br/>
1. **How do I get started with using App Mesh APIs?**<br/>
You can use App Mesh APIs to create the mesh and virtual nodes to represent your services. You then need to create virtual routers to configure traffic routes between these services. You then setup endpoints (statsd or Prometheus) to export metrics and logs from the mesh proxy and configure these endpoints in the Envoy bootstrap configuration - see detailed guide here (link). Then, you add App Mesh images into ECS task definition or EKS pod specification along with the environment variables required to virtual nodes. When these services get deployed, Envoys connect to App Mesh to get all the configuration required to handle all inbound and outbound task traffic according to the specified traffic routes.<br/>
1. **Which version of Envoy do you use?**<br/>
Today, App Mesh distributes a build of version 1.8.0 with an extensions for SigV4 that to ensure Envoy is authenticated propery with AWS authentication systems.We plan to upstream this change to Envoy soon.<br/>
1. **How do your nodes authenticate so that a malicious service on my cluster doesn't connect itself to the mesh?** <br/>
We have added Sigv4 based Authentication for Envoy proxies that connect to the App Mesh service via standard AWS authentication. We plan to upstream this change to Envoy soon.<br/>
1. **Are the service limits during the preview?**<br/>
You can create 1 mesh per account with 10 virtual nodes (10 versioned services or 10 deployments) and 10 virtual routers per mesh and 1 route in each virtual router.<br/>
1. **Is there a performance impact from having Envoy in the data path?**<br/>
Envoy is built for high performance. Using App Mesh should incur the same overhead as using Envoy without App Mesh.<br/>
1. **What does App Mesh cost?**<br/>
There is no additional charge for using AWS App Mesh. You pay only for the AWS resources (i.e. EC2 instances or requested Fargate CPU and memory) consumed by the App Mesh proxy that runs alongside your containers.<br/>
1. **How do I start using App Mesh?**<br/>
App Mesh is available today as a pubic preview. You can start using App Mesh from the AWS CLI or SDK. Learn more at aws.amazon.com/app-mesh/getting-started<br/>
