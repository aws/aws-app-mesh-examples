#!/bin/bash

main(){
  kubectl delete -f _output/manifest.yaml
  kubectl delete ns spire
}

main
