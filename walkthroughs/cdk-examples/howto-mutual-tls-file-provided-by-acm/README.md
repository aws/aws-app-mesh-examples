# About

In this walkthrough, we'll enable TLS encryption with mutual (two-way) authentication between two endpoints in App Mesh using X.509 certificates derived from ACM Private CA (ACM PCA). To provision infrastructure, we make use of the AWS Cloud Development Kit (CDK) V2. A non CDK version of this walkthrough is avaiable [here](https://github.com/aws/aws-app-mesh-examples/tree/main/walkthroughs/howto-mutual-tls-file-provided-by-acm).

In App Mesh, traffic encryption works between virtual nodes and virtual gateways, and thus between Envoys in your service mesh. This means your application code is not responsible for negotiating a TLS-encrypted session, instead allowing the local proxy to negotiate and terminate TLS on your application's behalf.

## Mutual TLS in App Mesh

In App Mesh, traffic encryption is originated and terminated by the Envoy proxy. This means your application code is not responsible for negotiating a TLS-encrypted connection, instead allowing the local proxy to negotiate and terminate TLS on your application's behalf.
In a basic TLS encryption scenario (for example, when your browser originates an HTTPS connection), the server would present a certificate to any client. **In Mutual TLS, both the client and the server present a certificate to each other, and both validate the peer's certificate.**

Validation typically involves checking at least that the certificate is signed by a trusted Certificate Authority, and that the certificate is still within its validity period.

In this guide, we will be configuring Envoy proxies using certificates sourced from ACM Private CA. The server-side certificate will be sourced internally between App Mesh and ACM PCA using the native integration between the two services.
The client-side certificate will be exported from ACM, stored in AWS Secrets Manager, and will be retrieved by a modified Envoy image during startup. Our Color App example uses a virtual gateway (ColorGateway) and a virtual node (ColorTeller) in App Mesh. The two services will be configured with separate Certificate Authorities (CAs) to demonstrate the full extent of cross-CA certificate validation in mTLS exchange.

# Prerequisites

