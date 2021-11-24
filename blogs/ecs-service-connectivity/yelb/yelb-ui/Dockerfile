FROM node:14
MAINTAINER massimo@it20.info

WORKDIR /

RUN npm install -g @angular/cli

ADD clarity-seed-newfiles clarity-seed-newfiles 

RUN git clone https://github.com/vmware/clarity-seed.git
WORKDIR /clarity-seed
RUN git checkout -b f3250ee26ceb847f61bb167a90dc957edf6e7f43

RUN cp /clarity-seed-newfiles/src/index.html /clarity-seed/src/index.html
RUN cp /clarity-seed-newfiles/src/styles.css /clarity-seed/src/styles.css
RUN cp /clarity-seed-newfiles/src/env.js /clarity-seed/src/env.js
RUN cp /clarity-seed-newfiles/src/app/app* /clarity-seed/src/app
RUN cp /clarity-seed-newfiles/src/app/env* /clarity-seed/src/app
RUN cp /clarity-seed-newfiles/src/environments/env* /clarity-seed/src/environments
RUN cp /clarity-seed-newfiles/package.json /clarity-seed/package.json
RUN cp /clarity-seed-newfiles/angular-cli.json /clarity-seed/.angular-cli.json
RUN rm -r /clarity-seed/src/app/home
RUN rm -r /clarity-seed/src/app/about

WORKDIR /clarity-seed/src

RUN npm install  

RUN ng build --environment=prod --output-path=./prod/dist/
RUN ng build --environment=test --output-path=./test/dist/
RUN ng build --environment=dev --output-path=./dev/dist/


FROM nginx:1.11.5
MAINTAINER massimo@it20.info

WORKDIR /
ADD startup.sh startup.sh

ENV UI_ENV=prod 

RUN chmod +x startup.sh

COPY --from=0 /clarity-seed/src/prod/dist /clarity-seed/prod/dist
COPY --from=0 /clarity-seed/src/test/dist /clarity-seed/test/dist
COPY --from=0 /clarity-seed/src/dev/dist /clarity-seed/dev/dist

CMD ["./startup.sh"]

