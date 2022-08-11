FROM public.ecr.aws/lambda/python:3.8

ARG FILE

COPY ${FILE} ${LAMBDA_TASK_ROOT}

RUN  pip3 install boto3 --target "${LAMBDA_TASK_ROOT}"