- An active AWS account
- [`node`](https://nodejs.org/en/download/)
- [`npm`](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [AWS CDK (V2)](https://docs.aws.amazon.com/cdk/v2/guide/cli.html)
- [TypeScript](https://www.typescriptlang.org/download)
- [`aws-cdk-lib`](https://www.npmjs.com/package/aws-cdk-lib)
- [Docker](https://docs.docker.com/get-docker/)
- [`jq`](https://stedolan.github.io/jq/)

_Note - CDK uses default AWS credentials `~/.aws/credentials` and configuration `~/.aws/config` unless specified explicitly in the Stack. To learn more about this, click [here](https://docs.aws.amazon.com/cdk/v2/guide/environments.html)._

# Setup & Deployment

_Note - Standard AWS costs may apply when provisioning infrastructure._

- Open your terminal
- Clone the repository `git clone https://github.com/aws/aws-app-mesh-examples.git`
- Navigate to `aws-app-mesh-examples/walkthroughs/cdk-examples/howto-tls-file-provided/`

Let us start by exporting a key-pair name, that will be used to `ssh` into a Bastion host we will provision later.

```bash
export KEY_PAIR_NAME=<name of the key pair to use>
```

Optional: If you want to create a new key-pair, run these commands:

```bash
aws ec2 create-key-pair --key-name $KEY_PAIR_NAME | jq -r .KeyMaterial > ~/.ssh/$KEY_PAIR_NAME.pem
```

```bash
chmod 400 ~/.ssh/$KEY_PAIR_NAME.pem
```

Optional: Note that the example apps use Go modules. By default `"GO_PROXY": "direct"` in `cdk.json`. You can change this to `"GO_PROXY": "https://proxy.golang.org"`.

## Step 1: Deploying the App without TLS

We can now provision our infrastructure through CDK.

```bash
cdk bootstrap
```

```bash
cdk deploy --all --require-approval never --context mesh-update=no-tls
```

Once the entire infrastructure has been provisioned, you will see the following message on your terminal.

```c
✅  infra/svc-dscry/mesh/ecs-servcies (ecs-services)

✨  Deployment time: 184.42s

Outputs:
infrasvcdscrymeshecsservcies72069B44.BastionEndpoint = curl -s colorteller.mtls.svc.cluster.local:9901/stats | grep -E 'ssl.handshake|ssl.no_certificate'
infrasvcdscrymeshecsservcies72069B44.BastionIP = export BASTION_IP=XX.XX.XXX.XXX
infrasvcdscrymeshecsservcies72069B44.URL = export URL=gateway-XXXXXXXXX.us-west-1.elb.amazonaws.com
Stack ARN:
arn:aws:cloudformation:us-west-1:XXXXXXXXXX:stack/ecs-services/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXX

✨  Total time: 187.14s
```

We can see that the deployment produces three outputs:

- `URL` - which is the DNS name of the public Application Load Balancer (ALB).
- `BastionIP` - which is the public IP address of the Bastion Host.
- `BastionEndpoint` - we will use this to query the Virtual Service from the Bastion Host.

Let's set the `URL` and `BASTION_IP` in our environment.

```bash
export BASTION_IP=<BastionIP>
export URL=<URL>
```

### Color Teller Response

- Let's query the gateway load balancer.

```bash
curl $URL/color
YELLOW%
```

- We can see that the Color Teller node returns a response

### Bastion Host Response

- To verify the TLS status, we can query the Envoy sidecar for stats about the certficate and handshake status.
- Enter the Bastion Host with the following command.

```bash
ssh -i ~/.ssh/$KEY_PAIR_NAME.pem ec2-user@$BASTION_IP
```

- After following the prompts, copy the `BastionEndpoint` output and run it in the Bastion Host.

```bash
[ec2-user@ip-XX-X-XX-XXX ~]$ curl -s colorteller.mtls.svc.cluster.local:9901/stats | grep -E 'ssl.handshake|ssl.no_certificate'
[ec2-user@ip-XX-X-XX-XXX ~]$
```

- Since there is no TLS encyption in the mesh, Envoy will not emit any stats and no results will be displayed.

- Type `exit` and hit enter to exit the Bastion Host.

## Step 2: Enabling Strict TLS Termination

- Let us provision another deployment with TLS enabled in the mesh. This update will add TLS termination to the Virtual Node and Gateway.

```bash
cdk deploy --all --require-approval never --context mesh-update=one-way-tls
```

- On the AWS console, wait for the services to finish updating with a new deployment.

- The ColorTeller Virtual node fetches the certificate from the ACM PCA.
- The ColorGateway validates the request using the Root CA, also provided by ACM PCA.

### Color Teller Response

- Let's query the gateway load balancer.

```bash
curl $URL/color
YELLOW%
```

- We can see that the Color Teller node returns a response

### Bastion Host Response

- Let us once again query the `BastionEndpoint` to get the TLS stats emitted by the Envoy sidecar.

```bash
ssh -i ~/.ssh/$KEY_PAIR_NAME.pem ec2-user@$BASTION_IP
```

```bash
[ec2-user@ip-XX-X-XX-XXX ~]$ curl -s colorteller.mtls.svc.cluster.local:9901/stats | grep -E 'ssl.handshake|ssl.no_certificate'
listener.0.0.0.0_15000.ssl.handshake: 1
listener.0.0.0.0_15000.ssl.no_certificate: 1
```

- This time, Envoy emits stats that show the handshake status `listener.0.0.0.0_15000.ssl.handshake: 1`
- Note that `listener.0.0.0.0_15000.ssl.no_certificate` returns a non-zero response. This stat shows the number of successfull connections in which no client side certificate was provided. Right now, both these metrics should return this same non-zero value. This will change once we add client side validation using mTLS.

## Step 3: Enabling Client Validation with Mutual TLS

- Let us provision another deployment with TLS enabled in the mesh. This update will add TLS termination to the Virtual Node and Gateway.

```bash
cdk deploy --all --require-approval never --context mesh-update=mtls
```

- On the AWS console, wait for the services to finish updating with a new deployment.

- The ColorTeller Virtual Node and ColorGateway Virtual Gateway will both validate the certificates provided by ACM PCA authorities.
- The client-side certificate will be exported from ACM, stored in AWS Secrets Manager, and will be retrieved by a modified Envoy image during startup.
- App Mesh does not support an integration with ACM for mTLS at this time. This walkthrough integrates ACM with ACM-PCA and allows the certificates to be rotated upon expiry using the RenewCertificate API from AWS ACM. After the certificate is rotated, the AWS Secrets Manager updates the services to fetch the renewed certificates.

### Color Teller Response

- Let's query the gateway load balancer.

```bash
curl $URL/color
YELLOW%
```

- We can see that the Color Teller node returns a response

### Bastion Host Response

- Let us once again query the `BastionEndpoint` to get the TLS stats emitted by the Envoy sidecar.

```bash
ssh -i ~/.ssh/$KEY_PAIR_NAME.pem ec2-user@$BASTION_IP
```

```bash
[ec2-user@ip-XX-X-XX-XXX ~]$ curl -s colorteller.mtls.svc.cluster.local:9901/stats | grep -E 'ssl.handshake|ssl.no_certificate'
listener.0.0.0.0_15000.ssl.handshake: 1
listener.0.0.0.0_15000.ssl.no_certificate: 0
```

- This time, since both entities are validating each other, we can see that the `listener.0.0.0.0_15000.ssl.no_certificate` emits 0. This means that successfull mTLS authentication was added to the service mesh.

# Cleanup

- Navigate to your project directory
- Run `cdk destroy --all` and hit `y` when the prompt appears. The cleanup process might take a few minutes.

```bash
cdk destroy --all
Are you sure you want to delete: infra/svc-dscvry/mesh/ecs-services, infra/svc-dscvry/mesh, infra/svc-dscvry, infra, secrets (y/n)? y
```

# CDK Code

<details>
<summary><b>Expand this section to learn more about provisioning App Mesh resources using custom CDK constructs</b></summary>

## Stacks and Constructs

There are a total of 5 Stacks that provision all the infrastructure for the example.

_Note - The `cdk bootstrap` command provisions a `CDKToolkit` Stack to deploy AWS CDK apps into your cloud enviroment._

1. `SecretsStack` - provisions the generated certficates as plaintext secrets in AWS Secrets Manager.
1. `InfraStack` - provisions the network infrastructure like the VPC, ECS Cluster, IAM Roles and the Docker images that are pushed to the ECR Repository.
1. `ServiceDiscoveryStack` - provisions 3 CloudMap services that are used for service discovery by App Mesh.
1. `MeshStack` - provisions the different mesh components like the frontend and backend virtual nodes, virtual router and the backend virtual gateway.
1. `EcsServicesStack` - this stack provisions the 3 Fargate services using a custom construct `AppMeshFargateService` which encapsulates the application container and Envoy sidecar/proxy into a single construct allowing us to easily spin up different 'meshified' Fargate Services.

Two more constructs - `EnvoySidecar` and `ApplicationContainer` bundle the common container options used by these Fargate service task definitions.

<p align="center">
  <img src="assets/stacks_tls.png">
</p>

The order mentioned above also represents the dependency these Stacks have on eachother. In this case, since we are deploying the `EnvoySidecar` containers along with our application code, it is necessary for the mesh components to be provisioned before the services are running, so the Envoy proxy can locate them using the `APPMESH_RESOURCE_ARN` environment variable.

These dependencies are propagated by passing the Stack objects in the `constructor` of their referencing Stack.

```c
// howto-tls-file-provided.ts
const infra = new InfraStack(app, "infra", { stackName: "infra" });
const serviceDiscovery = new ServiceDiscoveryStack(infra, "svc-dscvry", { stackName: "svc-dscvry" });
```

## App Mesh CDK Constructs

To easily define Fargate services with Envoy proxies, we make use of the `AppMeshFargateService` construct mentioned above. The main purpose of this construct is to bundle the application containers with the Envoy sidecar and proxy. To do so, we define a set of custom props in `lib/utils.ts` called `AppMeshFargateServiceProps`.

```c
// utils.ts
export interface EnvoyConfiguration {
  container: EnvoySidecar;
  proxyConfiguration?: ecs.ProxyConfiguration;
}

export interface AppMeshFargateServiceProps {
  serviceName: string;
  taskDefinitionFamily: string;
  serviceDiscoveryType?: ServiceDiscoveryType;
  applicationContainer: ApplicationContainer;
  envoyConfiguration?: EnvoyConfiguration;
}

```

Note that the `proxyConfiguration` prop in `EnvoyConfiguration` is separate because the Envoy sidecar container can exist own its own without acting as a proxy, but for it to act as a proxy there must be a running container with the name mentioned in the proxy configuration. These props are passed to instantiate Fargate Services in the `EcsServicesStack`. Once the attributes are passed to the construct, simple conditional checks can be used to add container dependencies and appropriate service discovery mechanisms for the different services.

The crux of the mesh infrastructure lies in the `Mesh` stack.

## Project Structure & Context

The skeleton of the project is generated using the `cdk init app --language typescript` command. By default, your main `node` app sits in the `bin` folder and the cloud infrastructure is provisioned in the `lib` folder.

The `cdk.json` file allows us to populate configuration variables in the `context`. In this example, you can see the `ENVOY_IMAGE` variable is defined here and then fetched in the `InfraStack` using the `tryGetContext` method.

</details>

# Learn more about App Mesh

- [How to use ACM Private CA for enabling mTLS in AWS App Mesh](https://aws.amazon.com/blogs/security/how-to-use-acm-private-ca-for-enabling-mtls-in-aws-app-mesh/)
- [Product Page](https://aws.amazon.com/app-mesh/?nc2=h_ql_prod_nt_appm&aws-app-mesh-blogs.sort-by=item.additionalFields.createdDate&aws-app-mesh-blogs.sort-order=desc&whats-new-cards.sort-by=item.additionalFields.postDateTime&whats-new-cards.sort-order=desc)
- [App Mesh under the hood](https://www.youtube.com/watch?v=h3syq1vbplE)
- [App Mesh CDK API Reference](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_appmesh-readme.html)
