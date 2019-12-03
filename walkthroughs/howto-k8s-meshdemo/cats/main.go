package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"

	"github.com/aws/aws-xray-sdk-go/xray"
)

var port string

func init() {
	flag.StringVar(&port, "port", "8080", "port to run on")
	flag.Parse()
}

type Data struct {
	Cat string `json:"cat"`
}

func handler(w http.ResponseWriter, r *http.Request) {
	d := Data{getCat(r.Context())}
	w.Header().Set("Cache-Control", "max-age=0, no-cache, must-revalidate")
	if d.Cat == "error" {
		http.Error(w, "error getting cats", http.StatusServiceUnavailable)
		return
	}
	json.NewEncoder(w).Encode(d)
}

func getCat(c context.Context) (cat string) {
	client := xray.Client(&http.Client{
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	})

	req, err := http.NewRequest("GET", "http://api.thecatapi.com/api/images/get?format=src&type=gif", nil)
	resp, err := client.Do(req.WithContext(c))
	if err != nil {
		log.Print(err)
		cat = "error"
	} else if resp.StatusCode >= http.StatusBadRequest {
		cat = "error"
		log.Print(resp.Status)
	} else {
		cat = resp.Header.Get("Location")
	}
	return
}

func main() {
	log.Printf("starting webserver on port %v", port)
	http.Handle("/", xray.Handler(xray.NewFixedSegmentNamer("cats"), http.HandlerFunc(handler)))
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", port), nil))
}
