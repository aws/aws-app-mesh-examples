ARG ENVOY_IMAGE
FROM ${ENVOY_IMAGE}

ARG AWS_DEFAULT_REGION

RUN yum update -y && \
    yum install -y jq curl unzip openssl less && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rpm -e --nodeps unzip && \
    rm -rf awscliv2.zip ./aws/install && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN mkdir /keys && chown 1337:1337 /keys 

ENV AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
COPY entryPoint.sh /bin/entryPoint.sh

CMD ["/bin/entryPoint.sh"]
