package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"net/http"
	"os"
	"strings"

	"github.com/pkg/errors"
)

const defaultPort = "8080"

var stats map[string]float64
var total float64

func getServerPort() string {
	port := os.Getenv("SERVER_PORT")
	if port != "" {
		return port
	}

	return defaultPort
}

func getColorTellerEndpoint() (string, error) {
	colorTellerEndpoint := os.Getenv("COLOR_TELLER_ENDPOINT")
	if colorTellerEndpoint == "" {
		return "", errors.New("COLOR_TELLER_ENDPOINT is not set")
	}
	return colorTellerEndpoint, nil
}

func getColorHandler(writer http.ResponseWriter, request *http.Request) {
	color, err := getColorFromColorTeller()
	if err != nil {
		writer.WriteHeader(http.StatusInternalServerError)
		writer.Write([]byte("500 - Unexpected Error"))
		return
	}
	statsJson, err := json.Marshal(getRatios())
	if err != nil {
		fmt.Fprintf(writer, `{"color":"%s", "error":"%s"}`, color, err)
		return
	}
	fmt.Fprintf(writer, `{"color":"%s", "stats": %s}`, color, statsJson)
}

func getRatios() map[string]float64 {
	ratios := make(map[string]float64)
	for k, v := range stats {
		if total == 0 {
			ratios[k] = 1
		} else {
			ratios[k] = math.Round(v*100/total) / 100
		}
	}

	return ratios
}

func clearColorStatsHandler(writer http.ResponseWriter, request *http.Request) {
	total = 0
	stats = make(map[string]float64)
	fmt.Fprint(writer, "cleared")
}

func getColorFromColorTeller() (string, error) {
	colorTellerEndpoint, err := getColorTellerEndpoint()
	if err != nil {
		return "-n/a-", err
	}

	resp, err := http.Get(fmt.Sprintf("http://%s", colorTellerEndpoint))
	if err != nil {
		return "-n/a-", err
	}

	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "-n/a-", err
	}

	color := strings.TrimSpace(string(body))
	if len(color) < 1 {
		return "-n/a-", errors.New("Empty response from colorTeller")
	}

	total += 1
	stats[color] += 1
	return color, nil
}

func main() {
	log.Println("starting server, listening on port " + getServerPort())
	stats = make(map[string]float64)
	colorTellerEndpoint, err := getColorTellerEndpoint()
	if err != nil {
		log.Fatalln(err)
	}

	log.Println("using color-teller at " + colorTellerEndpoint)
	http.HandleFunc("/color", getColorHandler)
	http.HandleFunc("/color/clear", clearColorStatsHandler)
	log.Fatal(http.ListenAndServe(":"+getServerPort(), nil))
}
