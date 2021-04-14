package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
)

const defaultPort = "8080"
const defaultDatabaseDelay = "10s"

// This is a simple HTTP server that has 2 main routes
// POST /price    - simulates a heavy write
// GET /price/$id - sumulates a lighweight read
// You can configure the simulated database/network delay with
// the DATABASE_DELAY env variable
// Example:
// $ PORT=8080 DATABASE_DELAY=30s go run main.go
// $ curl --http2-prior-knowledge -i localhost:8080/
func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}
	log.Printf("PORT is: %v", port)

	databaseDelay, err := time.ParseDuration(os.Getenv("DATABASE_DELAY"))
	if err != nil {
		databaseDelay, err = time.ParseDuration(defaultDatabaseDelay)
	}
	log.Printf("DATABASE_DELAY is: %s", databaseDelay)

	// GET  /health
	r := mux.NewRouter()
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {}).Methods("GET")

	// POST /price
	r.HandleFunc("/price", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s", r.Method, r.RequestURI)
		time.Sleep(databaseDelay)

		fmt.Fprintf(w, "%s", "{ \"status\": \"created\" }")
	}).Methods("POST")

	// GET /price/$id
	r.HandleFunc("/price/{id}", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s", r.Method, r.RequestURI)

		fmt.Fprintf(w, "%s", "{ \"value\": \"23.10\" }")
	}).Methods("GET")

	h2s := &http2.Server{}
	h1s := &http.Server{
		Addr:         "0.0.0.0:" + port,
		Handler:      h2c.NewHandler(r, h2s),
		ReadTimeout:  60 * time.Second,
		WriteTimeout: 60 * time.Second,
	}

	log.Fatal(h1s.ListenAndServe())
}
