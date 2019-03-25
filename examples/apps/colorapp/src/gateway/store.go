package main

import (
	"log"
	"math"
	"strconv"

	"github.com/mediocregopher/radix/v3"
)

// autoClearCountThreshold is the count at which counters will cleared automatically. This will also prevent any int overflow errors when collecting stats.
const autoClearCountThreshold = 10000

// Stats is a container to store count and ratio for a given color
type Stats struct {
	Ratio float64 `json:"ratio"`
	Count int     `json:"count"`
}

// Store is used by gateway app to record colors and hits
type Store interface {
	AddColor(color string) error
	GetStats() (colorStats map[string]*Stats, err error)
	ClearStats() error
}

// LocalStore is an in-memory implementation of Store
type LocalStore struct {
	totalCount int
	data       map[string]int
}

// NewLocalStore returns a new instance of LocalStore
func NewLocalStore() *LocalStore {
	return &LocalStore{data: make(map[string]int)}
}

// AddColor adds color to the store
func (m *LocalStore) AddColor(color string) error {
	if m.totalCount >= autoClearCountThreshold {
		err := m.ClearStats()
		if err != nil {
			return err
		}
	}

	m.totalCount++
	m.data[color]++
	return nil
}

// GetStats returns current stats for all colors
func (m *LocalStore) GetStats() (colorStats map[string]*Stats, err error) {
	totalCount := m.getTotalCount()
	colorStats = make(map[string]*Stats)
	for color, count := range m.data {
		ratio := float64(count) / float64(totalCount)
		colorStats[color] = &Stats{
			Count: count,
			Ratio: math.Round(ratio*100) / 100,
		}
	}

	return colorStats, nil
}

// ClearStats clears the color hits
func (m *LocalStore) ClearStats() error {
	m.totalCount = 0
	m.data = make(map[string]int)
	return nil
}

// getTotalCount returns sum of counts across all colors
func (m *LocalStore) getTotalCount() int {
	return m.totalCount
}

const colorsKey = "colors"
const totalCountKey = "totalCount"

// RedisStore uses redis as a backend for implementing Store
type RedisStore struct {
	redisPool *radix.Pool
}

// NewRedisStore returns a new instance of RedisStore
func NewRedisStore(redisEndpoint string) *RedisStore {
	redisPool, err := radix.NewPool("tcp", redisEndpoint, 10)
	if err != nil {
		log.Fatalf("Error creating redis store %s", err.Error())
	}

	r := &RedisStore{redisPool: redisPool}
	return r
}

// AddColor adds color to the store
func (r *RedisStore) AddColor(color string) error {
	var err error

	totalCount := r.getTotalCount()
	if totalCount >= autoClearCountThreshold {
		err = r.ClearStats()
		if err != nil {
			log.Printf("Error clearing stats: %v", err)
			return err
		}
	}

	err = r.redisPool.Do(radix.Cmd(nil, "INCR", totalCountKey))
	if err != nil {
		log.Printf("Error INCR key[%s]: %v", totalCountKey, err)
		return err
	}

	err = r.redisPool.Do(radix.Cmd(nil, "HINCRBY", colorsKey, color, "1"))
	if err != nil {
		log.Printf("Error HINCRBY hash[%s], key[%s]: %v", colorsKey, color, err)
	}
	return err
}

// GetStats returns current stats for all colors
func (r *RedisStore) GetStats() (map[string]*Stats, error) {
	var err error
	var colorCounts map[string]string

	err = r.redisPool.Do(radix.Cmd(&colorCounts, "HGETALL", colorsKey))
	if err != nil {
		log.Printf("Error HGETALL key[%s]: %v", colorsKey, err)
		return nil, err
	}

	totalCount := r.getTotalCount()

	colorStats := make(map[string]*Stats)
	for color, countVal := range colorCounts {
		count, err := strconv.Atoi(countVal)
		if err != nil {
			log.Printf("Error converting countVal[%s] to int: %v", countVal, err)
			count = 0
		}
		ratio := float64(count) / float64(totalCount)
		colorStats[color] = &Stats{
			Count: count,
			Ratio: math.Round(ratio*100) / 100,
		}
	}

	return colorStats, nil
}

// ClearStats clears the color hits
func (r *RedisStore) ClearStats() error {
	var err error

	err = r.redisPool.Do(radix.Cmd(nil, "DEL", totalCountKey))
	if err != nil {
		log.Printf("Error DEL key[%s]: %v", totalCountKey, err)
		return err
	}

	err = r.redisPool.Do(radix.Cmd(nil, "DEL", colorsKey))
	if err != nil {
		log.Printf("Error DEL key[%s]: %v", colorsKey, err)
	}
	return err
}

// GetTotalCount returns sum of counts across all colors
func (r *RedisStore) getTotalCount() int {
	var err error
	var totalCount int

	err = r.redisPool.Do(radix.Cmd(&totalCount, "GET", totalCountKey))
	if err != nil {
		log.Printf("Error GET key[%s]: %v", totalCountKey, err)
		return r.resetTotalCount()
	}

	return totalCount
}

func (r *RedisStore) resetTotalCount() int {
	var err error
	var colorCounts map[string]string

	totalCount := 0
	err = r.redisPool.Do(radix.Cmd(&colorCounts, "HGETALL", colorsKey))
	if err != nil {
		log.Printf("Error HGETALL key[%s]: %v", colorsKey, err)
		return 0
	}
	for _, countVal := range colorCounts {
		count, err := strconv.Atoi(countVal)
		if err != nil {
			log.Printf("Error converting countVal[%s] to int: %v", countVal, err)
			count = 0
		}
		totalCount += count
	}

	err = r.redisPool.Do(radix.Cmd(nil, "SET", totalCountKey, strconv.Itoa(totalCount)))
	if err != nil {
		log.Printf("Error SET key[%s] to val[%s]: %v", totalCountKey, totalCount, err)
	}
	return totalCount
}
