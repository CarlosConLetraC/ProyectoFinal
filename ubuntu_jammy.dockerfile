FROM ubuntu:22.04

ENV SHELL=/bin/bash
ENV HOME=/home/pc
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y git sudo

RUN adduser --disabled-password --gecos "" pc
RUN echo "pc:1234" | chpasswd
RUN usermod -aG sudo pc

RUN mkdir -p /home/pc && chown -R pc:pc /home/pc

USER pc
WORKDIR /home/pc

CMD ["bash"]
