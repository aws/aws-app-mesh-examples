FROM public.ecr.aws/amazonlinux/amazonlinux:2

RUN yum update -y && \
    yum groupinstall -y "Development Tools" && \
    yum -y install python3 procps openssl-devel git && \
    pip3 install -q Flask requests && \
    # Install wrk2
    mkdir /opt/wrk2 && \ 
    git clone https://github.com/giltene/wrk2.git /opt/wrk2 && \
    cd /opt/wrk2 && \
    make && \
    cp wrk /usr/local/bin && \
    # Remove pip3 & git
    yum -y remove python3-pip git-core && \
    yum clean all && \
    rm -rf /var/cache/yum && \
    cd

COPY wrk.py /usr/bin/wrk.py

EXPOSE 80

ENTRYPOINT ["python3", "/usr/bin/wrk.py"]

