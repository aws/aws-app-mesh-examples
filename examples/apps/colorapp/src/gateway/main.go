package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-xray-sdk-go/xray"
	"github.com/pkg/errors"
)

// colorHandler serves /color
type colorHandler struct {
	config *RuntimeConfig
	store  Store
}

func (h *colorHandler) getColor(writer http.ResponseWriter, request *http.Request) {
	resp := make(map[string]interface{})

	color, err := h.getColorFromColorTeller(request)
	if err != nil {
		resp["error"] = err.Error()
		h.printResponse(writer, resp)
		return
	}

	resp["color"] = color

	err = h.store.AddColor(color)
	if err != nil {
		resp["error"] = err.Error()
		h.printResponse(writer, resp)
		return
	}

	colorStats, err := h.store.GetStats()
	if err != nil {
		resp["error"] = err.Error()
		h.printResponse(writer, resp)
		return
	}

	resp["stats"] = colorStats
	h.printResponse(writer, resp)
}

func (h *colorHandler) printResponse(writer http.ResponseWriter, resp map[string]interface{}) {
	respJSON, err := json.MarshalIndent(resp, "", "  ")
	if err != nil {
		log.Printf("Error:%s", err)
		writer.WriteHeader(http.StatusInternalServerError)
		writer.Write([]byte("500 - Unexpected Error"))
		return
	}
	fmt.Fprintf(writer, `%s`, respJSON)
}

func (h *colorHandler) getColorFromColorTeller(request *http.Request) (string, error) {
	client := xray.Client(&http.Client{})
	req, err := http.NewRequest(http.MethodGet, fmt.Sprintf("http://%s", h.config.colorTellerEndpoint), nil)
	if err != nil {
		return "-n/a-", err
	}

	resp, err := client.Do(req.WithContext(request.Context()))
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

	return color, nil
}

func (h *colorHandler) clearStats(writer http.ResponseWriter, request *http.Request) {
	err := h.store.ClearStats()
	if err != nil {
		resp := make(map[string]interface{})
		resp["error"] = err.Error()
		h.printResponse(writer, resp)
		return
	}

	h.printStats(writer, request)
}

func (h *colorHandler) printStats(writer http.ResponseWriter, request *http.Request) {
	resp := make(map[string]interface{})

	colorStats, err := h.store.GetStats()
	if err != nil {
		resp["error"] = err.Error()
		h.printResponse(writer, resp)
		return
	}

	resp["stats"] = colorStats
	h.printResponse(writer, resp)
}

// tcpEchoHandler handles /tcpecho requests by forwarding to TCP_ECHO_ENDPOINT
type tcpEchoHandler struct {
	config *RuntimeConfig
}

func (h *tcpEchoHandler) echo(writer http.ResponseWriter, request *http.Request) {
	log.Printf("Dialing tcp endpoint %s", h.config.tcpEchoEndpoint)
	conn, err := net.Dial("tcp", h.config.tcpEchoEndpoint)
	if err != nil {
		writer.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(writer, "Dial failed, err:%s", err.Error())
		return
	}
	defer conn.Close()

	strEcho := "Hello from gateway"
	log.Printf("Writing '%s'", strEcho)
	_, err = fmt.Fprintf(conn, strEcho)
	if err != nil {
		writer.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(writer, "Write to server failed, err:%s", err.Error())
		return
	}

	reply, err := bufio.NewReader(conn).ReadString('\n')
	if err != nil {
		writer.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(writer, "Read from server failed, err:%s", err.Error())
		return
	}

	fmt.Fprintf(writer, "Response from tcpecho server: %s", reply)
}

type pingHandler struct{}

func (h *pingHandler) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	log.Println("ping requested, reponding with HTTP 200")
	writer.WriteHeader(http.StatusOK)
}

func main() {
	config := NewRuntimeConfig()

	xray.Configure(xray.Config{
		LogLevel:  "warn",
		LogFormat: "[%Level] [%Time] %Msg%n",
	})

	xraySegmentNamer := xray.NewFixedSegmentNamer(fmt.Sprintf("%s-gateway", config.stage))

	var store Store
	redisEndpoint := os.Getenv("REDIS_ENDPOINT")
	if redisEndpoint == "" {
		log.Printf("REDIS_ENDPOINT is not specified, using in-memory store")
		store = NewLocalStore()
	} else {
		log.Printf("REDIS_ENDPOINT is specified [%s], using redis store", redisEndpoint)
		store = NewRedisStore(redisEndpoint)
	}

	colorHandler := &colorHandler{
		config: config,
		store:  store,
	}
	http.Handle("/color", xray.Handler(xraySegmentNamer, http.HandlerFunc(colorHandler.getColor)))
	http.Handle("/color/clear", xray.Handler(xraySegmentNamer, http.HandlerFunc(colorHandler.clearStats)))
	http.Handle("/color/stats", xray.Handler(xraySegmentNamer, http.HandlerFunc(colorHandler.printStats)))

	tcpEchoHandler := &tcpEchoHandler{config: config}
	http.Handle("/tcpecho", xray.Handler(xraySegmentNamer, http.HandlerFunc(tcpEchoHandler.echo)))

	log.Fatal(http.ListenAndServe(":"+config.serverPort, nil))
}
