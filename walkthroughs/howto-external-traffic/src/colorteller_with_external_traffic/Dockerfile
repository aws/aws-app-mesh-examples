FROM public.ecr.aws/amazonlinux/amazonlinux:2 AS builder
RUN yum update -y && \
    yum install -y ca-certificates unzip tar gzip git && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN curl -LO https://golang.org/dl/go1.17.1.linux-amd64.tar.gz && \
    tar -C /usr/local -xzvf go1.17.1.linux-amd64.tar.gz

ENV PATH="${PATH}:/usr/local/go/bin"
ENV GOPATH="${HOME}/go"
ENV PATH="${PATH}:${GOPATH}/bin"

# Copy the code from the host and compile it
WORKDIR $GOPATH/src/github.com/username/repo
COPY . ./

# Use the default go proxy
ARG GO_PROXY=https://proxy.golang.org
ENV GOPROXY=$GO_PROXY
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -mod=readonly -a -installsuffix nocgo -o /app .

FROM scratch
COPY --from=builder /app ./
# Copy ca certifcates to make HTTPS requests
COPY --from=builder /etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/
ENTRYPOINT ["./app"]
