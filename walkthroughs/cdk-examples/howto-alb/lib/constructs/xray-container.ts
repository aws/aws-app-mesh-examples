import * as ecs from "aws-cdk-lib/aws-ecs";
import { Construct } from "constructs";
import { MeshStack } from "../stacks/mesh-components";
import { XrayContainerProps } from "../utils";

export class XrayContainer extends Construct {
  public readonly options: ecs.ContainerDefinitionOptions;
  constructor(ms: MeshStack, id: string, props: XrayContainerProps) {
    super(ms, id);

    this.options = {
      image: ecs.ContainerImage.fromRegistry(this.node.tryGetContext("IMAGE_XRAY")),
      containerName: "xray",
      logging: ecs.LogDriver.awsLogs({
        logGroup: ms.sd.base.logGroup,
        streamPrefix: props.logStreamPrefix,
      }),
      user: "1337",
      portMappings: [
        {
          containerPort: 2000,
          protocol: ecs.Protocol.UDP,
        },
      ],
    };
  }
}