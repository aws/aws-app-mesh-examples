FROM alpine:3.10.1

ENV VEGETA_VERSION 12.8.4

RUN set -ex \
 && apk add --no-cache ca-certificates jq \
 && apk add --no-cache --virtual .build-deps \
    openssl \
 && wget -q "https://github.com/tsenart/vegeta/releases/download/v${VEGETA_VERSION}/vegeta_${VEGETA_VERSION}_linux_amd64.tar.gz" -O /tmp/vegeta.tar.gz \
 && cd bin \
 && tar xzf /tmp/vegeta.tar.gz \
 && rm /tmp/vegeta.tar.gz \
 && apk del .build-deps

RUN apk --no-cache add curl
RUN apk --no-cache add jq

CMD [ "/bin/vegeta", "-help" ]
