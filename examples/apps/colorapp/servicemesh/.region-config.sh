
regions=$(aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" --output text \
  ssm get-parameters-by-path \
  --path /aws/service/global-infrastructure/services/appmesh/regions \
  --query 'Parameters[].Value')

# convert tab-delimited response into array
SUPPORTED_REGIONS=($(echo $regions | tr '\t' ' '))

DEFAULT_REGION=us-west-2

