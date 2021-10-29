/**
 * A cloudformation custom resource that creates dashboards
 * for App Mesh virtual nodes or virtual gateways.
 *
 * Properties:
 * * MetricNamespace: (required String) A CloudWatch metric namespace.
 * * MeshName: (required String) The App Mesh mesh name.
 * * Name: (required String) The CloudWatch dashboard name.
 * * Period: (required Number) The period of all metrics in the dashboard in seconds.
 * * Start: (required String) The start time of the dashboard in CloudWatch's format. e.g. '-PT1H'
 * * MetricNameSanitizer: (optional String) A regular expression used to match invalid characters in
 *                        metric names and replace them with underscores ('_').
 * * VirtualNodes: (optional CommaDelimitedList) A comma-delimited list of virtual node names.
 * * VirtualGateway: (optional String) The name of a virtual gateway.
 *
 * One of VirtualNodes or VirtualGateway are required.
 */

const cfnResponse = require('cfn-response-promise');
const {
  AppMesh, Backend, VirtualServiceProvider, paginateListGatewayRoutes
} = require('@aws-sdk/client-app-mesh');
const { CloudWatch } = require('@aws-sdk/client-cloudwatch');

/**
 * Returns an array of listener protocol names for a given virtual service
 * ex:
 * [
 *   'http',
 *   'tcp',
 * ]
 */
const getServiceProtocols = async (appmesh, meshName, virtualServiceName) => {
  console.log(`Getting virtual service protocols for mesh/${meshName}/virtualService/${virtualServiceName}`);
  const result = await appmesh.describeVirtualService({
    meshName,
    virtualServiceName,
  });
  return VirtualServiceProvider.visit(result.virtualService.spec.provider, {
    virtualNode: async provider => {
      const result = await appmesh.describeVirtualNode({
        meshName,
        virtualNodeName: provider.virtualNodeName,
      });
      return (result.virtualNode.spec.listeners ?? [])
        .map(it => it.portMapping.protocol);
    },
    virtualRouter: async provider => {
      const result = await appmesh.describeVirtualRouter({
        meshName,
        virtualRouterName: provider.virtualRouterName,
      });
      return (result.virtualRouter.spec.listeners ?? [])
        .map(it => it.portMapping.protocol);
    },
    _: async provider => [],
  });
};

/**
 * For a given virtual node, returns an object with 2 keys:
 * * listeners: an array of listener protocol names
 * * backend: a mapping of backend name to an array or listener protocol names
 * ex:
 * 
 * {
 *   listeners: ['http'],
 *   backends: { 'foo.bar.local': ['grpc'] },
 * }
 */
const getVNodeInfo = async (appmesh, meshName, virtualNodeName) => {
  console.log(`Getting virtual node info for mesh/${meshName}/virtualNode/${virtualNodeName}`);
  const result = await appmesh.describeVirtualNode({
    meshName,
    virtualNodeName,
  });
  const backends = await Promise.all((result.virtualNode.spec.backends ?? [])
    .map(backend => Backend.visit(backend, {
      virtualService: async vservice => {
        const { virtualServiceName } = vservice;
        const protos = await getServiceProtocols(appmesh, meshName, virtualServiceName);
        return { [virtualServiceName]: protos };
      },
      _: async it => ({})
    })));
  const listeners = (result.virtualNode.spec.listeners ?? [])
    .map(it => it.portMapping.protocol);
  return {
    listeners,
    backends: Object.assign({}, ...backends),
  }
};

/**
 * Find the target virtual service name for a gateway route
 */
const getGatewayRouteTarget = async (appmesh, meshName, virtualGatewayName, gatewayRouteName) => {
  const result = await appmesh.describeGatewayRoute({
    meshName,
    virtualGatewayName,
    gatewayRouteName,
  });
  const spec = result.gatewayRoute.spec;
  if (spec.httpRoute !== undefined) {
    return spec.httpRoute.action.target.virtualService.virtualServiceName;
  } else if (spec.http2Route !== undefined) {
    return spec.http2Route.action.target.virtualService.virtualServiceName;
  } else if (spec.grpcRoute !== undefined) {
    return spec.grpcRoute.action.target.virtualService.virtualServiceName;
  }
};

/**
 * For a given virtual gateway, returns an object with 2 keys:
 * * listeners: an array of listener protocol names
 * * backend: a mapping of target virtual service names to an array or listener protocol names
 * ex:
 * 
 * {
 *   listeners: ['http'],
 *   backends: { 'foo.bar.local': ['grpc'] },
 * }
 */
