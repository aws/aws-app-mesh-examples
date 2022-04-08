package main

import (
	"crypto/tls"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"

	"golang.org/x/net/http2"
)

func main() {
	color_host_red := os.Getenv("COLOR_HOST_RED")
	if color_host_red == "" {
		log.Fatalf("no COLOR_HOST_RED defined")
	}
	color_host_orange := os.Getenv("COLOR_HOST_ORANGE")
	if color_host_orange == "" {
		log.Fatalf("no COLOR_HOST_ORANGE defined")
	}
	color_host_yellow := os.Getenv("COLOR_HOST_YELLOW")
	if color_host_yellow == "" {
		log.Fatalf("no COLOR_HOST_YELLOW defined")
	}
	color_host_green := os.Getenv("COLOR_HOST_GREEN")
	if color_host_green == "" {
		log.Fatalf("no COLOR_HOST_GREEN defined")
	}
	color_host_blue := os.Getenv("COLOR_HOST_BLUE")
	if color_host_blue == "" {
		log.Fatalf("no COLOR_HOST_BLUE defined")
	}
	color_host_purple := os.Getenv("COLOR_HOST_PURPLE")
	if color_host_purple == "" {
		log.Fatalf("no COLOR_HOST_PURPLE defined")
	}	
	port := os.Getenv("PORT")
	if port == "" {
		log.Fatalf("no PORT defined")
	}
	log.Printf("COLOR_HOST_RED is: %v", color_host_red)
	log.Printf("COLOR_HOST_ORANGE is: %v", color_host_orange)
	log.Printf("COLOR_HOST_YELLOW is: %v", color_host_yellow)		
	log.Printf("COLOR_HOST_GREEN is: %v", color_host_green)
	log.Printf("COLOR_HOST_BLUE is: %v", color_host_blue)
	log.Printf("COLOR_HOST_PURPLE is: %v", color_host_purple)		
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

	http.HandleFunc("/red", func(w http.ResponseWriter, req *http.Request) {
		resp, err := client.Get("http://" + color_host_red + ":" + port)
		if err != nil {
			http.Error(w, err.Error(), 500)
			log.Printf("Could not get color: %v", err)
			return
		}
		defer resp.Body.Close()
		color, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			http.Error(w, err.Error(), 400)
			log.Printf("Could not read response body: %v", err)
			return
		}
		log.Printf("Got color response: %s", string(color))
		fmt.Fprint(w, string(color))
	})

	http.HandleFunc("/orange", func(w http.ResponseWriter, req *http.Request) {
		resp, err := client.Get("http://" + color_host_orange + ":" + port)
		if err != nil {
			http.Error(w, err.Error(), 500)
			log.Printf("Could not get color: %v", err)
			return
		}
		defer resp.Body.Close()
		color, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			http.Error(w, err.Error(), 400)
			log.Printf("Could not read response body: %v", err)
			return
		}
		log.Printf("Got color response: %s", string(color))
		fmt.Fprint(w, string(color))
	})	

	http.HandleFunc("/yellow", func(w http.ResponseWriter, req *http.Request) {
		resp, err := client.Get("http://" + color_host_yellow + ":" + port)
		if err != nil {
			http.Error(w, err.Error(), 500)
			log.Printf("Could not get color: %v", err)
			return
		}
		defer resp.Body.Close()
		color, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			http.Error(w, err.Error(), 400)
			log.Printf("Could not read response body: %v", err)
			return
		}
		log.Printf("Got color response: %s", string(color))
		fmt.Fprint(w, string(color))
	})

	http.HandleFunc("/green", func(w http.ResponseWriter, req *http.Request) {
		resp, err := client.Get("http://" + color_host_green + ":" + port)
		if err != nil {
			http.Error(w, err.Error(), 500)
			log.Printf("Could not get color: %v", err)
			return
		}
		defer resp.Body.Close()
		color, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			http.Error(w, err.Error(), 400)
			log.Printf("Could not read response body: %v", err)
			return
		}
		log.Printf("Got color response: %s", string(color))
		fmt.Fprint(w, string(color))
	})
	
	http.HandleFunc("/blue", func(w http.ResponseWriter, req *http.Request) {
		resp, err := client.Get("http://" + color_host_blue + ":" + port)
		if err != nil {
			http.Error(w, err.Error(), 500)
			log.Printf("Could not get color: %v", err)
			return
		}
		defer resp.Body.Close()
		color, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			http.Error(w, err.Error(), 400)
			log.Printf("Could not read response body: %v", err)
			return
		}
		log.Printf("Got color response: %s", string(color))
		fmt.Fprint(w, string(color))
	})	

	http.HandleFunc("/purple", func(w http.ResponseWriter, req *http.Request) {
		resp, err := client.Get("http://" + color_host_purple + ":" + port)
		if err != nil {
			http.Error(w, err.Error(), 500)
			log.Printf("Could not get color: %v", err)
			return
		}
		defer resp.Body.Close()
		color, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			http.Error(w, err.Error(), 400)
			log.Printf("Could not read response body: %v", err)
			return
		}
		log.Printf("Got color response: %s", string(color))
		fmt.Fprint(w, string(color))
	})

	log.Fatal(http.ListenAndServe("0.0.0.0:" + port, nil))
}
