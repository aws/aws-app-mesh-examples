#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
APP_DIR="${DIR}/../../examples/apps/colorapp"

${APP_DIR}/src/colorteller/deploy.sh
echo "Done deploying color/teller docker image"

${APP_DIR}/src/gateway/deploy.sh
echo "Done deploying color/gateway docker image"