const getVGatewayInfo = async (appmesh, meshName, virtualGatewayName) => {
  console.log(`Getting virtual gateway info for mesh/${meshName}/virtualGateway/${virtualGatewayName}`);
  const backends = {};
  const config = { client: appmesh };
  const params = {
    meshName,
    virtualGatewayName,
  };
  const result = await appmesh.describeVirtualGateway(params);
  const listeners = result.virtualGateway.spec.listeners
    .map(it => it.portMapping.protocol);
  for await (const page of paginateListGatewayRoutes(config, params)) {
    for (const route of page.gatewayRoutes) {
      const { gatewayRouteName } = route;
      const virtualServiceName = await getGatewayRouteTarget(appmesh, meshName, virtualGatewayName, gatewayRouteName);
      const protos = await getServiceProtocols(appmesh, meshName, virtualServiceName);
      backends[virtualServiceName] = protos;
    }
  }
  return {
    listeners,
    backends,
  };
};

/**
 * Use the property MetricNameSanitizer as a regex of characters to replace on a string
 */
const sanitizeMetric = (props, name) => {
  if ((props.MetricNameSanitizer ?? '') === '') {
    return name;
  }
  return name.replace(props.MetricNameSanitizer, '_');
};

const makeHeadingWidget = (text, level) => ({
  type: 'text',
  width: 24,
  height: 1,
  properties: {
    markdown: `${'#'.repeat(level)} ${text}`,
  },
});

const makeMetricWidget = (props, title, width, metrics, stat, filters) => ({
  type: 'metric',
  height: 4,
  width,
  properties: {
    title,
    period: parseInt(props.Period, 10),
    stat,
    region: props.Region,
    metrics: metrics.map(metric =>
      [{ expression: `SEARCH('Namespace="${props.MetricNamespace}" Mesh="${props.MeshName}" MetricName="${sanitizeMetric(props, metric)}" ${filters ?? ""}', '${stat}', ${props.Period})` }],
    ),
  },
});

const getInboundWidgets = (props, listeners, resourceType, resourceName) => {
  const widgets = [];
  const listener = listeners.shift();
  console.log(`${resourceName} has a ${listener} listener`);
  if (listener !== undefined) {
    widgets.push(makeHeadingWidget('Inbound Metrics', 2));
    widgets.push(makeMetricWidget(props,
      'ActiveConnectionCount', 8, ['envoy.appmesh.ActiveConnectionCount'], 'Sum', `${resourceType}="${resourceName}"`));
    widgets.push(makeMetricWidget(props,
      'NewConnectionCount', 8, ['envoy.appmesh.NewConnectionCount'], 'Sum', `${resourceType}="${resourceName}"`));
    widgets.push(makeMetricWidget(props,
      'ProcessedBytes', 8, ['envoy.appmesh.ProcessedBytes'], 'Sum', `${resourceType}="${resourceName}"`));

    if (listener === 'http' || listener === 'http2') {
      widgets.push(makeMetricWidget(props,
        'RequestCount', 24, ['envoy.appmesh.RequestCount'], 'Sum', `${resourceType}="${resourceName}"`));
    }
    if (listener === 'grpc') {
      widgets.push(makeMetricWidget(props,
        'GrpcRequestCount', 24, ['envoy.appmesh.GrpcRequestCount'], 'Sum', `${resourceType}="${resourceName}"`));
    }
  }
  return widgets;
};

const getOutboundWidgets = (props, backends, resourceType, resourceName) => {
  const widgets = [];
  const entries = Object.entries(backends);
  console.log(`Found ${entries.length} backends`);
  if (entries.length > 0) {
      widgets.push(makeHeadingWidget('Outbound Metrics', 2));
  }
  for (const [targetVirtualService, protocols] of entries) {
    protocol = protocols.shift();
    console.log(`${targetVirtualService} has a ${protocol} listener`);
    if (protocol === undefined) {
      continue;
    }
    console.log(`Adding section for backend ${targetVirtualService}`);
    widgets.push(makeHeadingWidget('Backend: ' + targetVirtualService, 3));
    widgets.push(makeMetricWidget(props,
      'ProcessedBytes', 24, ['envoy.appmesh.TargetProcessedBytes'], 'Sum',
      `${resourceType}="${resourceName}" TargetVirtualService="${targetVirtualService}"`));

    if (protocol !== 'tcp') {
      widgets.push(makeMetricWidget(props,
        'RequestCount', 8, ['envoy.appmesh.RequestCountPerTarget'], 'Sum',
        `${resourceType}="${resourceName}" TargetVirtualService="${targetVirtualService}"`));
      widgets.push(makeMetricWidget(props,
        'ResponseTime - p50', 8, ['envoy.appmesh.TargetResponseTime'], 'p50',
        `${resourceType}="${resourceName}" TargetVirtualService="${targetVirtualService}"`));
      widgets.push(makeMetricWidget(props,
        'ResponseTime - p99', 8, ['envoy.appmesh.TargetResponseTime'], 'p99',
        `${resourceType}="${resourceName}" TargetVirtualService="${targetVirtualService}"`));

      if (protocol === 'http' || protocol === 'http2') {
        widgets.push(makeMetricWidget(props,
          '2xx Responses', 8, ['envoy.appmesh.HTTPCode_Target_2XX_Count'], 'Sum',
          `${resourceType}="${resourceName}" TargetVirtualService="${targetVirtualService}"`));
        widgets.push(makeMetricWidget(props,
          '4xx Responses', 8, ['envoy.appmesh.HTTPCode_Target_4XX_Count'], 'Sum',
          `${resourceType}="${resourceName}" TargetVirtualService="${targetVirtualService}"`));
        widgets.push(makeMetricWidget(props,
          '5xx Responses', 8, ['envoy.appmesh.HTTPCode_Target_5XX_Count'], 'Sum',
          `${resourceType}="${resourceName}" TargetVirtualService="${targetVirtualService}"`));
      }
    }
  }
  return widgets;
};

