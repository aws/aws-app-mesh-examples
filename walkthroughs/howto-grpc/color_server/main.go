package main

import (
	"context"
	"log"
	"net"
	"os"
	"strings"

	pb "github.com/aws/aws-app-mesh-examples/walkthroughs/howto-grpc/color_server/color"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	health "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/status"
)

type server struct {
	color pb.Color
}

func (s *server) GetColor(ctx context.Context, in *pb.GetColorRequest) (*pb.GetColorResponse, error) {
	log.Printf("Received GetColor request")
	return &pb.GetColorResponse{Color: s.color}, nil
}

func (s *server) SetColor(ctx context.Context, in *pb.SetColorRequest) (*pb.SetColorResponse, error) {
	log.Printf("Received SetColor request: %v", in)
	oldColor := s.color
	s.color = in.Color
	return &pb.SetColorResponse{Color: oldColor}, nil
}

func (s *server) Check(ctx context.Context, in *health.HealthCheckRequest) (*health.HealthCheckResponse, error) {
	log.Printf("Received Check request: %v", in)
	return &health.HealthCheckResponse{Status: health.HealthCheckResponse_SERVING}, nil
}

func (s *server) Watch(in *health.HealthCheckRequest, _ health.Health_WatchServer) error {
	log.Printf("Received Watch request: %v", in)
	return status.Error(codes.Unimplemented, "unimplemented")
}

func main() {
	color := os.Getenv("COLOR")
	if color == "" {
		log.Fatalf("no COLOR defined")
	}
	port := os.Getenv("PORT")
	if port == "" {
		log.Fatalf("no PORT defined")
	}
	log.Printf("COLOR is: %v", color)
	log.Printf("PORT is: %v", port)
	lis, err := net.Listen("tcp", "0.0.0.0:"+port)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	colorValue := pb.Color(pb.Color_value[strings.ToUpper(color)])
	pb.RegisterColorServiceServer(s, &server{color: colorValue})
	health.RegisterHealthServer(s, &server{color: colorValue})
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
