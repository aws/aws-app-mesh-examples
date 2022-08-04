package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
)

func main() {
	host, port, namespace := os.Getenv("HOST"), os.Getenv("PORT"), os.Getenv("NAMESPACE")

	log.Printf("HOST: %s", host)
	log.Printf("PORT: %s", port)
	log.Printf("NAMESPACE: %s", namespace)

	http.HandleFunc("/ping", func(w http.ResponseWriter, req *http.Request) {})
	http.HandleFunc("/color", func(w http.ResponseWriter, req *http.Request) {
		resp, err := http.Get(fmt.Sprintf("http://%s", host))
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

		fmt.Fprint(w, string(color))
	})

	log.Fatal(http.ListenAndServe(fmt.Sprintf("0.0.0.0:%s", port), nil))
}
