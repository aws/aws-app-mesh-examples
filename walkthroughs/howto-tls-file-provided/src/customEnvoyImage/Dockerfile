ARG ENVOY_IMAGE
FROM ${ENVOY_IMAGE}

RUN yum update -y && \
    yum install -y python3 jq curl unzip && \
    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" && \
    unzip awscli-bundle.zip && \
    sed -i "s/env python/env python3/g" ./awscli-bundle/install && \
    ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws && \
    rm -rf awscli-bundle.zip ./awscli-bundle && \
    yum remove -y python3 unzip && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN mkdir /keys && chown 1337:1337 /keys 

COPY entryPoint.sh /bin/entryPoint.sh

CMD ["/bin/entryPoint.sh"]
