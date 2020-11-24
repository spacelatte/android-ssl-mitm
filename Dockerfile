#!/usr/bin/env -S docker build --compress -f

FROM debian:stable

RUN apt update
RUN apt install -y adb curl build-essential libssl-dev

ADD https://git.lekensteyn.nl/peter/wireshark-notes/plain/src/sslkeylog.c ./
RUN cc -fPIC -ldl -shared -o libsslkeylog.so sslkeylog.c

