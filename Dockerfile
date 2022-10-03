# syntax=docker/dockerfile:2
FROM debian:11.5-slim

COPY ./copy/* /usr/local/etc/haproxy/
RUN /usr/local/etc/haproxy/bootstrap.sh
CMD /usr/local/etc/haproxy/start.sh
