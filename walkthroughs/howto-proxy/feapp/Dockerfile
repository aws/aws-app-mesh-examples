FROM public.ecr.aws/amazonlinux/amazonlinux:2

COPY requirements.txt ./

RUN yum update -y && \
    yum install -y python3 && \
    pip3 install --no-cache-dir -r requirements.txt && \
    yum clean all && \
    rm -rf /var/cache/yum

WORKDIR /usr/src/app

COPY . .

ENV PORT 8080

CMD ["gunicorn", "app:app", "--config=config.py"]