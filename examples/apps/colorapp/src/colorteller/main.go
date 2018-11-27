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

func handler(writer http.ResponseWriter, request *http.Request) {
	fmt.Fprint(writer, getColor())
}

func main() {
	log.Println("starting server, listening on port " + getServerPort())
	http.HandleFunc("/", handler)
	http.ListenAndServe(":"+getServerPort(), nil)
}
