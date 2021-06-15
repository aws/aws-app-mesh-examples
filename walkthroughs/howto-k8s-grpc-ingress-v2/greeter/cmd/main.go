package main

import (
	"fmt"
	"greeter/input"
	"greeter/server"
	"log"
	"net"

	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

var (
	port = 9111
)

func main() {
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("Initializing gRPC server on port %d\n", port)
	log.Printf("Listening on %d\n", port)
	grpcServer := grpc.NewServer()
	input.RegisterHelloServer(grpcServer, &server.HelloServer{})
	reflection.Register(grpcServer)
	grpcServer.Serve(lis)
}
