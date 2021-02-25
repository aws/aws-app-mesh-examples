FROM public.ecr.aws/bitnami/postgresql:10
MAINTAINER massimo@it20.info

WORKDIR /

COPY init-yelb-db.sh /docker-entrypoint-initdb.d/init-yelb-db.sh

ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres_password

