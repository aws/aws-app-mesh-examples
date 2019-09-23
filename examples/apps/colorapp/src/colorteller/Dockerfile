FROM golang:1-stretch as builder
WORKDIR /go/src/github.com/aws/aws-app-mesh-examples/colorapp/teller

# Force the go compiler to use modules.
ENV GO111MODULE=on

# go.mod and go.sum go into their own layers.
COPY go.mod .
COPY go.sum .

# Force the go compiler to ignore proxies
RUN go env -w GOPROXY=direct
# This ensures `go mod download` happens only when go.mod and go.sum change.
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix nocgo -o /aws-app-mesh-examples-colorapp-teller .

FROM amazonlinux:2
RUN yum install -y ca-certificates
COPY --from=builder /aws-app-mesh-examples-colorapp-teller /bin/aws-app-mesh-examples-colorapp-teller

ENTRYPOINT ["/bin/aws-app-mesh-examples-colorapp-teller"]
