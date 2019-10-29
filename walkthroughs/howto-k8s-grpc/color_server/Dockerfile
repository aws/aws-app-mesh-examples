FROM golang:1 AS builder

# Use the default go proxy
ARG GO_PROXY=https://proxy.golang.org

WORKDIR /go/src/github.com/aws/aws-app-mesh-examples/walkthroughs/howto-grpc/color_server

# Set the proxies for the go compiler.
ENV GOPROXY=$GO_PROXY

# go.mod and go.sum go into their own layers.
# This ensures `go mod download` happens only when go.mod and go.sum change.
COPY go.mod .
COPY go.sum .
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix nocgo -o /color_server .

FROM amazonlinux:2
RUN yum install -y ca-certificates
COPY --from=builder /color_server /color_server

ENTRYPOINT ["/color_server"]
