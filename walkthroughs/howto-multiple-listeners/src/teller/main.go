package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"math/rand"
)

const defaultPort = "1111"
const defaultTell = "color"
var n = rand.Intn(3)
var color = [4]string{ "blue", "green", "red", "yellow" }
var fruit = [4]string{"apple", "banana", "blueberry", "grape" }
var vegetable = [4]string{"broccoli", "corn", "greenbean", "pepper" }

func getServerPort() string {
	port := os.Getenv("PORT")
	if port != "" {
		return port
	}
	return defaultPort
}

func getTell() string {
	tell := os.Getenv("TELL")
	if tell == "fruit" {
        return fruit[n]
    } else if tell == "vegetable" {
        return vegetable[n]
    }
    return color[n]
}

func getTellType() string {
	tell := os.Getenv("TELL")
	if tell == "" {
	    return defaultTell
	}
    return tell
}

type tellHandler struct{}

func (h *tellHandler) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	log.Println(getTellType(), " requested, responding with", getTell())
	fmt.Fprint(writer, getTell())
}

type pingHandler struct{}

func (h *pingHandler) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	log.Println("ping requested, responding with HTTP 200")
	writer.WriteHeader(http.StatusOK)
}

func main() {
	log.Println("starting server, listening on port " + getServerPort())
	http.Handle("/", http.Handler(&tellHandler{}))
	http.Handle("/ping", http.Handler(&pingHandler{}))
	http.ListenAndServe(":"+getServerPort(), nil)
}

