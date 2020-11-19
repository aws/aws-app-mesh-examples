FROM ubuntu:20.04

RUN apt-get -y update
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y install \
    tzdata \
    libgflags-dev \
    build-essential \
    cmake \
    git

WORKDIR /home
COPY ./color.proto .

RUN mkdir -p grpc_client && \
    cd grpc_client && \
    git clone -b v1.33.2 https://github.com/grpc/grpc && \
    cd grpc && \
    git submodule update --init && \
    mkdir -p cmake/build && \
    cd cmake/build && \
    cmake -DgRPC_BUILD_TESTS=ON ../.. && \
    make grpc_cli && \
    cp ./grpc_cli /usr/bin/ && \
    cd /home
