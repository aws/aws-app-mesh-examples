FROM node:9.11.1

RUN npm install -g local-web-server && mkdir /var/meshdemo-site

COPY index.html /var/meshdemo-site/
COPY error.jpg /var/meshdemo-site/
WORKDIR /var/meshdemo-site/

ENTRYPOINT ["ws"]
