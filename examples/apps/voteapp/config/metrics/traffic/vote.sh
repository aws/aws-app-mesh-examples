!/bin/bash
WEB_URI=$(aws cloudformation describe-stacks --stack-name ${ENVIRONMENT_NAME}-ecs-cluster \
--query 'Stacks[0].Outputs[?OutputKey==`ExternalUrl`].OutputValue' --output text)
docker run -it --rm -e WEB_URI=$WEB_URI subfuzion/vote vote
