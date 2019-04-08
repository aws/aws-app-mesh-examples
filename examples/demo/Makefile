MESH_NAME=appmesh-demo

#
# Demo
#
.PHONY: k8sdemo appmeshdemo updatecolors cleandemo cleank8sdemo
k8sdemo:
	kubectl apply -f demo/ns.yaml
	kubectl apply -f demo/front-end.yaml
	kubectl apply -f demo/colors.yaml

appmeshdemo:
	$(eval export MESH_NAME)
	cd demo/appmesh/ && \
	./deployappmesh.sh

updatecolors:
	cd demo/appmesh/ && \
	./updatecolors.sh

cleandemo:
	$(eval export MESH_NAME)
	kubectl delete -f demo/ns.yaml
	./demo/appmesh/cleanappmesh.sh

cleank8sdemo:
	kubectl delete -f demo/ns.yaml

