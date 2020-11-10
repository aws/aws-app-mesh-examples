FROM golang:1 AS builder

WORKDIR /go/src/github.com/aws/aws-app-mesh-examples/feapp

# go.mod and go.sum go into their own layers.
# This ensures `go mod download` happens only when go.mod and go.sum change.
COPY go.mod .

RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix nocgo -o /aws-app-mesh-examples-feapp .

FROM amazonlinux:2
RUN yum install -y ca-certificates
COPY --from=builder /aws-app-mesh-examples-feapp bin/aws-app-mesh-examples-feapp

ENTRYPOINT ["/bin/aws-app-mesh-examples-feapp"]
