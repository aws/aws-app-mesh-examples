ARG ENVOY_IMAGE
FROM ${ENVOY_IMAGE}

RUN yum install -y jq curl unzip && \
    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" && \
    unzip awscli-bundle.zip && \
    ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws && \
    rm -rf awscli-bundle.zip ./awscli-bundle

RUN mkdir /keys && chown 1337:1337 /keys 

COPY entryPoint.sh /bin/entryPoint.sh

CMD ["/bin/entryPoint.sh"]
