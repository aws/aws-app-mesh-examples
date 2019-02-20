FROM golang:1.11.2-stretch AS build

WORKDIR /build
COPY . .
RUN go get -d -v ./... && \
    go install -v ./...


FROM debian:stretch
COPY --from=build /go/bin/envoy_cloudwatch_agent /usr/bin/envoy_cloudwatch_agent
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get -y install ca-certificates && \
    useradd -r cwagent
USER cwagent
CMD ["/usr/bin/envoy_cloudwatch_agent"]
