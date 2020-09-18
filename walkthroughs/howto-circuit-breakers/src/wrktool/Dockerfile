FROM amazonlinux:2

RUN yum -y update
RUN yum groupinstall -y "Development Tools"
RUN yum -y install python3 procps openssl-devel git
RUN pip3 install -q Flask requests

# Install wrk2
RUN mkdir /opt/wrk2 && \
    git clone https://github.com/giltene/wrk2.git /opt/wrk2 && \
    cd /opt/wrk2 && \
    make && \
    cp wrk /usr/local/bin && \
    cd

COPY wrk.py /usr/bin/wrk.py

EXPOSE 80

ENTRYPOINT ["python3", "/usr/bin/wrk.py"]
