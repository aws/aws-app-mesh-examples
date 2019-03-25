package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-xray-sdk-go/xray"
)

const defaultPort = "8080"
const defaultColor = "black"
const defaultStage = "default"

type runtimeConfig struct {
	stage      string
	serverPort string
	color      string
}

type handler struct {
	config *runtimeConfig
}

func (h *handler) getColor(writer http.ResponseWriter, request *http.Request) {
	log.Println("color requested, responding with", h.config.color)
	fmt.Fprint(writer, h.config.color)
}

func (h *handler) ping(writer http.ResponseWriter, request *http.Request) {
	log.Println("ping requested, reponding with HTTP 200")
	writer.WriteHeader(http.StatusOK)
}

func newRuntimeConfig() *runtimeConfig {
	config := &runtimeConfig{}

	config.stage = os.Getenv("STAGE")
	if config.stage == "" {
		config.stage = defaultStage
	}

	config.serverPort = os.Getenv("SERVER_PORT")
	if config.serverPort == "" {
		config.serverPort = defaultPort
	}

	config.color = os.Getenv("COLOR")
	if config.color == "" {
		config.color = defaultColor
	}

	log.Printf("Config initialized to %s", config)

	return config
}

func main() {
	config := newRuntimeConfig()

	xray.Configure(xray.Config{
		LogLevel:  "warn",
		LogFormat: "[%Level] [%Time] %Msg%n",
	})
	xraySegmentNamer := xray.NewFixedSegmentNamer(fmt.Sprintf("%s-colorteller-%s", config.stage, config.color))
	handler := &handler{config: config}
	http.Handle("/", xray.Handler(xraySegmentNamer, http.HandlerFunc(handler.getColor)))
	http.Handle("/ping", xray.Handler(xraySegmentNamer, http.HandlerFunc(handler.ping)))

	http.ListenAndServe(":"+config.serverPort, nil)
}
