
#Creates a Virtual Gateway
aws appmesh create-virtual-gateway --cli-input-json file://yelb-vg.json


#Creates Virtual Gateway Route for App
aws appmesh create-gateway-route --cli-input-json file://yelb-app-gateway-route.json


#Creates Virtual Gateway Route for UI 
aws appmesh create-gateway-route --cli-input-json file://yelb-ui-gateway-route.json
