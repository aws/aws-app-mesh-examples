package envoy

import "fmt"

type Collector struct {
	AdminHost string
}

// Value by quantile (P75, P90, etc.)
type Histogram map[string]float64

type Counters struct {
	// Counters
	UpstreamReq,
	UpstreamResp2xx,
	UpstreamResp4xx,
	UpstreamResp5xx float64
}

func (c *Counters) String() string {
	return fmt.Sprintf(
		"UpstreamReq: %g, UpstreamResp2xx: %g, UpstreamResp4xx: %g, UpstreamResp5xx: %g\n",
		c.UpstreamReq, c.UpstreamResp2xx, c.UpstreamResp4xx, c.UpstreamResp5xx)
}

type UpstreamCluster string

type CountersByUpstream map[string]*Counters
type HistogramsByUpstream map[string]Histogram
