FROM golang:1 AS builder

WORKDIR /go/src/github.com/aws/aws-app-mesh-examples/price-app

COPY go.mod .
COPY go.sum .
RUN go mod download

COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix nocgo -o /src/price-app .

####

FROM alpine
COPY --from=builder /src/price-app /usr/local/bin/price-app
ENTRYPOINT price-app
