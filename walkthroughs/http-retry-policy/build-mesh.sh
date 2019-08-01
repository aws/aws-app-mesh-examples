aws appmesh-preview create-mesh --mesh-name retrypolicy-mesh

aws appmesh-preview create-virtual-router --mesh-name retrypolicy-mesh --virtual-router-name color-router --cli-input-json file://components/color-router.json

aws appmesh-preview create-virtual-service --mesh-name retrypolicy-mesh --virtual-service-name color.retrypolicy-mesh.local --cli-input-json file://components/color-service.json

aws appmesh-preview create-virtual-node --mesh-name retrypolicy-mesh --virtual-node-name front-node --cli-input-json file://components/front-node.json

aws appmesh-preview create-virtual-node --mesh-name retrypolicy-mesh --virtual-node-name blue-node --cli-input-json file://components/blue-node.json

aws appmesh-preview create-route --mesh-name retrypolicy-mesh --virtual-router-name color-router --route-name color-route-blue --cli-input-json file://components/blue-route.json
