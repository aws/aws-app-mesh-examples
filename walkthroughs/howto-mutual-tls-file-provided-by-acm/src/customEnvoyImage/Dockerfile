ARG ENVOY_IMAGE
FROM ${ENVOY_IMAGE} as envoy
FROM public.ecr.aws/amazonlinux/amazonlinux:2
ARG AWS_DEFAULT_REGION
RUN yum update -y && \
    yum install -y jq curl openssl unzip less && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rpm -e --nodeps unzip && \
    rm -rf awscliv2.zip ./aws/install && \
    yum clean all && \
    rm -rf /var/cache/yum

COPY --from=envoy /usr/bin/envoy /usr/bin/envoy
COPY --from=envoy /usr/bin/agent /usr/bin/agent
COPY --from=envoy /aws_appmesh_aggregate_stats.wasm /aws_appmesh_aggregate_stats.wasm

RUN mkdir /keys && chown 1337:1337 /keys 

ENV AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
COPY entryPoint.sh /bin/entryPoint.sh

CMD ["/bin/entryPoint.sh"]
