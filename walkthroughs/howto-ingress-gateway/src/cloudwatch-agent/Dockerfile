FROM amazonlinux

# See https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/download-cloudwatch-agent-commandline.html
RUN yum install -y \
    shadow-utils \
    https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm

# start-amazon-cloudwatch-agent uses the environment to generate a config file
# see https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-cloudwatch-agent-configuration-file-wizard.html.
# However, this file cannot be written without providing permissions to uid 1337 that is
# used by containers in the context of App Mesh. 
# NOTICE: copied from https://github.com/istio/istio/blob/master/docker/Dockerfile.base
RUN useradd -m --uid 1337 sidecar-agent && \
    echo "sidecar-agent ALL=NOPASSWD: ALL" >> /etc/sudoers && \
    chown -R sidecar-agent /opt/aws/amazon-cloudwatch-agent

USER sidecar-agent
ENV RUN_IN_CONTAINER="True"
ENTRYPOINT ["/opt/aws/amazon-cloudwatch-agent/bin/start-amazon-cloudwatch-agent"]