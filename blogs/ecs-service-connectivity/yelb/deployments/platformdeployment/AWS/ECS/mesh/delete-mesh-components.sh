
# Delete Gateway Components
aws appmesh delete-gateway-route --gateway-route-name yelbapp-gatewayroute --virtual-gateway yelb-gateway --mesh-name yelb 

aws appmesh delete-gateway-route --gateway-route-name yelbui-gatewayroute --virtual-gateway yelb-gateway --mesh-name yelb 

aws appmesh delete-virtual-gateway --virtual-gateway yelb-gateway --mesh-name yelb


# Delete Virtual Services (AppServer, UI, DB, Redis and RecipePuppy)

aws appmesh delete-virtual-service --mesh-name yelb --virtual-service-name yelb-appserver

aws appmesh delete-virtual-service --mesh-name yelb --virtual-service-name redis-server

aws appmesh delete-virtual-service --mesh-name yelb --virtual-service-name yelb-db

aws appmesh delete-virtual-service --mesh-name yelb --virtual-service-name www.recipepuppy.com

aws appmesh delete-virtual-service --mesh-name yelb --virtual-service-name yelb-ui


# Delete Virtual Nodes (AppServer, UI, DB, Redis and RecipePuppy)

aws appmesh delete-virtual-node --mesh-name yelb --virtual-node-name yelb-redis-server

aws appmesh delete-virtual-node --mesh-name yelb --virtual-node-name yelb-db

aws appmesh delete-virtual-node --mesh-name yelb --virtual-node-name yelb-recipe

aws appmesh delete-virtual-node --mesh-name yelb --virtual-node-name yelb-app-server

aws appmesh delete-virtual-node --mesh-name yelb --virtual-node-name yelb-ui

# Delete the mesh

aws appmesh delete-mesh --mesh-name yelb