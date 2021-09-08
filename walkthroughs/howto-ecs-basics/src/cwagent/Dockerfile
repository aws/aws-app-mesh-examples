FROM public.ecr.aws/amazonlinux/amazonlinux:2
RUN yum update -y && \
    yum install -y \
    shadow-utils \
    https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm && \
    yum clean all && \
    rm -rf /var/cache/yum

# NOTICE: copied from https://github.com/istio/istio/blob/master/docker/Dockerfile.base
# Change ownership to allow agent to write generated files
RUN useradd -m --uid 1337 sidecar-agent && \
    echo "sidecar-agent ALL=NOPASSWD: ALL" >> /etc/sudoers && \
    chown -R sidecar-agent /opt/aws/amazon-cloudwatch-agent

USER sidecar-agent
ENV RUN_IN_CONTAINER="True"
ENTRYPOINT ["/opt/aws/amazon-cloudwatch-agent/bin/start-amazon-cloudwatch-agent"]