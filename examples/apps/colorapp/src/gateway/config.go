package main

import (
	"log"
	"os"
)

// RuntimeConfig defines the config for gatewayapp
type RuntimeConfig struct {
	stage               string
	serverPort          string
	colorTellerEndpoint string
	tcpEchoEndpoint     string
}

// NewRuntimeConfig creates an instance using environment variables
func NewRuntimeConfig() *RuntimeConfig {
	config := &RuntimeConfig{}
	config.stage = os.Getenv("STAGE")
	if config.stage == "" {
		config.stage = "default"
	}

	config.serverPort = os.Getenv("SERVER_PORT")
	if config.serverPort == "" {
		log.Fatalln("SERVER_PORT environment variable is not set")
	}
	log.Printf("Using serverPort %s", config.serverPort)

	config.colorTellerEndpoint = os.Getenv("COLOR_TELLER_ENDPOINT")
	if config.colorTellerEndpoint == "" {
		log.Fatalln("COLOR_TELLER_ENDPOINT environment variable is not set")
	}
	log.Println("Using color-teller at " + config.colorTellerEndpoint)

	config.tcpEchoEndpoint = os.Getenv("TCP_ECHO_ENDPOINT")
	if config.tcpEchoEndpoint == "" {
		log.Fatalln("TCP_ECHO_ENDPOINT environment variable is not set")
	}
	log.Printf("Using tcp-echo at: %s", config.tcpEchoEndpoint)

	return config
}
