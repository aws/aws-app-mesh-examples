package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"sync"
)

const defaultPort = "8080"

var colorServiceEndpoint = ""

var hostsStats []hostStatusCounter
var counterMutex = &sync.Mutex{}

type hostStatusCounter struct {
	HostUID string
	Counter struct {
		StatusOk    int
		StatusError int
		Total       int
	}
}

func getServerPort() string {
	port := os.Getenv("SERVER_PORT")
	if port != "" {
		return port
	}
	return defaultPort
}

func getColorServiceEndpoint() (string, error) {
	endpoint := os.Getenv("COLOR_SERVICE_ENDPOINT")
	if endpoint != "" {
		return endpoint, nil
	}
	return "", errors.New("COLOR_SERVICE_ENDPOINT is not set")
}

func updateStats(hostUID string, status int) {
	counterMutex.Lock()
	defer counterMutex.Unlock()
	found := false
	for i, h := range hostsStats {
		if h.HostUID == hostUID {
			hostsStats[i].Counter.Total++
			if status == http.StatusOK {
				hostsStats[i].Counter.StatusOk++
			} else {
				hostsStats[i].Counter.StatusError++
			}
			found = true
		}
	}
	if !found {
		var newHost hostStatusCounter
		if status == http.StatusOK {
			newHost = hostStatusCounter{
				HostUID: hostUID,
				Counter: struct {
					StatusOk    int
					StatusError int
					Total       int
				}{
					StatusOk:    1,
					StatusError: 0,
					Total:       1,
				},
			}

		} else {
			newHost = hostStatusCounter{
				HostUID: hostUID,
				Counter: struct {
					StatusOk    int
					StatusError int
					Total       int
				}{
					StatusOk:    0,
					StatusError: 1,
					Total:       1,
				},
			}
		}
		hostsStats = append(hostsStats, newHost)
	}
	fmt.Println("stats updated: ", hostsStats)
}

func main() {
	log.Printf("starting server on port %s\n", getServerPort())
	c, err := getColorServiceEndpoint()
	if c == "" {
		log.Fatalln(err)
	}
	colorServiceEndpoint = c
	http.HandleFunc("/ping", pingHandler)
	http.HandleFunc("/color/get", colorGetHandler)
	http.HandleFunc("/color/fault", colorFaultHandler)
	http.HandleFunc("/color/recover", colorRecoverHandler)
	http.HandleFunc("/stats", statsHandler)
	http.HandleFunc("/reset_stats", resetStatsHandler)
	log.Fatal(http.ListenAndServe(":"+getServerPort(), nil))
}

func pingHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("received ping.")
}

func colorServiceHandler(w http.ResponseWriter, r *http.Request, path string) {
	log.Printf("received color/%s request.", path)
	resp, err := http.Get(fmt.Sprintf("http://%s/%s", colorServiceEndpoint, path))
	if err != nil {
		log.Printf("error in getting response: %s\n", err)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, err.Error())
		return
	}
	if path == "get" {
		updateStats(resp.Header.Get("HostUID"), resp.StatusCode)
	}
	body, err := ioutil.ReadAll(resp.Body)
	w.WriteHeader(resp.StatusCode)
	fmt.Fprintf(w, "%s\n", string(body))
}

func colorGetHandler(w http.ResponseWriter, r *http.Request) {
	colorServiceHandler(w, r, "get")
}

func colorFaultHandler(w http.ResponseWriter, r *http.Request) {
	colorServiceHandler(w, r, "fault")
}

func colorRecoverHandler(w http.ResponseWriter, r *http.Request) {
	colorServiceHandler(w, r, "recover")
}

func statsHandler(w http.ResponseWriter, r *http.Request) {
	json, _ := json.Marshal(hostsStats)
	fmt.Fprintf(w, "%s\n", string(json))
}

func resetStatsHandler(w http.ResponseWriter, r *http.Request) {
	counterMutex.Lock()
	defer counterMutex.Unlock()
	hostsStats = nil
	fmt.Fprintf(w, "stats cleared.\n")
}
