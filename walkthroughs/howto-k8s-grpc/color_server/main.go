package main

import (
	"context"
	"log"
	"math/rand"
	"net"
	"os"
	"strings"

	pb "github.com/aws/aws-app-mesh-examples/walkthroughs/howto-grpc/color_server/color"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	health "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/status"
)

type colorServer struct {
	color     pb.Color
	flakiness pb.Flakiness
}

func (s *colorServer) GetColor(ctx context.Context, in *pb.GetColorRequest) (*pb.GetColorResponse, error) {
	log.Printf("Received GetColor request")
	// test for random flakiness in the api
	if rand.Float32() < s.flakiness.Rate {
		code := codes.Code(s.flakiness.Code)
		return nil, status.Error(code, code.String())
	}
	return &pb.GetColorResponse{Color: s.color}, nil
}

func (s *colorServer) SetColor(ctx context.Context, in *pb.SetColorRequest) (*pb.SetColorResponse, error) {
	log.Printf("Received SetColor request: %v", in)
	oldColor := s.color
	s.color = in.Color
	return &pb.SetColorResponse{Color: oldColor}, nil
}

func (s *colorServer) GetFlakiness(ctx context.Context, in *pb.GetFlakinessRequest) (*pb.GetFlakinessResponse, error) {
	log.Printf("Received GetFlakiness request")
	return &pb.GetFlakinessResponse{Flakiness: &s.flakiness}, nil
}

func (s *colorServer) SetFlakiness(ctx context.Context, in *pb.SetFlakinessRequest) (*pb.SetFlakinessResponse, error) {
	log.Printf("Received SetFlakiness request: %v", in)
	oldFlakiness := s.flakiness
	s.flakiness = *in.Flakiness
	return &pb.SetFlakinessResponse{Flakiness: &oldFlakiness}, nil
}

func (s *colorServer) Check(ctx context.Context, in *health.HealthCheckRequest) (*health.HealthCheckResponse, error) {
	log.Printf("Received Check request: %v", in)
	return &health.HealthCheckResponse{Status: health.HealthCheckResponse_SERVING}, nil
}

func (s *colorServer) Watch(in *health.HealthCheckRequest, _ health.Health_WatchServer) error {
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
	c := colorServer{color: colorValue}
	pb.RegisterColorServiceServer(s, &c)
	health.RegisterHealthServer(s, &c)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
