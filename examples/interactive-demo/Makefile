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
	$(eval export MESH_NAME)
	cd demo/appmesh/ && \
	./updatecolors.sh

cleanappmeshdemo:
	$(eval export MESH_NAME)
	./demo/appmesh/cleanappmesh.sh

cleank8sdemo:
	kubectl delete -f demo/ns.yaml

clean: cleank8sdemo cleanappmeshdemo

