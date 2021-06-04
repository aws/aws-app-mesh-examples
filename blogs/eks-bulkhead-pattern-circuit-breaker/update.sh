#!/bin/bash

set -eo pipefail

EXAMPLES_OUT_DIR="${DIR}/_output"

main() {
  kubectl apply -f ./${EXAMPLES_OUT_DIR}/update.yaml
  echo "Updated successfully"
}

main
