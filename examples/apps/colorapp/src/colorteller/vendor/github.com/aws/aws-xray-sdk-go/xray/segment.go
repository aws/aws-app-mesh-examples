// Copyright 2017-2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
//
//     http://aws.amazon.com/apache2.0/
//
// or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

package xray

import (
	"context"
	"crypto/rand"
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-xray-sdk-go/header"
	"github.com/aws/aws-xray-sdk-go/internal/plugins"
	log "github.com/cihub/seelog"
)

// NewTraceID generates a string format of random trace ID.
func NewTraceID() string {
	var r [12]byte
	_, err := rand.Read(r[:])
	if err != nil {
		panic(err)
	}
	return fmt.Sprintf("1-%08x-%02x", time.Now().Unix(), r)
}

// NewSegmentID generates a string format of segment ID.
func NewSegmentID() string {
	var r [8]byte
	_, err := rand.Read(r[:])
	if err != nil {
		panic(err)
	}
	return fmt.Sprintf("%02x", r)
}

// BeginSegment creates a Segment for a given name and context.
func BeginSegment(ctx context.Context, name string) (context.Context, *Segment) {
	if len(name) > 200 {
		name = name[:200]
	}
	seg := &Segment{parent: nil}
	log.Tracef("Beginning segment named %s", name)
	seg.ParentSegment = seg

	seg.Lock()
	defer seg.Unlock()

	seg.TraceID = NewTraceID()
	seg.Sampled = true
	seg.addPlugin(plugins.InstancePluginMetadata)
	if svcVersion := privateCfg.ServiceVersion(); svcVersion != "" {
		seg.GetService().Version = svcVersion
	}
	seg.ID = NewSegmentID()
	seg.Name = name
	seg.StartTime = float64(time.Now().UnixNano()) / float64(time.Second)
	seg.InProgress = true

	go func() {
		select {
		case <-ctx.Done():
			seg.Lock()
			seg.ContextDone = true
			seg.Unlock()
			if !seg.InProgress && !seg.Emitted {
				seg.flush(false)
			}
		}
	}()

	return context.WithValue(ctx, ContextKey, seg), seg
}

// BeginSubsegment creates a subsegment for a given name and context.
func BeginSubsegment(ctx context.Context, name string) (context.Context, *Segment) {
	if len(name) > 200 {
		name = name[:200]
	}
	parent := GetSegment(ctx)
	if parent == nil {
		privateCfg.ContextMissingStrategy().ContextMissing(fmt.Sprintf("failed to begin subsegment named '%v': segment cannot be found.", name))
		return nil, nil
	}

	seg := &Segment{parent: parent}
	log.Tracef("Beginning subsegment named %s", name)
	seg.ParentSegment = parent.ParentSegment
	seg.ParentSegment.totalSubSegments++
	seg.Lock()
	defer seg.Unlock()

	parent.Lock()
	parent.rawSubsegments = append(parent.rawSubsegments, seg)
	parent.openSegments++
	parent.Unlock()

	seg.ID = NewSegmentID()
	seg.Name = name
	seg.StartTime = float64(time.Now().UnixNano()) / float64(time.Second)
	seg.InProgress = true

	return context.WithValue(ctx, ContextKey, seg), seg
}

// NewSegmentFromHeader creates a segment for downstream call and add information to the segment that gets from HTTP header.
func NewSegmentFromHeader(ctx context.Context, name string, h *header.Header) (context.Context, *Segment) {
	con, seg := BeginSegment(ctx, name)

	if h.TraceID != "" {
		seg.TraceID = h.TraceID
	}
	if h.ParentID != "" {
		seg.ParentID = h.ParentID
	}
	seg.Sampled = h.SamplingDecision == header.Sampled
	seg.IncomingHeader = h

	return con, seg
}

// Close a segment.
func (seg *Segment) Close(err error) {

	seg.Lock()
	if seg.parent != nil {
		log.Tracef("Closing subsegment named %s", seg.Name)
	} else {
		log.Tracef("Closing segment named %s", seg.Name)
	}
	seg.EndTime = float64(time.Now().UnixNano()) / float64(time.Second)
	seg.InProgress = false
	seg.Unlock()

	if err != nil {
		seg.AddError(err)
	}

	seg.flush(false)
}

