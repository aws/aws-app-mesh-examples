import * as secrets_mgr from "aws-cdk-lib/aws-secretsmanager";
import * as acm_pca from "aws-cdk-lib/aws-acmpca";
import * as cert_mgr from "aws-cdk-lib/aws-certificatemanager";
import * as iam from "aws-cdk-lib/aws-iam";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as assets from "aws-cdk-lib/aws-ecr-assets";
import * as logs from "aws-cdk-lib/aws-logs";

import { Construct } from "constructs";
import { StackProps, Stack, RemovalPolicy, Duration, triggers } from "aws-cdk-lib";
import { getCertLambdaPolicies } from "../utils";

import * as path from "path";

export class AcmStack extends Stack {
  readonly colorTellerRootCa: acm_pca.CfnCertificateAuthority;
  readonly colorTellerRootCert: acm_pca.CfnCertificate;
  readonly colorTellerRootCaActvn: acm_pca.CfnCertificateAuthorityActivation;

  readonly colorTellerEndpointCert: cert_mgr.PrivateCertificate;
  readonly colorGatewayEndpointCert: cert_mgr.PrivateCertificate;

  readonly colorGatewayCa: acm_pca.CfnCertificateAuthority;
  readonly colorGatewayCert: acm_pca.CfnCertificate;
  readonly colorGatewayCaActvn: acm_pca.CfnCertificateAuthorityActivation;

  readonly certificateSecret: secrets_mgr.Secret;

  readonly initCertRole: iam.Role;
  readonly initCertFunc: lambda.DockerImageFunction;
  readonly initCertTrigger: triggers.Trigger;

  readonly initCertTriggerFunc: triggers.TriggerFunction;

  readonly signingAlgorithm: string = "SHA256WITHRSA";
  readonly keyAlgorithm: string = "RSA_2048";
  readonly namespace: string = this.node.tryGetContext("SERVICES_DOMAIN");

  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // CAs
    this.colorTellerRootCa = this.buildCertificateAuthority("CtRootCA", "AcmPcaColorTeller");
    this.colorGatewayCa = this.buildCertificateAuthority("GwCA", "AcmPcaColorGateway");

    // Root certs
    this.colorTellerRootCert = this.buildRootCertificate(
      "CtRootCert",
      this.colorTellerRootCa.attrArn,
      this.colorTellerRootCa.attrCertificateSigningRequest
    );
    this.colorGatewayCert = this.buildRootCertificate(
      "GwCert",
      this.colorGatewayCa.attrArn,
      this.colorGatewayCa.attrCertificateSigningRequest
    );

    // Activations
    this.colorTellerRootCaActvn = this.buildCaActivation(
      "RootActvn",
      this.colorTellerRootCa.attrArn,
      this.colorTellerRootCert.attrCertificate
    );
    this.colorGatewayCaActvn = this.buildCaActivation("GwActvn", this.colorGatewayCa.attrArn, this.colorGatewayCert.attrCertificate);

    // Endpoint certs
    this.colorTellerEndpointCert = this.buildEnpointCertificate("CtEndpt", this.colorTellerRootCa.attrArn, "colorteller");
    this.colorGatewayEndpointCert = this.buildEnpointCertificate("GwEndpt", this.colorGatewayCa.attrArn, "colorgateway");

    this.colorGatewayEndpointCert.node.addDependency(this.colorGatewayCaActvn);
    this.colorTellerEndpointCert.node.addDependency(this.colorTellerRootCaActvn);

    this.certificateSecret = new secrets_mgr.Secret(this, `${this.stackName}Secret`, {
      secretName: "cert-secret",
      generateSecretString: {
        secretStringTemplate: JSON.stringify({
          GatewayCertificate: "tempcert",
          GatewayCertificateChain: "tempcertchain",
          GatewayPrivateKey: "privatekey",
          Passphrase: "passphrase",
        }),
        generateStringKey: "Passphrase",
      },
      removalPolicy: RemovalPolicy.DESTROY,
    });

    this.initCertRole = new iam.Role(this, `${this.stackName}LambdaCertRole`, {
      assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
      managedPolicies: getCertLambdaPolicies(this, "initCertPols"),
    });

    this.initCertFunc = new lambda.DockerImageFunction(this, `${this.stackName}InitCertFunc`, {
      functionName: "init-cert",
      logRetention: logs.RetentionDays.ONE_DAY,
      timeout: Duration.seconds(900),
      code: lambda.DockerImageCode.fromImageAsset(path.join(__dirname, "../../lambda_initcert"), {
        platform: assets.Platform.LINUX_AMD64,
      }),
      role: this.initCertRole,
      environment: {
        COLOR_GATEWAY_ACM_ARN: this.colorGatewayEndpointCert.certificateArn,
        COLOR_TELLER_ACM_ARN: this.colorTellerEndpointCert.certificateArn,
        COLOR_TELLER_ACM_PCA_ARN: this.colorTellerRootCa.attrArn,
        COLOR_GATEWAY_ACM_PCA_ARN: this.colorGatewayCa.attrArn,
        AWS_ACCOUNT: process.env.CDK_DEFAULT_ACCOUNT!,
        SECRET: this.certificateSecret.secretArn,
      },
    });

    this.initCertTrigger = new triggers.Trigger(this, `${this.stackName}InitCertTrigger`, {
      handler: this.initCertFunc,
      executeAfter: [this.colorTellerEndpointCert, this.colorGatewayEndpointCert, this.certificateSecret],
      executeOnHandlerChange: false,
    });
  }

  private buildCertificateAuthority = (cfnLogicalName: string, commonName: string): acm_pca.CfnCertificateAuthority => {
    return new acm_pca.CfnCertificateAuthority(this, `${this.stackName}${cfnLogicalName}`, {
      type: "ROOT",
      keyAlgorithm: this.keyAlgorithm,
      signingAlgorithm: this.signingAlgorithm,
      subject: { commonName: commonName },
    });
  };

  private buildRootCertificate = (cfnLogicalName: string, caArn: string, signingRequest: string): acm_pca.CfnCertificate => {
    return new acm_pca.CfnCertificate(this, `${this.stackName}${cfnLogicalName}`, {
      certificateAuthorityArn: caArn,
      certificateSigningRequest: signingRequest,
      signingAlgorithm: this.signingAlgorithm,
      templateArn: `arn:${this.partition}:acm-pca:::template/RootCACertificate/V1`,
      validity: {
        type: "YEARS",
        value: 10,
      },
    });
  };

  private buildEnpointCertificate = (cfnLogicalName: string, caArn: string, domainPrefix: string): cert_mgr.PrivateCertificate => {
    return new cert_mgr.PrivateCertificate(this, `${this.stackName}${cfnLogicalName}`, {
      domainName: `${domainPrefix}.${this.namespace}`,
      certificateAuthority: acm_pca.CertificateAuthority.fromCertificateAuthorityArn(this, `${this.stackName}${cfnLogicalName}CA`, caArn),
    });
  };

  private buildCaActivation = (cfnLogicalName: string, caArn: string, certificate: string): acm_pca.CfnCertificateAuthorityActivation => {
    return new acm_pca.CfnCertificateAuthorityActivation(this, `${this.stackName}${cfnLogicalName}`, {
      certificateAuthorityArn: caArn,
      certificate: certificate,
      status: "ACTIVE",
    });
  };
}
