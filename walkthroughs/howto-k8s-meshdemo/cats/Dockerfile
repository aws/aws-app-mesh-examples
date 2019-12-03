FROM golang AS builder
WORKDIR /go/src/github.com/jasonrichardsmith/meshdemo-cats
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main

FROM scratch
COPY --from=builder /go/src/github.com/jasonrichardsmith/meshdemo-cats/main .
ENTRYPOINT ["./main"]  
