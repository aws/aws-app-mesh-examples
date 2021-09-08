FROM golang:1 AS builder

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



