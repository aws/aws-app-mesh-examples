package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/go-redis/redis"
)

func main() {
	time.Sleep(30000 * time.Millisecond)

	log.Println("Finished initial sleep, continuing")

	redisEndpoint := os.Getenv("REDIS_ENDPOINT")
	if redisEndpoint == "" {
		log.Fatalln("REDIS_ENDPOINT environment variable is not set")
	}

	log.Println("starting to ping redis server at " + redisEndpoint)

	client := redis.NewClient(&redis.Options{
		Addr:     redisEndpoint,
		Password: "", // no password set
		DB:       0,  // use default DB
	})

	for {
		pong, err := client.Ping().Result()
		fmt.Println(pong, err)
		time.Sleep(5 * time.Second)
	}
}
