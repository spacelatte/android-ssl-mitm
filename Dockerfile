#!/usr/bin/env -S docker build --compress -f

FROM debian:stable

RUN apt update
RUN apt install -y adb curl
