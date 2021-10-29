FROM public.ecr.aws/amazonlinux/amazonlinux:2 AS builder
RUN yum update -y && \
    yum install -y ca-certificates unzip tar gzip git && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN curl -LO https://golang.org/dl/go1.17.1.linux-amd64.tar.gz && \
    tar -C /usr/local -xzvf go1.17.1.linux-amd64.tar.gz

ENV PATH="${PATH}:/usr/local/go/bin"
ENV GOPATH="${HOME}/go"
ENV PATH="${PATH}:${GOPATH}/bin"

ARG GO_PROXY=https://proxy.golang.org
WORKDIR /djapp

COPY go.mod .

RUN go env -w GOPROXY=${GO_PROXY}
RUN go mod download

COPY . .
RUN go build

FROM public.ecr.aws/amazonlinux/amazonlinux:2
RUN yum update -y && \
    yum install -y ca-certificates && \
    yum clean all && \
    rm -rf /var/cache/yum
COPY --from=builder /djapp/djapp /djapp

ENV PORT      "8080"
ENV BACKENDS  "[]"
ENV RESPONSES "[]"

ENTRYPOINT ["/djapp"]
