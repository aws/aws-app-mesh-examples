#!/usr/bin/env bash

set -e

protoc ./color.proto --go_out=plugins=grpc:./color_client/color
protoc ./color.proto --go_out=plugins=grpc:./color_server/color
