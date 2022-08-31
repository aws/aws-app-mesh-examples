package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
)

func startServer(port string) {
	mux := http.NewServeMux()

	mux.Handle("/ping", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	mux.Handle("/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello world %s\n", port)
	}))

	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port), mux))
}

func main() {
	port1, port2 := os.Getenv("PORT1"), os.Getenv("PORT2")

	log.Printf("PORT1: %s", port1)
	log.Printf("PORT2: %s", port2)

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)

	go startServer(port1)
	go startServer(port2)

	_ = <-ch
}
