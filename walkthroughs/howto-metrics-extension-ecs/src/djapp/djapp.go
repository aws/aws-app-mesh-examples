package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"os"
	"time"
)

type backendHandler struct {
	random   *rand.Rand
	backends []string
}

type responseHandler struct {
	random    *rand.Rand
	responses []string
}

func (h *backendHandler) ServeHTTP(w http.ResponseWriter, _ *http.Request) {
	i := h.random.Intn(len(h.backends))
	backend := h.backends[i]
	log.Printf("sending request to %s", backend)

	resp, err := http.Get("http://" + backend)
	if err != nil {
		log.Printf("received error from %s: %s", backend, err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("could not read response from %s: %s", backend, err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	log.Printf("got back %s", string(body))
	w.WriteHeader(http.StatusOK)
	w.Write(body)
}

func (h *responseHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	i := h.random.Intn(len(h.responses))
	response := h.responses[i]
	log.Printf("sending response: %s", response)
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, response)
}

func envOr(key string, orElse string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return orElse
}

func main() {
	port := envOr("PORT", "8080")
	backends := envOr("BACKENDS", "[]")
	responses := envOr("RESPONSES", "[]")

	var parsedBackends []string
	var parsedResponses []string

	if err := json.Unmarshal([]byte(backends), &parsedBackends); err != nil {
		log.Fatalf("unable to parse BACKENDS: %s", err)
	}
	if err := json.Unmarshal([]byte(responses), &parsedResponses); err != nil {
		log.Fatalf("unable to parse RESPONSES: %s", err)
	}

	if len(parsedBackends) == 0 && len(parsedResponses) == 0 {
		log.Fatalln("either BACKENDS or RESPONSES must be specified")
	}
	if len(parsedBackends) > 0 && len(parsedResponses) > 0 {
		log.Fatalln("only BACKENDS or RESPONSES can be specified")
	}

	random := rand.New(rand.NewSource(time.Now().UnixNano()))
	var h http.Handler
	if len(parsedBackends) > 0 {
		log.Printf("backends: %+q", parsedBackends)
		h = &backendHandler{
			backends: parsedBackends,
			random:   random,
		}
	} else {
		log.Printf("responses: %+q", parsedResponses)
		h = &responseHandler{
			responses: parsedResponses,
			random:    random,
		}
	}

	log.Printf("starting server, listening on port %s", port)
	http.Handle("/", h)
	http.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
