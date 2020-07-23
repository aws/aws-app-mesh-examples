#!/bin/bash
NGINX_CONF=/etc/nginx/conf.d/default.conf
cd clarity-seed

# when the variable is populated a search domain entry is added to resolv.conf at startup
# this is needed for the ECS service discovery (a search domain can't be added with awsvpc mode) 
if [ $SEARCH_DOMAIN ]; then echo "search ${SEARCH_DOMAIN}" >> /etc/resolv.conf; fi 

sed -i -- 's#/usr/share/nginx/html#/clarity-seed/'$UI_ENV'/dist#g' $NGINX_CONF

# this adds the reverse proxy configuration to nginx 
# everything that hits /api is proxied to the app server     
if ! grep -q "location /api" "$NGINX_CONF"; then
    eval "cat <<EOF
    location /api {
        proxy_pass http://yelb-appserver:4567/api;
        proxy_http_version 1.1;
    }
EOF
" > /proxycfg.txt
    # echo "        proxy_set_header Host $host;" >> /proxycfg.txt
    sed --in-place '/server_name  localhost;/ r /proxycfg.txt' $NGINX_CONF
fi
nginx -g "daemon off;" 


