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

WORKDIR /grpc_server

ENV GOPROXY=$GO_PROXY

COPY go.mod .
COPY go.sum .
COPY cmd ./cmd
COPY input ./input
COPY server ./server
RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix nocgo -o greeter ./cmd/main.go

FROM public.ecr.aws/amazonlinux/amazonlinux:2
COPY --from=builder /grpc_server/greeter ./greeter

EXPOSE 9111

ENTRYPOINT ["./greeter"]



