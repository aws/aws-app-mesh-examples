FROM node:13.2.0

RUN npm install -g local-web-server && mkdir /var/meshdemo-site

COPY index.html /var/meshdemo-site/
COPY error.jpg /var/meshdemo-site/
WORKDIR /var/meshdemo-site/

ENTRYPOINT ["ws"]
