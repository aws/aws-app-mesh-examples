package main

import (
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go/aws/session"

	"github.com/aws-samples/voting-app/src/cw-agent/internal"
	"github.com/aws-samples/voting-app/src/cw-agent/internal/envoy"
)

const defaultCollectFrequency = 5 * time.Second

type config struct {
	collectFrequency time.Duration
	collector        envoy.Collector
	submitter        internal.CloudwatchSubmitter
}

func main() {
	var err error

	c := config{}

	downstreamService := os.Getenv("DOWNSTREAM_SERVICE_NAME")
	if downstreamService == "" {
		log.Fatal("DOWNSTREAM_SERVICE_NAME not set")
	}

	envoyAdminHost := os.Getenv("ENVOY_ADMIN_HOST")
	if envoyAdminHost == "" {
		log.Fatal("ENVOY_ADMIN_HOST not set")
	}

	freqStr := os.Getenv("COLLECT_FREQUENCY")
	if freqStr == "" {
		c.collectFrequency = defaultCollectFrequency
	} else {
		c.collectFrequency, err = time.ParseDuration(freqStr)
		if err != nil {
			log.Fatal(err)
		}
	}

	c.collector = envoy.Collector{
		AdminHost: envoyAdminHost,
	}

	c.submitter = internal.CloudwatchSubmitter{
		Session:           session.Must(session.NewSession()),
		DownstreamService: downstreamService,
	}

	c.collect()
}

func (c *config) collect() {
	// First tick is immediate
	tick := time.After(0)

	for {
		<-tick
		tick = time.Tick(c.collectFrequency)

		// Subsequent ticks are on collect frequency
		tick = time.After(c.collectFrequency)

		log.Printf("Collecting histograms and counters from Envoy")

		ctrs, hsts, err := c.collector.Collect()
		if err != nil {
			log.Println(err)
			continue
		}

		log.Printf("Submitting metrics to CloudWatch")

		if err := c.submitter.Submit(ctrs, hsts); err != nil {
			log.Println(err)
			continue
		}
	}
}
