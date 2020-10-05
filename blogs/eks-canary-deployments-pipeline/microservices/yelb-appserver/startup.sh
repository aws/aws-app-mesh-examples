#!/bin/bash

# when the variable is populated a search domain entry is added to resolv.conf at startup
# this is needed for the ECS service discovery (a search domain can't be added with awsvpc mode) 
if [ $SEARCH_DOMAIN ]; then echo "search ${SEARCH_DOMAIN}" >> /etc/resolv.conf; fi 

ruby /app/yelb-appserver.rb -o 0.0.0.0