#Gets the yelb redis endpoint from yelb-fargate cloudformation stack
export YELB_REDIS_ENDPOINT=$(aws cloudformation describe-stacks --stack-name yelb-fargate --query "Stacks[0].Outputs[?OutputKey=='YelbRedisCacheUrl'].OutputValue" --output text)

#Pass the endpoint to the dns hostname
cli_input=$( jq -n \
        --arg DNS_HOSTNAME "${YELB_REDIS_ENDPOINT}" \
        -f "yelb-redis-vn.json" )

#Create virtual node yelb-redis      
aws appmesh create-virtual-node --mesh-name yelb --virtual-node-name yelb-redis-server --cli-input-json "$cli_input"

#Create virtual service and map it to the virtual node
aws appmesh create-virtual-service --cli-input-json file://yelb-redis-vs.json