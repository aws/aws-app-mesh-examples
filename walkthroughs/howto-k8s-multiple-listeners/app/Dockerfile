FROM --platform=linux/amd64 golang:1.17.1 AS builder
WORKDIR /workspace
COPY go.mod ./
ENV GOPROXY=direct
RUN go mod download
COPY . ./
RUN go build -o app main.go
FROM public.ecr.aws/amazonlinux/amazonlinux:2
WORKDIR /
COPY --from=builder /workspace/app .
ENTRYPOINT ["/app"]
