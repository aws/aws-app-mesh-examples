// Copyright 2017-2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
//
//     http://aws.amazon.com/apache2.0/
//
// or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

package xray

import (
	"bytes"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/aws/aws-xray-sdk-go/header"
	"github.com/aws/aws-xray-sdk-go/pattern"
	log "github.com/cihub/seelog"
)

// SegmentNamer is the interface for naming service node.
type SegmentNamer interface {
	Name(host string) string
}

// FixedSegmentNamer records the fixed name of service node.
type FixedSegmentNamer struct {
	FixedName string
}

// NewFixedSegmentNamer initializes a FixedSegmentNamer which
// will provide a fixed segment name for every generated segment.
// If the AWS_XRAY_TRACING_NAME environment variable is set,
// its value will override the provided name argument.
func NewFixedSegmentNamer(name string) *FixedSegmentNamer {
	if fName := os.Getenv("AWS_XRAY_TRACING_NAME"); fName != "" {
		name = fName
	}
	return &FixedSegmentNamer{
		FixedName: name,
	}
}

// Name returns the segment name for the given host header value.
// In this case, FixedName is always returned.
func (fSN *FixedSegmentNamer) Name(host string) string {
	return fSN.FixedName
}

// DynamicSegmentNamer chooses names for segments generated
// for incoming requests by parsing the HOST header of the
// incoming request. If the host header matches a given
// recognized pattern (using the included pattern package),
// it is used as the segment name. Otherwise, the fallback
// name is used.
type DynamicSegmentNamer struct {
	FallbackName    string
	RecognizedHosts string
}

// NewDynamicSegmentNamer creates a new dynamic segment namer.
func NewDynamicSegmentNamer(fallback string, recognized string) *DynamicSegmentNamer {
	if dName := os.Getenv("AWS_XRAY_TRACING_NAME"); dName != "" {
		fallback = dName
	}
	return &DynamicSegmentNamer{
		FallbackName:    fallback,
		RecognizedHosts: recognized,
	}
}

// Name returns the segment name for the given host header value.
func (dSN *DynamicSegmentNamer) Name(host string) string {
	if pattern.WildcardMatchCaseInsensitive(dSN.RecognizedHosts, host) {
		return host
	}
	return dSN.FallbackName
}

// Handler wraps the provided http handler with xray.Capture
// using the request's context, parsing the incoming headers,
// adding response headers if needed, and sets HTTP sepecific trace fields.
// Handler names the generated segments using the provided SegmentNamer.
func Handler(sn SegmentNamer, h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		name := sn.Name(r.Host)

		traceHeader := header.FromString(r.Header.Get("x-amzn-trace-id"))

		ctx, seg := NewSegmentFromHeader(r.Context(), name, traceHeader)

		r = r.WithContext(ctx)

		seg.Lock()

		seg.GetHTTP().GetRequest().Method = r.Method
		seg.GetHTTP().GetRequest().URL = r.URL.String()
		seg.GetHTTP().GetRequest().ClientIP, seg.GetHTTP().GetRequest().XForwardedFor = clientIP(r)
		seg.GetHTTP().GetRequest().UserAgent = r.UserAgent()

		trace := parseHeaders(r.Header)
		if trace["Root"] != "" {
			seg.TraceID = trace["Root"]
			seg.RequestWasTraced = true
		}
		if trace["Parent"] != "" {
			seg.ParentID = trace["Parent"]
		}
		// Don't use the segment's header here as we only want to
		// send back the root and possibly sampled values.
		var respHeader bytes.Buffer
		respHeader.WriteString("Root=")
		respHeader.WriteString(seg.TraceID)
		switch trace["Sampled"] {
		case "0":
			seg.Sampled = false
			log.Trace("Incoming header decided: Sampled=false")
		case "1":
			seg.Sampled = true
			log.Trace("Incoming header decided: Sampled=true")
		default:
			seg.Sampled = privateCfg.SamplingStrategy().ShouldTrace(r.Host, r.URL.String(), r.Method)
			log.Tracef("SamplingStrategy decided: %t", seg.Sampled)
		}
		if trace["Sampled"] == "?" {
			respHeader.WriteString(";Sampled=")
			respHeader.WriteString(strconv.Itoa(btoi(seg.Sampled)))
		}
		w.Header().Set("x-amzn-trace-id", respHeader.String())
		seg.Unlock()

		resp := &responseCapturer{w, 200, 0}
		h.ServeHTTP(resp, r)

		seg.Lock()
		seg.GetHTTP().GetResponse().Status = resp.status
		seg.GetHTTP().GetResponse().ContentLength, _ = strconv.Atoi(resp.Header().Get("Content-Length"))

		if resp.status >= 400 && resp.status < 500 {
			seg.Error = true
		}
		if resp.status == 429 {
			seg.Throttle = true
		}
		if resp.status >= 500 && resp.status < 600 {
			seg.Fault = true
		}
		seg.Unlock()
		seg.Close(nil)
	})
}

func clientIP(r *http.Request) (string, bool) {
	forwardedFor := r.Header.Get("X-Forwarded-For")
	if forwardedFor != "" {
		return strings.TrimSpace(strings.Split(forwardedFor, ",")[0]), true
	}

	return r.RemoteAddr, false
}

type responseCapturer struct {
	http.ResponseWriter
	status int
	length int
}

func (w *responseCapturer) WriteHeader(status int) {
	w.status = status
	w.ResponseWriter.WriteHeader(status)
}

func (w *responseCapturer) Write(data []byte) (int, error) {
	w.length += len(data)
	return w.ResponseWriter.Write(data)
}

func btoi(b bool) int {
	if b {
		return 1
	}
	return 0
}

func parseHeaders(h http.Header) map[string]string {
	m := map[string]string{}
	s := h.Get("x-amzn-trace-id")
	for _, c := range strings.Split(s, ";") {
		p := strings.SplitN(c, "=", 2)
		k := strings.TrimSpace(p[0])
		v := ""
		if len(p) > 1 {
			v = strings.TrimSpace(p[1])
		}
		m[k] = v
	}
	return m
}
