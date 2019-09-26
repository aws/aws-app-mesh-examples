#!/usr/bin/env bash

set -e

protoc --go_out=plugins=grpc:./color_client/color ./color.proto
protoc --go_out=plugins=grpc:./color_server/color ./color.proto
