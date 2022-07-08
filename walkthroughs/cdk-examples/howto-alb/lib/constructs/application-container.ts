import * as ecs from "aws-cdk-lib/aws-ecs";
import { Construct } from "constructs";
import { MeshStack } from "../stacks/mesh-components";
import { ApplicationContainerProps } from "../utils";

export class ApplicationContainer extends Construct {
  public options: ecs.ContainerDefinitionOptions;
  constructor(ms: MeshStack, id: string, props: ApplicationContainerProps) {
    super(ms, id);
    this.options = {
      image: props.image,
      containerName: "app",
      logging: ecs.LogDriver.awsLogs({
        logGroup: ms.sd.base.logGroup,
        streamPrefix: props.logStreamPrefix,
      }),
      environment: props.env,
      portMappings: props.portMappings,
    };
  }
}
