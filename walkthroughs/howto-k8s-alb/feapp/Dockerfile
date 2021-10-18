FROM public.ecr.aws/amazonlinux/amazonlinux:2
RUN yum update -y && \
    yum install -y python3 && \
    yum clean all && \
    rm -rf /var/cache/yum

COPY serve.py ./
RUN chmod +x ./serve.py

CMD ["python3", "-u", "./serve.py"]