const upsertVNodesDashboard = async (props, appmesh, cloudwatch) => {
  console.log(`Creating virtual node dashboard for ${props.VirtualNodes}`);
  const body = {
    start: props.Start,
    widgets: [],
  };

  for (const virtualNodeName of props.VirtualNodes.split(',')) {
    console.log(`Creating section for ${virtualNodeName}`);

    body.widgets.push(makeHeadingWidget(virtualNodeName, 1));
    const info = await getVNodeInfo(appmesh, props.MeshName, virtualNodeName);
    body.widgets.push(...getInboundWidgets(props, info.listeners, 'VirtualNode', virtualNodeName));
    body.widgets.push(...getOutboundWidgets(props, info.backends, 'VirtualNode', virtualNodeName));
  }

  const jsonBody = JSON.stringify(body);
  console.log(`Creating dashboard: ${jsonBody}`);
  await cloudwatch.putDashboard({
    DashboardName: props.Name,
    DashboardBody: jsonBody,
  });
  const result = await cloudwatch.getDashboard({ DashboardName: props.Name });
  return result.DashboardArn;
};

const upsertVGatewayDashboard = async (props, appmesh, cloudwatch) => {
  console.log(`Creating virtual gateway dashboard for ${props.VirtualGateway}`);
  const body = {
    start: props.Start,
    widgets: [],
  };

  body.widgets.push(makeHeadingWidget(props.VirtualGateway, 1));
  const info = await getVGatewayInfo(appmesh, props.MeshName, props.VirtualGateway);
  body.widgets.push(...getInboundWidgets(props, info.listeners, 'VirtualGateway', props.VirtualGateway));
  body.widgets.push(...getOutboundWidgets(props, info.listeners, 'VirtualGateway', props.VirtualGateway));

  const jsonBody = JSON.stringify(body);
  console.log(`Creating dashboard: ${jsonBody}`);
  await cloudwatch.putDashboard({
    DashboardName: props.Name,
    DashboardBody: jsonBody,
  });
  const result = await cloudwatch.getDashboard({ DashboardName: props.Name });
  return result.DashboardArn;
};

const upsertHandler = async (event, ctx, appmesh, cloudwatch) => {
  const { ResourceProperties, OldResourceProperties } = event;
  if (OldResourceProperties !== undefined) {
    if (ResourceProperties.Name !== OldResourceProperties.Name) {
      await cloudwatch.deleteDashboards({ DashboardNames: [OldResourceProperties.Name] });
    }
  }
  if (ResourceProperties.VirtualNodes.length > 0) {
    await upsertVNodesDashboard(ResourceProperties, appmesh, cloudwatch);
  } else if (ResourceProperties.VirtualGateway.length > 0) {
    await upsertVGatewayDashboard(ResourceProperties, appmesh, cloudwatch);
  } else {
    throw new Error('VirtualNodes or VirtualGateway are required');
  }
};

const deleteHandler = async (event, ctx, appmesh, cloudwatch) => {
  await cloudwatch.deleteDashboards({ DashboardNames: [event.ResourceProperties.Name] });
};

module.exports.handler = async (event, ctx) => {
  const appmesh = new AppMesh();
  const cloudwatch = new CloudWatch();
  const handlers = {
    Create: upsertHandler,
    Update: upsertHandler,
    Delete: deleteHandler,
  };
  try {
    const arn = await handlers[event.RequestType](event, ctx, appmesh, cloudwatch);
    await cfnResponse.send(event, ctx, cfnResponse.SUCCESS, { Arn: arn }, arn);
  } catch (err) {
    console.error(err);
    await cfnResponse.send(event, ctx, cfnResponse.FAILED, {});
  }
};
