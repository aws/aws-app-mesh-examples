## AWS X-Ray

AWS X-Ray is a service that collects data about requests that your application serves, and provides tools you can use to view, filter, and gain insights into that data to identify issues and opportunities for optimization. For any traced request to your application, you can see detailed information not only about the request and response, but also about calls that your application makes to downstream AWS resources, micro-services, databases and HTTP web APIs.

## X-Ray and Envoy

X-Ray is built into the AWS AppMesh enabled Envoy, allowing you to see calls propagate and route on ingress and egress. Latency, throttling, errors, and exceptions can be grouped by user agent, status codes and others.

With filter expressions and groups, even the most complex service maps can be broken into logical components, allowing you to focus on a specific set of nodes.

1. Service Map

![](https://raw.githubusercontent.com/aws-samples/voting-app/master/images/xray-dashboard/envoy-service-map.png?token=AAJv-nGyiTz033TbhwfIswNWTeChiMlKks5cB-y8wA%3D%3D)

Each instance of Envoy is denoted by the "ServiceMesh::Envoy" node identifier. With the fully qualified dynamic name, you can easily determine the ingress and egress of each of your services.

By clicking on a "ServiceMesh::Envoy" node, and clicking "view traces", you can go to the trace overview page specific to that ingress/egress and group by various attributes.

2. Trace Overview

![](https://raw.githubusercontent.com/aws-samples/voting-app/master/images/xray-dashboard/envoy-trace-overview.png?token=AAJv-l6gqPq9Ydge7XDSldHxFH_4WHqGks5cB-z4wA%3D%3D)

On the trace view, you can group traces to view percentage distribution on various attributes. For example:

**URL**: The unique URL of the request
**StatusCode**: The HTTP status code of the response
**Error root cause message**: Shows the distributions of common error stack traces

3. Trace Details

![](https://raw.githubusercontent.com/aws-samples/voting-app/master/images/xray-dashboard/envoy-trace-details.png?token=AAJv-g-TYjWyV4XFyS76dj8E3VnXRJO2ks5cB-0gwA%3D%3D)

Drill down into a simple trace and see the time spent on each ingress and egress, and where that specific request was routed to and how much time was spent at each point. In the event of an error or exception, further information is available, such as stack trace or downstream error message capturing.
