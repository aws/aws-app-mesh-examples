package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var returnval string
var port string
var latency int
var errors bool
var randomErrors bool
var lasterror int

func init() {
	flag.StringVar(&returnval, "color", "green", "color to return")
	flag.StringVar(&port, "port", "8080", "port to run on")
	flag.IntVar(&latency, "latency", 0, "latency to add")
	flag.BoolVar(&errors, "errors", false, "return errors")
	flag.BoolVar(&randomErrors, "randomErrors", false, "return random errors no more than every fifth request")
	flag.Parse()
}

type Data struct {
	Type string `json:"color"`
}

func handler(w http.ResponseWriter, r *http.Request) {
	if errors {
		http.Error(w, "These are errors", http.StatusInternalServerError)
		return
	}
	if randomErrors {
		if lasterror < 4 {
			http.Error(w, "These are random errors", http.StatusInternalServerError)
			lasterror++
			return
		} else {
			lasterror = 0
		}
	}
	time.Sleep(time.Duration(latency) * time.Second)
	d := Data{returnval}
	json.NewEncoder(w).Encode(d)
}

func main() {
	log.Printf("starting webserver on port %v", port)
	http.HandleFunc("/", handler)
	http.Handle("/metrics", promhttp.Handler())
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", port), nil))
}
