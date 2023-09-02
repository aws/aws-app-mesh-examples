FROM --platform=${BUILDPLATFORM} golang:1.20 as builder

WORKDIR /go/src/github.com/aws/aws-app-mesh-examples/walkthroughs/howto-http2/color_server

# Use the default go proxy
ARG GO_PROXY=https://proxy.golang.org

# Set the proxies for the go compiler.
ENV GOPROXY=$GO_PROXY

# go.mod and go.sum go into their own layers.
# This ensures `go mod download` happens only when go.mod and go.sum change.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG TARGETOS
ARG TARGETARCH

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -a -installsuffix nocgo -o /color_server .

FROM public.ecr.aws/amazonlinux/amazonlinux:2
RUN yum update -y && \
    yum install -y ca-certificates && \
    yum clean all && \
    rm -rf /var/cache/yum
COPY --from=builder /color_server /color_server

ENTRYPOINT ["/color_server"]
