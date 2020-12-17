FROM nginx

ARG BACKEND_SERVICE
RUN test -n "$BACKEND_SERVICE"
ARG BACKEND_PORT=80
ARG LISTEN_PORT=80

ENV backend_service=$BACKEND_SERVICE
ENV backend_port=$BACKEND_PORT
ENV listen_port=$LISTEN_PORT

COPY nginx.conf /etc/nginx/nginx.conf

CMD /bin/sh -c "envsubst < /etc/nginx/nginx.conf > /etc/nginx/nginx.conf && nginx -g 'daemon off;'"