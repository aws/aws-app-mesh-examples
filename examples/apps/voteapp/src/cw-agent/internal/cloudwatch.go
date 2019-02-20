package internal

import (
	"github.com/aws/aws-sdk-go/aws/client"
	"github.com/aws/aws-sdk-go/service/cloudwatch"

	"github.com/aws-samples/voting-app/src/cw-agent/internal/envoy"
)

const cloudwatchMetricNamespace = "AWS App Mesh Demo"

type CloudwatchSubmitter struct {
	Session           client.ConfigProvider
	DownstreamService string
}

func (c *CloudwatchSubmitter) Submit(counters envoy.CountersByUpstream, histograms envoy.HistogramsByUpstream) error {
	cwClient := cloudwatch.New(c.Session)

	for upstreamCluster, ctrs := range counters {
		dimensions := []*cloudwatch.Dimension{
			new(cloudwatch.Dimension).
				SetName("DownstreamService").
				SetValue(c.DownstreamService),
			new(cloudwatch.Dimension).
				SetName("UpstreamService").
				SetValue(upstreamCluster),
		}
		data := []*cloudwatch.MetricDatum{
			new(cloudwatch.MetricDatum).
				SetMetricName("UpstreamRequests").
				SetStorageResolution(1).
				SetDimensions(dimensions).
				SetValue(ctrs.UpstreamReq),
			new(cloudwatch.MetricDatum).
				SetMetricName("Upstream2xxResponses").
				SetStorageResolution(1).
				SetDimensions(dimensions).
				SetValue(ctrs.UpstreamResp2xx),
			new(cloudwatch.MetricDatum).
				SetMetricName("Upstream4xxResponses").
				SetStorageResolution(1).
				SetDimensions(dimensions).
				SetValue(ctrs.UpstreamResp4xx),
			new(cloudwatch.MetricDatum).
				SetMetricName("Upstream5xxResponses").
				SetStorageResolution(1).
				SetDimensions(dimensions).
				SetValue(ctrs.UpstreamResp5xx),
		}

		if _, err := cwClient.PutMetricData(
			new(cloudwatch.PutMetricDataInput).
				SetNamespace(cloudwatchMetricNamespace).
				SetMetricData(data),
		); err != nil {
			return err
		}
	}

	for upstreamCluster, hsts := range histograms {
		dimensions := []*cloudwatch.Dimension{
			new(cloudwatch.Dimension).
				SetName("DownstreamService").
				SetValue(c.DownstreamService),
			new(cloudwatch.Dimension).
				SetName("UpstreamService").
				SetValue(upstreamCluster),
		}

		var data []*cloudwatch.MetricDatum

		for quantile, val := range hsts {
			data = append(data,
				new(cloudwatch.MetricDatum).
					SetMetricName("UpstreamResponseTimeP"+quantile).
					SetStorageResolution(1).
					SetDimensions(dimensions).
					SetValue(val),
			)
		}

		if _, err := cwClient.PutMetricData(
			new(cloudwatch.PutMetricDataInput).
				SetNamespace(cloudwatchMetricNamespace).
				SetMetricData(data),
		); err != nil {
			return err
		}
	}
	return nil
}
