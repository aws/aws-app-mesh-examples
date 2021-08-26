#!/usr/bin/env bash
set -e

kubectl config use-context $FRONT_CXT

echo "Retrieving the ARN of the yelb-appserver virtual service from the backend cluster..."
export VS_ARN=$(kubectl --context $BACK_CXT -n yelb get virtualservice yelb-appserver -o json \
  | jq -r '.status.virtualServiceARN')
 
echo "Creating an update for the yelb-ui virtual node (yelb-ui-final.yaml)..."
( echo "cat <<EOF > mesh/yelb-ui-final.yaml";
  cat mesh/yelb-ui.yaml;
  echo "EOF";
) > temp.sh
chmod +x temp.sh
./temp.sh
rm temp.sh
