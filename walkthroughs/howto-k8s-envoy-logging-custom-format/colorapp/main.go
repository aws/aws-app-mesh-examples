package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	color, port := os.Getenv("COLOR"), os.Getenv("PORT")

	log.Printf("COLOR: %s", color)
	log.Printf("PORT: %s", port)

	http.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {})
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Received request: %v", r)
		fmt.Fprintf(w, "%s", color)
	})

	log.Fatal(http.ListenAndServe(fmt.Sprintf("0.0.0.0:%s", port), nil))
}
