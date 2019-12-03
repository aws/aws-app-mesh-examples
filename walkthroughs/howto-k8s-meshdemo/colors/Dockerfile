FROM golang AS builder
WORKDIR /go/src/github.com/aws/aws-app-mesh-examples/walkthroughs/howto-k8s-meshdemo/colors
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main

FROM scratch
COPY --from=builder /go/src/github.com/aws/aws-app-mesh-examples/walkthroughs/howto-k8s-meshdemo/colors/main .
ENTRYPOINT ["./main"]  
