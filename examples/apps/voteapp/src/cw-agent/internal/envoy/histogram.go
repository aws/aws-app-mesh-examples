package envoy

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
)

const (
	classicMetricsEndpoint = "/stats"
)

var jsonFormatQueryParams = url.Values{
	"format": []string{"json"},
}

// The following types map to the object structure returned by
// envoy's `/stats?format=json` HTTP GET endpoint.
type metrics struct {
	Stats []metricStat
}

type metricStat struct {
	Name       string
	Value      float64
	Histograms *metricHistograms
}

type metricHistograms struct {
	SupportedQuantiles []float64           `json:"supported_quantiles"`
	ComputedQuantiles  []computedQuantiles `json:"computed_quantiles"`
}

type computedQuantiles struct {
	Name   string
	Values []quantileValues
}

type quantileValues struct {
	Interval, Cumulative float64
}

func (coll *Collector) collectHistograms(upstreamClusters []string) (HistogramsByUpstream, error) {
	h := make(HistogramsByUpstream)

	u := url.URL{
		Scheme:   "http",
		Host:     coll.AdminHost,
		Path:     classicMetricsEndpoint,
		RawQuery: jsonFormatQueryParams.Encode(),
	}

	resp, err := http.Get(u.String())
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	sanitizedOutput := newVerticalBarReplacer(resp.Body)

	buf := new(bytes.Buffer)
	if _, err := buf.ReadFrom(sanitizedOutput); err != nil {
		return nil, err
	}

	var m metrics

	if err := json.Unmarshal(buf.Bytes(), &m); err != nil {
		return nil, err
	}
	for _, stat := range m.Stats {
		if stat.Histograms != nil {
			for _, cluster := range upstreamClusters {
				for _, quantiles := range stat.Histograms.ComputedQuantiles {
					if quantiles.Name == "cluster."+string(cluster)+".upstream_rq_time" {
						for i, valPair := range quantiles.Values {
							qName := fmt.Sprintf("%g", stat.Histograms.SupportedQuantiles[i])
							if _, ok := h[cluster]; !ok {
								h[cluster] = make(Histogram)
							}
							h[cluster][qName] = valPair.Interval
						}
					}
				}
			}
		}
	}

	return h, nil
}
