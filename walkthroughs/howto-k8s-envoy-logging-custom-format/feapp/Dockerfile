FROM --platform=linux/amd64 golang:1.17.1 AS builder
WORKDIR /workspace
COPY . ./
ENV GOPROXY=direct
RUN go mod download
RUN go build -o feapp main.go
FROM public.ecr.aws/amazonlinux/amazonlinux:2
WORKDIR /
COPY --from=builder /workspace/feapp .
ENTRYPOINT ["/feapp"]
