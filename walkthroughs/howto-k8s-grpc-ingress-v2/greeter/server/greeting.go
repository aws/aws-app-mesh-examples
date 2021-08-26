package server

import (
	"context"
	"greeter/input"
	"log"
)

type HelloServer struct{}

func (s *HelloServer) SayHello(ctx context.Context, name *input.Name) (*input.Result, error) {
	log.Printf("Received request for: %s\n", name.GetUser())
	return &input.Result{Output: "Hello " + name.GetUser()}, nil
}
