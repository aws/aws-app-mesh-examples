#!/bin/bash
trap "exit" INT
while true
do
  WEB_URI=$(aws cloudformation describe-stacks --stack-name ${ENVIRONMENT_NAME}-ecs-cluster \
  --query 'Stacks[0].Outputs[?OutputKey==`ExternalUrl`].OutputValue' --output text)
  docker run -it --rm -e WEB_URI=$WEB_URI subfuzion/vote results
  #sleep $(( ( RANDOM % 10 )  + 1 ))
  sleep 3
done
trap 'exit 143' SIGTERM # exit = 128 + 15 (SIGTERM)
tail -f /dev/null & wait ${!}
