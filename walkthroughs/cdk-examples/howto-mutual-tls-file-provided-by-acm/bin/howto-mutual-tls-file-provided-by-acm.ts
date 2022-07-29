#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { InfraStack } from "../lib/stacks/infra";
import { AcmStack } from "../lib/stacks/acm-stack";

const app = new cdk.App();
const infra = new InfraStack(app, "infra", { stackName: "infra" });
const acm = new AcmStack(infra, "acm", { stackName: "acm" });
