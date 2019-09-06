// Copyright 2017-2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
//
//     http://aws.amazon.com/apache2.0/
//
// or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

package plugins

import (
	"github.com/aws/aws-sdk-go/aws/ec2metadata"
)

// InstancePluginMetadata points to the PluginMetadata struct.
var InstancePluginMetadata = &PluginMetadata{}

// PluginMetadata struct contains items to record information
// about the AWS infrastructure hosting the traced application.
type PluginMetadata struct {

	// IdentityDocument records the shape for unmarshaling an
	// EC2 instance identity document.
	IdentityDocument *ec2metadata.EC2InstanceIdentityDocument

	// BeanstalkMetadata records the Elastic Beanstalk
	// environment name, version label, and deployment ID.
	BeanstalkMetadata *BeanstalkMetadata

	// ECSContainerName records the ECS container ID.
	ECSContainerName string
}

// BeanstalkMetadata provides the shape for unmarshaling
// Elastic Beanstalk environment metadata.
type BeanstalkMetadata struct {
	Environment  string `json:"environment_name"`
	VersionLabel string `json:"version_label"`
	DeploymentID int    `json:"deployment_id"`
}
