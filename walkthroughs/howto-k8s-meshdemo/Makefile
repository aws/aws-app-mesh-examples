SHELL=/bin/bash -eo pipefail
.DEFAULT_GOAL := build
REGION=eu-west-1
ACCOUNT=072792469044
REPOFAMILY=${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/meshdemo
VERSION=$(shell cat VERSION)
TAG=${VERSION}

build:
	docker build -t ${REPOFAMILY}/${REPO}:${TAG} -f ${REPO}/Dockerfile ${REPO}

catsrepo:
	$(eval export REPO=cats)
buildcats: | catsrepo build
pushcats: | catsrepo push

colorsrepo:
	$(eval export REPO=colors)
buildcolors: | colorsrepo build
pushcolors: | colorsrepo push

frontendrepo:
	$(eval export REPO=frontend)
buildfrontend: | frontendrepo build
pushfrontend: | frontendrepo push

buildall:
	$(MAKE) buildcats
	$(MAKE) buildfrontend
	$(MAKE) buildcolors

pushall: ecrlogin
	$(MAKE) pushcats
	$(MAKE) pushfrontend
	$(MAKE) pushcolors


ecrlogin:
	aws ecr get-login --region ${REGION} --no-include-email | bash

push:
	docker push ${REPOFAMILY}/${REPO}:${TAG}

