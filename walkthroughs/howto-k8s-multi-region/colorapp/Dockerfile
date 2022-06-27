FROM public.ecr.aws/bitnami/python:latest

COPY serve.py ./
RUN chmod +x ./serve.py
RUN pip install requests
CMD ["python", "-u", "./serve.py"]
