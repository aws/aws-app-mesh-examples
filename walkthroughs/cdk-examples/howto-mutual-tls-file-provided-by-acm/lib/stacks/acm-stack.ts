import * as secrets_mgr from "aws-cdk-lib/aws-secretsmanager";
import * as acm_pca from "aws-cdk-lib/aws-acmpca";
import * as cert_mgr from "aws-cdk-lib/aws-certificatemanager";
import * as iam from "aws-cdk-lib/aws-iam";
import * as lambda from "aws-cdk-lib/aws-lambda";
import { StackProps, Stack, SecretValue, RemovalPolicy } from "aws-cdk-lib";
import { Construct } from "constructs";
import * as fs from "fs";
import * as path from "path";
import * as shell from "child_process";
import { InfraStack } from "./infra";

export class AcmStack extends Stack {
  readonly infra: InfraStack;
  readonly colorTellerRootCa: acm_pca.CfnCertificateAuthority;
  readonly colorTellerRootCert: acm_pca.CfnCertificate;
  readonly colorTellerRootCaActvn: acm_pca.CfnCertificateAuthorityActivation;

  readonly colorTellerEndpointCert: cert_mgr.CfnCertificate;
  readonly colorGatewayEndpointCert: cert_mgr.CfnCertificate;

  readonly colorGatewayCa: acm_pca.CfnCertificateAuthority;
  readonly colorGatewayCert: acm_pca.CfnCertificate;
  readonly colorGatewayCaActvn: acm_pca.CfnCertificateAuthorityActivation;

  readonly certificateSecret: secrets_mgr.Secret;

  readonly lambdaInitCertRole: iam.Role;
  readonly lambdaInitCertFunc: lambda.Function;

  readonly signingAlgorithm = "SHA256WITHRSA";
  readonly keyAlgorithm = "RSA_2048";

  constructor(infra: InfraStack, id: string, props?: StackProps) {
    super(infra, id, props);

    this.infra = infra;

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

    // Endpoint certs
    this.colorTellerEndpointCert = this.buildEnpointCertificate(
      "CtEndpt",
      this.colorTellerRootCa.attrArn,
      "colorteller"
    );
    this.colorGatewayEndpointCert = this.buildEnpointCertificate(
      "GwEndpt",
      this.colorGatewayCa.attrArn,
      "colorgateway"
    );

    // Activations
    this.colorTellerRootCaActvn = this.buildCaActivation(
      "RootActvn",
      this.colorTellerRootCa.attrArn,
      this.colorTellerRootCert.attrCertificate
    );
    this.colorGatewayCaActvn = this.buildCaActivation(
      "GwActvn",
      this.colorGatewayCa.attrArn,
      this.colorGatewayCert.attrCertificate
    );

    this.certificateSecret = new secrets_mgr.Secret(this, `${this.stackName}Secret`, {
      secretName: "cert-secret",
      generateSecretString: {
        secretStringTemplate: JSON.stringify({
          GatewayCertificate: "tempcert",
          GatewayCertificateChain: "tempcertchain",
          GatewayPrivateKey: "privatekey",
          Passphrase: "passphrase",
        }),
      },
    });

    this.lambdaInitCertRole = new iam.Role(this, `${this.stackName}LambdaCertRole`, {
      assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName("service-role/AWSLambdaBasicExecutionRole"),
        iam.ManagedPolicy.fromAwsManagedPolicyName("SecretsManagerReadWrite"),
      ],
    });

    this.lambdaInitCertFunc = new lambda.Function(this, `${this.stackName}InitCertFunc`, {
      runtime: lambda.Runtime.PYTHON_3_9,
      handler: "initcert.lambda_handler",
      code: lambda.Code.fromAsset(path.join(__dirname, "../lambda")),
      role: this.lambdaInitCertRole,
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

  private buildRootCertificate = (
    cfnLogicalName: string,
    caArn: string,
    signingRequest: string
  ): acm_pca.CfnCertificate => {
    return new acm_pca.CfnCertificate(this, `${this.stackName}${cfnLogicalName}`, {
      certificateAuthorityArn: caArn,
      certificateSigningRequest: signingRequest,
      signingAlgorithm: this.signingAlgorithm,
      templateArn: "",
      validity: {
        type: "YEARS",
        value: 10,
      },
    });
  };

  private buildEnpointCertificate = (
    cfnLogicalName: string,
    caArn: string,
    domainPrefix: string
  ): cert_mgr.CfnCertificate => {
    return new cert_mgr.CfnCertificate(this, `${this.stackName}${cfnLogicalName}`, {
      certificateAuthorityArn: caArn,
      domainName: `${domainPrefix}.${this.node.tryGetContext("SERVICES_DOMAIN")}`,
    });
  };

  private buildCaActivation = (
    cfnLogicalName: string,
    caArn: string,
    certificate: string
  ): acm_pca.CfnCertificateAuthorityActivation => {
    return new acm_pca.CfnCertificateAuthorityActivation(this, `${this.stackName}${cfnLogicalName}`, {
      certificateAuthorityArn: caArn,
      certificate: certificate,
      status: "ACTIVE",
    });
  };
}
