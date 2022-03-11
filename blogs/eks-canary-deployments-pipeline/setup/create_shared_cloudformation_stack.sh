#!/usr/bin/env bash

# Load environment variables
source ~/.bash_profile

# Create a new S3 bucket with a random name suffix because S3 bucket names are unique
RANDOM_STRING=$(LC_ALL=C tr -dc 'a-z' </dev/urandom | head -c 10 ; echo)
S3_BUCKET_NAME=$(aws s3 mb s3://eks-canary-blogpost-cloudformation-files-$RANDOM_STRING --region $AWS_REGION | cut -d' ' -f2)
echo "export S3_BUCKET_NAME=${S3_BUCKET_NAME}" | tee -a ~/.bash_profile

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Get the base directory path that will be used to zip the resources before uploading to S3
base_path="$(dirname $(dirname $(realpath $0)) )"


if [ $USE_SAMPLE_MICROSERVICES == "True" ]
then
  cd /tmp
  git clone https://github.com/mreferre/yelb.git
  
  cp /tmp/yelb/yelb-ui/* $base_path/microservices/yelb-ui/ -rf
  cp /tmp/yelb/yelb-db/* $base_path/microservices/yelb-db/ -rf
  cp /tmp/yelb/yelb-appserver/* $base_path/microservices/yelb-appserver/ -rf
  
  cd $base_path/microservices
  
  for dockerfile in `find ./ |grep Dockerfile`
    do
      for image in `cat $dockerfile |grep FROM|cut -d ' ' -f2`
        do
          if ! echo $image |grep -q '/'; then
            echo "Adding $image to ECR"
            docker pull $image
            imagename=$(echo $image |cut -d ':' -f1)
            aws ecr create-repository --repository-name $imagename --region $AWS_REGION
            docker tag $image $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$image
            docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$image
            sed -i.bak "s#$image#$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$image#g" $dockerfile
            
          fi
        done
    done
  
  #Modifying the increment to 2 to demonstrate in blog post
  sed -i "s/count +1 WHERE name/count +2 WHERE name/g" $base_path/microservices/yelb-appserver/modules/restaurantsdbupdate.rb
  
  
  
  # Zip the microservice resources
  cd $base_path/microservices/yelb-ui && zip -r yelb-ui.zip ./* > /dev/null
  cd $base_path/microservices/yelb-db && zip -r yelb-db.zip ./* > /dev/null
  cd $base_path/microservices/yelb-appserver && zip -r yelb-appserver.zip ./* > /dev/null
  cd $base_path/microservices/redis-server && zip -r redis-server.zip ./* > /dev/null
fi

# Zip the lambda function resources
cd $base_path/shared_stack/lambda_functions/check_deployment_version && zip -r function.zip ./* > /dev/null
cd $base_path/shared_stack/lambda_functions/deploy_and_switch_traffic && zip -r function.zip ./* > /dev/null
cd $base_path/shared_stack/lambda_functions/gather_healthcheck_status && zip -r function.zip ./* > /dev/null
cd $base_path/shared_stack/lambda_functions/rollback_or_finish_upgrade && zip -r function.zip ./* > /dev/null
cd $base_path/shared_stack/lambda_functions/update_deployment_version && zip -r function.zip ./* > /dev/null

# Move back to the base directory
cd $base_path
echo $S3_BUCKET_NAME
# Upload the resources to the bucket created
aws s3 cp ./ s3://$S3_BUCKET_NAME --recursive --region $AWS_REGION > /dev/null

# Get the AWS Lambda Layer ARN from last AWS CloudFormation stack output
LAMBDA_LAYER_ARN=$(aws cloudformation describe-stacks --stack-name kubectl-lambda-layer \
--region $AWS_REGION --output json | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "LayerVersionArn") | .OutputValue')

# Deploy AWS CloudFormation Stack
aws cloudformation create-stack --stack-name $SHARED_STACK_NAME \
--template-url "https://$S3_BUCKET_NAME.s3.amazonaws.com/shared_stack/stepfuntions_cloudformation.yml" \
--parameters ParameterKey=SourceCodeBucket,ParameterValue="$S3_BUCKET_NAME" \
ParameterKey=EKSClusterARN,ParameterValue="$EKS_CLUSTER_ARN" \
ParameterKey=LambdaLayerName,ParameterValue="$LAMBDA_LAYER_ARN" \
--capabilities CAPABILITY_IAM \
--region $AWS_REGION

echo -n "Creating the AWS CloudFormation stack"
while [ "$(aws cloudformation describe-stacks --stack-name $SHARED_STACK_NAME --region $AWS_REGION --output json | jq -r '.Stacks[0].StackStatus')" == "CREATE_IN_PROGRESS" ]; do
  echo -n '.'
  sleep 10
done
echo -e "\n$(aws cloudformation describe-stacks --stack-name $SHARED_STACK_NAME --region $AWS_REGION --output json | jq -r '.Stacks[0].StackStatus')"


#Cleanup
rm /tmp/yelb -rf
rm $base_path/microservices/yelb-ui/* 2> /dev/null 
rm $base_path/microservices/yelb-ui/clarity-seed-newfiles -rf
rm $base_path/microservices/yelb-db/* 2> /dev/null
rm $base_path/microservices/yelb-appserver/* 2> /dev/null
rm $base_path/microservices/yelb-appserver/modules -rf
rm $base_path/microservices/redis-server/redis-server.zip
rm $base_path/microservices/redis-server/Dockerfile 2> /dev/null
mv $base_path/microservices/redis-server/Dockerfile.bak $base_path/microservices/redis-server/Dockerfile
rm $base_path/shared_stack/lambda_functions/check_deployment_version/function.zip
rm $base_path/shared_stack/lambda_functions/deploy_and_switch_traffic/function.zip
rm $base_path/shared_stack/lambda_functions/gather_healthcheck_status/function.zip 
rm $base_path/shared_stack/lambda_functions/rollback_or_finish_upgrade/function.zip
rm $base_path/shared_stack/lambda_functions/update_deployment_version/function.zip