FROM debian:bookworm-slim


# create pidfile, install dependencies, add haproxy apt key and repository, install haproxy
# RUN mkdir /run/haproxy/ && touch /var/run/haproxy.pid && \
# apt-get -qq update && apt-get -yqq dist-upgrade && \
# apt-get -yqq install apt-transport-https ca-certificates curl gnupg certbot wget socat iproute2 traceroute net-tools htop procps git rsyslog && \
# curl https://haproxy.debian.net/bernat.debian.org.gpg | gpg --dearmor > /usr/share/keyrings/haproxy.debian.net.gpg && \
# echo deb "[signed-by=/usr/share/keyrings/haproxy.debian.net.gpg]" http://haproxy.debian.net bookworm-backports-2.8 main \
# > /etc/apt/sources.list.d/haproxy.list && \
# apt-get -qq update && apt-get -yqq dist-upgrade && apt-get -yqq install haproxy=2.8.\*




# roughly, https://salsa.debian.org/haproxy-team/haproxy/-/blob/732b97ae286906dea19ab5744cf9cf97c364ac1d/debian/haproxy.postinst#L5-6
RUN set -eux; \
	groupadd --gid 666 --system haproxy; \
	useradd \
		--gid haproxy \
		--home-dir /var/lib/haproxy \
		--no-create-home \
		--system \
		--uid 666 \
		haproxy \
	; \
	mkdir /var/lib/haproxy; \
	chown haproxy:haproxy /var/lib/haproxy


RUN set -eux; \
    apt-get -qq update; \
    apt-get -yqq dist-upgrade; \
    apt-get -yqq install apt-utils apt-transport-https ca-certificates curl gnupg certbot wget socat iproute2 traceroute net-tools htop procps git; \
    curl https://haproxy.debian.net/bernat.debian.org.gpg | gpg --dearmor > /usr/share/keyrings/haproxy.debian.net.gpg; \
    echo deb "[signed-by=/usr/share/keyrings/haproxy.debian.net.gpg]" http://haproxy.debian.net bookworm-backports-2.8 main > /etc/apt/sources.list.d/haproxy.list; \
    apt-get -qq update; \
    apt-get -yqq dist-upgrade; \
    apt-get -yqq install haproxy=2.8.\*; \
    mkdir /var/run/haproxy; \
    mkdir /dev/log; \
    chown haproxy:haproxy /var/run/haproxy; \
    haproxy -v
 

# Disable rsyslog from loading unavailable imklog
#RUN sed -i '/imklog/s/^/#/' /etc/rsyslog.conf

# Uncomment specific lines in .bashrc using sed. 'll' alias and colors
RUN sed -i '/^# export LS_OPTIONS/s/^# //' /root/.bashrc \
    && sed -i '/^# eval "\$\(dircolors\)"/s/^# //' /root/.bashrc \
    && sed -i '/^# alias ls=/s/^# //' /root/.bashrc \
    && sed -i '/^# alias ll=/s/^# //' /root/.bashrc \
    && sed -i '/^# alias l=/s/^# //' /root/.bashrc

COPY --chown=haproxy:haproxy ./conf/ /usr/local/etc/haproxy/
#COPY ./tls/* /etc/ssl/private/

# Generate diffie-helman if not exists
#RUN if [ ! -f /usr/local/etc/haproxy/dhparams.pem ]; then openssl dhparam -out "/usr/local/etc/haproxy/dhparams.pem" 4096; fi

# Add ocsp cronjob
#RUN echo "0 3 * * * /usr/local/etc/haproxy/ocsp.sh" | tee /etc/crontab

# Add renew cronjob
#RUN echo "0 0 * * * /usr/local/etc/haproxy/renew.sh" | tee /etc/crontab

#SHELL ["/bin/bash", "-c"]
#ENTRYPOINT [ "/usr/local/etc/haproxy/start.sh" ]
#CMD [""]
# CMD ["--prod", "example.dev,info@example.dev, 0.0.0.0:3000,0.0.0.1:3000"]

STOPSIGNAL SIGUSR1

COPY --chmod=777 docker-entrypoint.sh /usr/local/bin/
RUN set -eux; \
    ls -lisah /dev

ENTRYPOINT ["docker-entrypoint.sh"]

USER haproxy

# https://github.com/docker-library/haproxy/issues/200
WORKDIR /var/lib/haproxy

CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy_init.cfg"]