FROM public.ecr.aws/amazonlinux/amazonlinux:2 AS builder
RUN yum update -y && \
    yum install -y ca-certificates unzip tar gzip git && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN curl -LO https://golang.org/dl/go1.18.1.linux-amd64.tar.gz && \
    tar -C /usr/local -xzvf go1.18.1.linux-amd64.tar.gz

ENV PATH="${PATH}:/usr/local/go/bin"
ENV GOPATH="${HOME}/go"
ENV PATH="${PATH}:${GOPATH}/bin"

# Copy the code from the host and compile it
WORKDIR $GOPATH/src/github.com/username/repo
COPY Gopkg.toml Gopkg.lock ./
COPY . ./

# Use the default go proxy
ARG GO_PROXY=https://goproxy.io
ENV GOPROXY=$GO_PROXY
RUN go mod tidy -go=1.16 && go mod tidy -go=1.17
RUN CGO_ENABLED=0 GOOS=linux go build -mod=readonly -a -installsuffix nocgo -o /app .

FROM scratch
COPY --from=builder /app ./
ENTRYPOINT ["./app"]
