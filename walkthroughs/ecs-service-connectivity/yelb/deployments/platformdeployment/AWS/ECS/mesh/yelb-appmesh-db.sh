
#Pass the DB endpoint to DNS_HostName
cli_input=$( jq -n \
        --arg DNS_HOSTNAME "${YELB_DB_ENDPOINT}" \
        -f "yelb-db-vn.json" )
        
#Create Virtual Node yelb-db
aws appmesh create-virtual-node --mesh-name yelb --virtual-node-name yelb-db --cli-input-json "$cli_input"

#Create Virtual Service and map yelb-db
aws appmesh create-virtual-service --cli-input-json file://yelb-db-vs.json