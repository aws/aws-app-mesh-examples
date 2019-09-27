package main

import (
	"io"
	"log"
	"net/http"
	"os"

	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
)

// This is a simple HTTP server that supports cleartext HTTP1.1 and HTTP2
// requests as well as upgrading to HTTP2 via h2c
// Example:
// $ COLOR=red PORT=8080 go run main.go
// $ curl --http2-prior-knowledge -i localhost:8080
func main() {
	color := os.Getenv("COLOR")
	if color == "" {
		log.Fatalf("no COLOR defined")
	}
	port := os.Getenv("PORT")
	if port == "" {
		log.Fatalf("no PORT defined")
	}
	log.Printf("COLOR is: %v", color)
	log.Printf("PORT is: %v", port)
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Received request: %v", r)
		io.WriteString(w, color)
	})
	h2s := &http2.Server{}
	h1s := &http.Server{
		Addr:    "0.0.0.0:" + port,
		Handler: h2c.NewHandler(handler, h2s),
	}
	log.Fatal(h1s.ListenAndServe())
}
