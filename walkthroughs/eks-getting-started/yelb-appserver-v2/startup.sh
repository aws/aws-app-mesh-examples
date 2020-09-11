#!/bin/bash

# when the variable is populated a search domain entry is added to resolv.conf at startup
# this is needed for the ECS service discovery given the app works by calling host names and not FQDNs
# a search domain can't be added to the container when using the awsvpc mode 
# and the awsvpc mode is needed for A records (bridge only supports SRV records)
if [ $SEARCH_DOMAIN ]; then echo "search ${SEARCH_DOMAIN}" >> /etc/resolv.conf; fi 

ruby /app/yelb-appserver.rb -o 0.0.0.0