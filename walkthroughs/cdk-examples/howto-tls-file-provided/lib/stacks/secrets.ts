import * as secrets_mgr from "aws-cdk-lib/aws-secretsmanager";
import { StackProps, Stack, SecretValue, RemovalPolicy } from "aws-cdk-lib";
import { Construct } from "constructs";
import * as fs from "fs";
import * as path from "path";
import * as shell from "child_process";

export class SecretsStack extends Stack {
  readonly CERT_DIR: string = "../../src/tlsCertificates";

  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    if (this.node.tryGetContext("make-certs") === "true") {
      this.generateNewCertificates();
      Object.entries(this.fetchCertificateContents()).forEach(([certName, certContent]) => {
        new secrets_mgr.Secret(this, `${this.stackName}${certName}`, {
          secretName: certName,
          description: "OpenSSL certificate",
          secretStringValue: SecretValue.unsafePlainText(certContent),
          removalPolicy: RemovalPolicy.DESTROY,
        });
      });
    }
  }

  private generateNewCertificates = (): void => {
    const files = fs.readdirSync(path.join(__dirname, this.CERT_DIR));
    files
      .filter((file) => file.endsWith(".pem") || file.endsWith(".generated"))
      .forEach((file) => {
        fs.unlinkSync(path.join(__dirname, this.CERT_DIR, file));
      });

    process.env.SERVICES_DOMAIN = this.node.tryGetContext("SERVICES_DOMAIN");
    shell.execFileSync(path.join(__dirname, this.CERT_DIR, "certs.sh"));
  };

  private fetchCertificateContents = (): { [key: string]: string } => {
    const certContents: { [key: string]: string } = {};
    const files = fs.readdirSync(path.join(__dirname, this.CERT_DIR));

    files
      .filter((file) => file.endsWith(".pem") && !["ca_1_key.pem", "ca_2_key.pem"].includes(file))
      .forEach((file) => {
        const content = fs.readFileSync(path.join(__dirname, this.CERT_DIR, file));
        certContents[file.replace(".pem", "")] = content.toString();
      });
    return certContents;
  };
}
