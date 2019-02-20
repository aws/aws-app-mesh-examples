#
# This Dockerfile is here to support running tests
#

FROM node:9 as build

ARG NODE_ENV
ENV NODE_ENV ${NODE_ENV:-development}

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY package.json /usr/src/app/
RUN yarn
COPY . /usr/src/app

CMD [ "npm", "test" ]
