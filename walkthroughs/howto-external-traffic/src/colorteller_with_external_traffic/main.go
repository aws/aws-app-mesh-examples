package main

import (
	"fmt"
	"log"
	"net/http"
	"io/ioutil"
	"os"
)

const defaultPort = "8080"
const defaultColor = "black"
const defaultStage = "default"

func getServerPort() string {
	port := os.Getenv("SERVER_PORT")
	if port != "" {
		return port
	}

	return defaultPort
}

func getColor() string {
	color := os.Getenv("COLOR")
	if color != "" {
		return color
	}

	return defaultColor
}

func getStage() string {
	stage := os.Getenv("STAGE")
	if stage != "" {
		return stage
	}

	return defaultStage
}

type colorHandler struct{}
func (h *colorHandler) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	log.Println("color requested, responding with", getColor())
	fmt.Fprint(writer, getColor())
}

type pingHandler struct{}
func (h *pingHandler) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	log.Println("ping requested, reponding with HTTP 200")
	writer.WriteHeader(http.StatusOK)
}

type externalHandler struct{}
func (h *externalHandler) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	log.Println("external service requested, reponding with service response")
	resp, err := http.Get("https://github.com")
	if err != nil {
		log.Println(err)
		fmt.Println("HTTP Response Status:", resp.StatusCode, http.StatusText(resp.StatusCode))
		return
	}
	defer resp.Body.Close()
	responseData, err := ioutil.ReadAll(resp.Body)
    if err != nil {
        log.Println(err)
    }
	writer.Write(responseData)
}

func main() {
	log.Println("starting server, listening on port " + getServerPort())
	http.Handle("/", &colorHandler{})
	http.Handle("/ping", &pingHandler{})
	http.Handle("/external", &externalHandler{})
	http.ListenAndServe(":"+getServerPort(), nil)
}
