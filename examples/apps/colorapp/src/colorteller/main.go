package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

const defaultPort = "8080"
const defaultColor = "black"

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

func colorHandler(writer http.ResponseWriter, request *http.Request) {
	log.Println("color requested, responding with", getColor())
	fmt.Fprint(writer, getColor())
}

func pingHandler(writer http.ResponseWriter, request *http.Request) {
	log.Println("ping requested, reponding with HTTP 200")
	writer.WriteHeader(http.StatusOK)
}

func main() {
	log.Println("starting server, listening on port " + getServerPort())
	http.HandleFunc("/", colorHandler)
	http.HandleFunc("/ping", pingHandler)
	http.ListenAndServe(":"+getServerPort(), nil)
}
