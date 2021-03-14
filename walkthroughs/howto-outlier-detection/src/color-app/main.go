package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"

	"github.com/google/uuid"
)

const defaultPort = "9080"
const niceColor = "purple"

var responseStatus = http.StatusOK
var responseMutex = &sync.Mutex{}

var hostUID = getHostUID()

func getServerPort() string {
	port := os.Getenv("SERVER_PORT")
	if port != "" {
		return port
	}
	return defaultPort
}

func getHostUID() string {
	return uuid.New().String()
}

func main() {
	log.Printf("starting server on port %s\n", getServerPort())
	log.Printf("host unique identifer: %s\n", hostUID)
	http.HandleFunc("/ping", pingHandler)
	http.HandleFunc("/get", colorHandler)
	http.HandleFunc("/fault", faultHandler)
	http.HandleFunc("/recover", recoverHandler)
	log.Fatal(http.ListenAndServe(":"+getServerPort(), nil))
}

func pingHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("received ping.")
}

func colorHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("received get color request.")
	//send back customer header with hostUID
	w.Header().Add("HostUID", hostUID)
	w.WriteHeader(responseStatus)
	if responseStatus == http.StatusOK {
		fmt.Fprintf(w, niceColor)
	} else {
		fmt.Fprintf(w, "no colors 4 u")
	}
}

func faultHandler(w http.ResponseWriter, r *http.Request) {
	responseMutex.Lock()
	defer responseMutex.Unlock()
	responseStatus = http.StatusInternalServerError
	log.Println("received fault request, now returning status ", responseStatus)
	fmt.Fprintf(w, "host: %s will now respond with %d on /get.", hostUID, responseStatus)
}

func recoverHandler(w http.ResponseWriter, r *http.Request) {
	responseMutex.Lock()
	defer responseMutex.Unlock()
	responseStatus = http.StatusOK
	log.Println("received recover request, now returning status ", responseStatus)
	fmt.Fprintf(w, "host: %s will now respond with %d on /get.", hostUID, responseStatus)
}
