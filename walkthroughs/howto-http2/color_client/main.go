package main

import (
	"crypto/tls"
	"io"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"

	"golang.org/x/net/http2"
)

func main() {
	color_host := os.Getenv("COLOR_HOST")
	if color_host == "" {
		log.Fatalf("no COLOR_HOST defined")
	}
	port := os.Getenv("PORT")
	if port == "" {
		log.Fatalf("no PORT defined")
	}
	log.Printf("COLOR_HOST is: %v", color_host)
	log.Printf("PORT is: %v", port)
	// Create an h2c client
	client := &http.Client{
		Transport: &http2.Transport{
			// Allow non-https urls
			AllowHTTP: true,
			// Make the transport *not-actually* use TLS
			DialTLS: func(network, addr string, cfg *tls.Config) (net.Conn, error) {
				return net.Dial(network, addr)			
			},
		},
	}
	http.HandleFunc("/ping", func(w http.ResponseWriter, req *http.Request) {})

	http.HandleFunc("/color", func(w http.ResponseWriter, req *http.Request) {
		resp, err := client.Get("http://"+color_host)
		if err != nil {
			http.Error(w, err.Error(), 500)
			log.Fatalf("Could not get color: %v", err)
		}
		defer resp.Body.Close()
		color, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			http.Error(w, err.Error(), 400)
			log.Printf("Could not read response body: %v", err)
		}
		log.Printf("Got color response: %v", string(color))
		io.WriteString(w, string(color))
	})
	log.Fatal(http.ListenAndServe("0.0.0.0:"+port, nil))
}
