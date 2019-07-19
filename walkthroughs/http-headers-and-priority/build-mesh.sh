aws appmesh-preview create-mesh --mesh-name header-mesh

aws appmesh-preview create-virtual-router --mesh-name header-mesh --virtual-router-name color-router --cli-input-json file://components/color-router.json

aws appmesh-preview create-virtual-service --mesh-name header-mesh --virtual-service-name color.header-mesh.local --cli-input-json file://components/color-service.json

aws appmesh-preview create-virtual-node --mesh-name header-mesh --virtual-node-name front-node --cli-input-json file://components/front-node.json

aws appmesh-preview create-virtual-node --mesh-name header-mesh --virtual-node-name blue-node --cli-input-json file://components/blue-node.json

aws appmesh-preview create-virtual-node --mesh-name header-mesh --virtual-node-name red-node --cli-input-json file://components/red-node.json

aws appmesh-preview create-virtual-node --mesh-name header-mesh --virtual-node-name green-node --cli-input-json file://components/green-node.json

aws appmesh-preview create-virtual-node --mesh-name header-mesh --virtual-node-name yellow-node --cli-input-json file://components/yellow-node.json

aws appmesh-preview create-route --mesh-name header-mesh --virtual-router-name color-router --route-name color-route-blue --cli-input-json file://components/blue-route.json

aws appmesh-preview create-route --mesh-name header-mesh --virtual-router-name color-router --route-name color-route-red --cli-input-json file://components/red-route.json

aws appmesh-preview create-route --mesh-name header-mesh --virtual-router-name color-router --route-name color-route-green --cli-input-json file://components/green-route.json

aws appmesh-preview create-route --mesh-name header-mesh --virtual-router-name color-router --route-name color-route-yellow --cli-input-json file://components/yellow-route.json
