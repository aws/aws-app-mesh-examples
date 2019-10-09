package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"

	pb "github.com/aws/aws-app-mesh-examples/walkthroughs/howto-grpc/color_client/color"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func handleRpcError(method string, err error, w http.ResponseWriter) {
	s, _ := status.FromError(err)
	if s.Code() != codes.Unimplemented {
		http.Error(w, err.Error(), 500)
		log.Printf("Something really bad happened: %v %v", s.Code(), err)
		return
	}
	http.Error(w, err.Error(), 404)
	log.Printf("Can't find %s method: %v %v", method, s.Code(), err)
}

func main() {
	colorHost := os.Getenv("COLOR_HOST")
	if colorHost == "" {
		log.Fatalf("no COLOR_HOST defined")
	}
	port := os.Getenv("PORT")
	if port == "" {
		log.Fatalf("no PORT defined")
	}
	log.Printf("COLOR_HOST is: %v", colorHost)
	log.Printf("PORT is: %v", port)

	// Connect to COLOR_HOST
	conn, err := grpc.Dial(colorHost, grpc.WithInsecure())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()
	c := pb.NewColorServiceClient(conn)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	http.HandleFunc("/ping", func(w http.ResponseWriter, req *http.Request) {})

	http.HandleFunc("/getColor", func(w http.ResponseWriter, req *http.Request) {
		log.Printf("Recived getColor request: %v", req)
		resp, err := c.GetColor(ctx, &pb.GetColorRequest{})
		if err != nil {
			handleRpcError("GetColor", err, w)
			return
		}
		log.Printf("Got GetColor response: %v", resp)
		fmt.Fprint(w, strings.ToLower(resp.GetColor().String()))
	})

	http.HandleFunc("/setColor", func(w http.ResponseWriter, req *http.Request) {
		log.Printf("Recieved setColor request: %v", req)
		defer req.Body.Close()
		color, err := ioutil.ReadAll(req.Body)
		if err != nil {
			http.Error(w, err.Error(), 400)
			log.Printf("Could not read request body: %v", err)
			return
		}
		colorString := strings.ToUpper(string(color))
		resp, err := c.SetColor(ctx, &pb.SetColorRequest{Color: pb.Color(pb.Color_value[colorString])})
		if err != nil {
			handleRpcError("SetColor", err, w)
			return
		}
		log.Printf("Got SetColor response: %v", resp)
		fmt.Fprint(w, strings.ToLower(resp.GetColor().String()))
	})

	http.HandleFunc("/getFlakiness", func(w http.ResponseWriter, req *http.Request) {
		log.Printf("Recived getFlakiness request: %v", req)
		resp, err := c.GetFlakiness(ctx, &pb.GetFlakinessRequest{})
		if err != nil {
			handleRpcError("GetFlakiness", err, w)
			return
		}
		log.Printf("Got GetFlakiness response: %v", resp)
		fmt.Fprint(w, resp.String())
	})

	http.HandleFunc("/setFlakiness", func(w http.ResponseWriter, req *http.Request) {
		log.Printf("Recieved setFlakiness request: %v", req)
		query := req.URL.Query()
		rates, ok := query["rate"]
		if !ok {
			http.Error(w, "rate must be specified", 400)
			log.Printf("Could not read rate parameter")
			return
		}
		rate, err := strconv.ParseFloat(rates[0], 32)
		if err != nil {
			http.Error(w, err.Error(), 400)
			log.Printf("Could not parse rate parameter: %v", err)
			return
		}
		if rate < 0.0 || rate > 1.0 {
			http.Error(w, "rate must be between 0.0 and 1.0", 400)
			log.Printf("Invalid rate parameter: %v", rate)
			return
		}

		qCodes, ok := query["code"]
		if !ok {
			http.Error(w, "code must be specified", 400)
			log.Printf("Could not read code parameter: %v", err)
			return
		}

		code, err := strconv.ParseInt(qCodes[0], 10, 32)
		if err != nil {
			http.Error(w, err.Error(), 400)
			log.Printf("Could not parse code parameter: %v", err)
			return
		}
		resp, err := c.SetFlakiness(ctx, &pb.SetFlakinessRequest{
			Flakiness: &pb.Flakiness{Rate: float32(rate), Code: int32(code)},
		})
		if err != nil {
			handleRpcError("SetFlakiness", err, w)
			return
		}
		log.Printf("Got SetFlakiess response: %v", resp)
		fmt.Fprint(w, resp.String())
	})
	log.Fatal(http.ListenAndServe("0.0.0.0:"+port, nil))
}
