aws appmesh-preview delete-route --mesh-name retrypolicy-mesh --virtual-router-name color-router --route-name color-route-blue

aws appmesh-preview delete-virtual-node --mesh-name retrypolicy-mesh --virtual-node-name front-node

aws appmesh-preview delete-virtual-node --mesh-name retrypolicy-mesh --virtual-node-name blue-node

aws appmesh-preview delete-virtual-service --mesh-name retrypolicy-mesh --virtual-service-name color.retrypolicy-mesh.local

aws appmesh-preview delete-virtual-router --mesh-name retrypolicy-mesh --virtual-router-name color-router

aws appmesh-preview delete-mesh --mesh-name retrypolicy-mesh