// RemoveSubsegment removes a subsegment child from a segment or subsegment.
func (seg *Segment) RemoveSubsegment(remove *Segment) bool {
	seg.Lock()
	defer seg.Unlock()

	for i, v := range seg.rawSubsegments {
		if v == remove {
			seg.rawSubsegments[i] = seg.rawSubsegments[len(seg.rawSubsegments)-1]
			seg.rawSubsegments[len(seg.rawSubsegments)-1] = nil
			seg.rawSubsegments = seg.rawSubsegments[:len(seg.rawSubsegments)-1]

			seg.totalSubSegments--
			seg.openSegments--
			return true
		}
	}
	return false
}

func (seg *Segment) flush(decrement bool) {
	seg.Lock()
	if decrement {
		seg.openSegments--
	}
	shouldFlush := (seg.openSegments == 0 && seg.EndTime > 0) || seg.ContextDone
	seg.Unlock()

	if shouldFlush {
		if seg.parent == nil {
			seg.Lock()
			seg.Emitted = true
			seg.Unlock()
			emit(seg)
		} else {
			seg.parent.flush(true)
		}
	}
}

func (seg *Segment) root() *Segment {
	if seg.parent == nil {
		return seg
	}
	return seg.parent.root()
}

func (seg *Segment) addPlugin(metadata *plugins.PluginMetadata) {
	//Only called within a seg locked code block
	if metadata == nil {
		return
	}

	if metadata.IdentityDocument != nil {
		seg.GetAWS()["account_id"] = metadata.IdentityDocument.AccountID
		seg.GetAWS()["instace_id"] = metadata.IdentityDocument.InstanceID
		seg.GetAWS()["availability_zone"] = metadata.IdentityDocument.AvailabilityZone
	}

	if metadata.ECSContainerName != "" {
		seg.GetAWS()["container"] = metadata.ECSContainerName
	}

	if metadata.BeanstalkMetadata != nil {
		seg.GetAWS()["environment"] = metadata.BeanstalkMetadata.Environment
		seg.GetAWS()["version_label"] = metadata.BeanstalkMetadata.VersionLabel
		seg.GetAWS()["deployment_id"] = metadata.BeanstalkMetadata.DeploymentID
	}
}

// AddAnnotation allows adding an annotation to the segment.
func (seg *Segment) AddAnnotation(key string, value interface{}) error {
	switch value.(type) {
	case bool, int, uint, float32, float64, string:
	default:
		return fmt.Errorf("failed to add annotation key: %q value: %q to subsegment %q. value must be of type string, number or boolean", key, value, seg.Name)
	}

	seg.Lock()
	defer seg.Unlock()

	if seg.Annotations == nil {
		seg.Annotations = map[string]interface{}{}
	}
	seg.Annotations[key] = value
	return nil
}

// AddMetadata allows adding metadata to the segment.
func (seg *Segment) AddMetadata(key string, value interface{}) error {
	seg.Lock()
	defer seg.Unlock()

	if seg.Metadata == nil {
		seg.Metadata = map[string]map[string]interface{}{}
	}
	if seg.Metadata["default"] == nil {
		seg.Metadata["default"] = map[string]interface{}{}
	}
	seg.Metadata["default"][key] = value
	return nil
}

// AddMetadataToNamespace allows adding a namespace into metadata for the segment.
func (seg *Segment) AddMetadataToNamespace(namespace string, key string, value interface{}) error {
	seg.Lock()
	defer seg.Unlock()

	if seg.Metadata == nil {
		seg.Metadata = map[string]map[string]interface{}{}
	}
	if seg.Metadata[namespace] == nil {
		seg.Metadata[namespace] = map[string]interface{}{}
	}
	seg.Metadata[namespace][key] = value
	return nil
}

// AddError allows adding an error to the segment.
func (seg *Segment) AddError(err error) error {
	seg.Lock()
	defer seg.Unlock()

	seg.Fault = true
	seg.GetCause().WorkingDirectory, _ = os.Getwd()
	seg.GetCause().Exceptions = append(seg.GetCause().Exceptions, privateCfg.ExceptionFormattingStrategy().ExceptionFromError(err))

	return nil
}
