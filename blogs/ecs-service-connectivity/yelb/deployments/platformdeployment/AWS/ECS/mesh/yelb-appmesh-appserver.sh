#Create Virtual Node for Yelb App Server
aws appmesh create-virtual-node --mesh-name yelb --virtual-node-name yelb-app-server --cli-input-json file://yelb-app-vn.json

#Create Virtual service and map it to yelb-app-server
aws appmesh create-virtual-service --cli-input-json file://yelb-app-vs.json