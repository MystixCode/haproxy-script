FROM debian:bookworm-slim

# needed for socket in haproxy.cfg
RUN mkdir /run/haproxy/
RUN touch /var/run/haproxy.pid

# install dependencies
RUN apt-get -qq update && apt-get -yqq dist-upgrade && apt-get -yqq install apt-transport-https ca-certificates curl gnupg certbot wget socat iproute2 traceroute net-tools

#Add haproxy apt repository
RUN curl https://haproxy.debian.net/bernat.debian.org.gpg \
      | gpg --dearmor > /usr/share/keyrings/haproxy.debian.net.gpg
RUN echo deb "[signed-by=/usr/share/keyrings/haproxy.debian.net.gpg]" \
      http://haproxy.debian.net bookworm-backports-2.8 main \
      > /etc/apt/sources.list.d/haproxy.list

# install packages
RUN apt-get -qq update && apt-get -yqq dist-upgrade && apt-get -yqq install haproxy=2.8.\*

COPY ./conf/* /usr/local/etc/haproxy/

SHELL ["/bin/bash", "-c"]

ENTRYPOINT [ "/usr/local/etc/haproxy/start.sh" ]

CMD [""]
# CMD ["--prod", "example.dev,info@example.dev, 0.0.0.0:3000,0.0.0.1:3000"]
