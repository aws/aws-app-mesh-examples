package main

import (
	"context"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"

	pb "github.com/aws/aws-app-mesh-examples/walkthroughs/howto-grpc/color_client/color"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

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
			s, _ := status.FromError(err)
			if s.Code() != codes.Unimplemented {
				http.Error(w, err.Error(), 500)
			        log.Fatalf("Something really bad happened: %v %v", s.Code(), err)
			}
			http.Error(w, err.Error(), 404)
			log.Printf("Can't find GetColor method: %v %v", s.Code(), err)
			return
		}
		log.Printf("Got GetColor response: %v", resp)
		io.WriteString(w, strings.ToLower(resp.GetColor().String()))
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
			s, _ := status.FromError(err)
			if s.Code() != codes.Unimplemented {
			        http.Error(w, err.Error(), 500)
			        log.Fatalf("Something really bad happened: %v %v", s.Code(), err)
			}
		        http.Error(w, err.Error(), 404)
			log.Printf("Can't find SetColor method: %v %v", s.Code(), err)
			return
		}
		log.Printf("Got SetColor response: %v", resp)
		io.WriteString(w, strings.ToLower(resp.GetColor().String()))
	})
	log.Fatal(http.ListenAndServe("0.0.0.0:"+port, nil))
}
