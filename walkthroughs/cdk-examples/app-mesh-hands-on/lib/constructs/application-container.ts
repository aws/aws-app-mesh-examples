import * as ecs from "aws-cdk-lib/aws-ecs";
import { Construct } from "constructs";
import { MeshStack } from "../stacks/mesh-components";
import { ApplicationContainerProps } from "../utils";

export class ApplicationContainer extends Construct {
  public options: ecs.ContainerDefinitionOptions;
  constructor(mesh: MeshStack, id: string, props: ApplicationContainerProps) {
    super(mesh, id);
    this.options = {
      image: props.image,
      containerName: "app",
      logging: ecs.LogDriver.awsLogs({
        logGroup: mesh.serviceDiscovery.base.logGroup,
        streamPrefix: props.logStreamPrefix,
      }),
      environment: props.env,
      portMappings: props.portMappings,
    };
  }
}
