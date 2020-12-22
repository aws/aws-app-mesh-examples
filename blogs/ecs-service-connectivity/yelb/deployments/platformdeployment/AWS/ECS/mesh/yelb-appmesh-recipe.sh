
#Create Virtual Node for Yelb Recipe
aws appmesh create-virtual-node --mesh-name yelb --virtual-node-name yelb-recipe --cli-input-json file://yelb-recipe-vn.json

#Create Virtual Service
aws appmesh create-virtual-service --cli-input-json file://yelb-recipe-vs.json