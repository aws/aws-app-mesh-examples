FROM public.ecr.aws/amazonlinux/amazonlinux:2

COPY requirements.txt ./

RUN yum update -y && \
    yum install -y python3 && \
    pip3 install --no-cache-dir -r requirements.txt && \
    yum clean all && \
    rm -rf /var/cache/yum

WORKDIR /usr/src/app

RUN yum install -y openssl && \
    openssl req -x509 -nodes -days 365 \
    -subj  "/C=CA/ST=QC/O=Company Inc/CN=example.com" \
     -newkey rsa:2048 -keyout key.pem \
     -out cert.pem;

COPY . .

ENV PORT 8443

CMD ["gunicorn", "--certfile", "cert.pem", "--keyfile", "key.pem", "app:app", "--config=config.py"]
