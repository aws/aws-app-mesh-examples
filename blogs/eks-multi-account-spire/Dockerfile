FROM gcr.io/spiffe-io/spire-server:0.10.0
RUN apk -Uuv add groff less python py-pip \
    && pip install awscli \
    && apk --purge -v del py-pip \
    && rm /var/cache/apk/*
CMD []