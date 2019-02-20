package envoy

import "io"

func (coll *Collector) Collect() (CountersByUpstream, HistogramsByUpstream, error) {
	var (
		err        error
		counters   CountersByUpstream
		histograms HistogramsByUpstream
	)

	counters, err = coll.collectCounters()
	if err != nil {
		return counters, histograms, err
	}

	var upstreamClusters []string
	for cluster := range counters {
		upstreamClusters = append(upstreamClusters, cluster)
	}

	histograms, err = coll.collectHistograms(upstreamClusters)
	if err != nil {
		return counters, histograms, err
	}

	return counters, histograms, nil
}

// This is a io.Reader wrapper that replaces all '|' characters in
// its output with '_' characters.  It's needed to prevent the
// upstream Prometheus text format parser from crashing on invalid input.
type verticalBarReplacer struct {
	raw io.Reader
}

func newVerticalBarReplacer(r io.Reader) *verticalBarReplacer {
	return &verticalBarReplacer{raw: r}
}

func (s *verticalBarReplacer) Read(p []byte) (n int, err error) {
	n, err = s.raw.Read(p)
	for i := range p {
		if p[i] == '|' {
			p[i] = '_'
		}
	}
	return
}
