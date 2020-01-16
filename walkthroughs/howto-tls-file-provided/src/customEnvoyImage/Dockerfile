ARG AWS_ENVOY_IMAGE
FROM ${AWS_ENVOY_IMAGE}

RUN yum install -y jq
RUN yum install -y curl
RUN yum install -y unzip
RUN curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
RUN unzip awscli-bundle.zip
RUN ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws

RUN mkdir /keys
RUN chown 1337:1337 /keys 

COPY entryPoint.sh /bin/entryPoint.sh

CMD ["/bin/entryPoint.sh"]
