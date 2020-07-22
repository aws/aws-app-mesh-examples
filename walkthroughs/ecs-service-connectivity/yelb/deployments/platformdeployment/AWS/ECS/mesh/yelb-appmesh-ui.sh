
#create virtual node yelb-ui
aws appmesh create-virtual-node --mesh-name yelb --virtual-node-name yelb-ui --cli-input-json file://yelb-ui-vn.json

#create virtual service
aws appmesh create-virtual-service --cli-input-json file://yelb-ui-vs.json