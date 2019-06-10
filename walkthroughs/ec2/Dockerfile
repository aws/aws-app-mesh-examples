FROM amazonlinux:2

RUN yum install -y iproute iptables
COPY ./appmesh-proxy-route-manager.sh /usr/local/bin
ENTRYPOINT [ "/usr/local/bin/appmesh-proxy-route-manager.sh" ]
CMD [ "enable" ]
