FROM debian:latest as build

RUN apt-get update &&  \
    apt-get install -y ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

RUN curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/debian/amd64/latest/amazon-cloudwatch-agent.deb && \
    dpkg -i -E amazon-cloudwatch-agent.deb && \
    rm -rf /tmp/* && \
    rm -rf /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard && \
    rm -rf /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl && \
    rm -rf /opt/aws/amazon-cloudwatch-agent/bin/config-downloader

# NOTICE: copied from https://github.com/istio/istio/blob/master/docker/Dockerfile.base
# Change ownership to allow agent to write generated files
RUN useradd -m --uid 1337 sidecar-agent && \
    echo "sidecar-agent ALL=NOPASSWD: ALL" >> /etc/sudoers && \
    chown -R sidecar-agent /opt/aws/amazon-cloudwatch-agent

COPY cwagentconfig /etc/cwagentconfig

USER sidecar-agent

ENV RUN_IN_CONTAINER="True"
ENTRYPOINT ["/opt/aws/amazon-cloudwatch-agent/bin/start-amazon-cloudwatch-agent"]