FROM node:9 as build

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY package.json /usr/src/app/
RUN yarn
COPY . /usr/src/app

FROM mhart/alpine-node:base-9
ARG NODE_ENV
ENV NODE_ENV ${NODE_ENV:-development}
WORKDIR /usr/src/app
COPY --from=build /usr/src/app .
EXPOSE 3000
ENTRYPOINT [ "node", "app.js" ]
