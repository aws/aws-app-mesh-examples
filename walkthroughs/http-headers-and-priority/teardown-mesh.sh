aws appmesh-preview delete-route --mesh-name header-mesh --virtual-router-name color-router --route-name color-route-blue

aws appmesh-preview delete-route --mesh-name header-mesh --virtual-router-name color-router --route-name color-route-red

aws appmesh-preview delete-route --mesh-name header-mesh --virtual-router-name color-router --route-name color-route-green

aws appmesh-preview delete-route --mesh-name header-mesh --virtual-router-name color-router --route-name color-route-yellow

aws appmesh-preview delete-virtual-node --mesh-name header-mesh --virtual-node-name front-node

aws appmesh-preview delete-virtual-node --mesh-name header-mesh --virtual-node-name blue-node

aws appmesh-preview delete-virtual-node --mesh-name header-mesh --virtual-node-name red-node

aws appmesh-preview delete-virtual-node --mesh-name header-mesh --virtual-node-name green-node

aws appmesh-preview delete-virtual-node --mesh-name header-mesh --virtual-node-name yellow-node

aws appmesh-preview delete-virtual-service --mesh-name header-mesh --virtual-service-name color.header-mesh.local

aws appmesh-preview delete-virtual-router --mesh-name header-mesh --virtual-router-name color-router

aws appmesh-preview delete-mesh --mesh-name header-mesh
