#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ECR_URL=$1

build_vegeta() {
    aws ecr describe-repositories --repository-name appmesh/vegeta-trafficgen >/dev/null 2>&1 || aws ecr create-repository --repository-name appmesh/vegeta-trafficgen >/dev/null
    docker build -t ${ECR_URL}/appmesh/vegeta-trafficgen ${DIR}/.
    docker push ${ECR_URL}/appmesh/vegeta-trafficgen
}

build_vegeta
