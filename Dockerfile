FROM debian:bookworm-slim

# Specify Bash as the default shell
SHELL ["/bin/bash", "-c"]

#Copy everything except things in .dockerignore
COPY --chown=haproxy:haproxy ./ /

RUN set -eux; \
# Create user
groupadd --gid 666 --system haproxy; \
useradd \
--gid haproxy \
--home-dir /var/lib/haproxy \
--no-create-home \
--system \
--uid 666 \
haproxy; \
# Install packages
apt-get -qq update; \
apt-get -yqq dist-upgrade; \
apt-get -yqq install \
apt-utils \
apt-transport-https \
ca-certificates \
curl \
gnupg \
certbot \
wget \
socat \
cron; \
# Add haproxy apt repo
curl https://haproxy.debian.net/bernat.debian.org.gpg | gpg --dearmor \
> /usr/share/keyrings/haproxy.debian.net.gpg; \
echo deb "[signed-by=/usr/share/keyrings/haproxy.debian.net.gpg]" http://haproxy.debian.net bookworm-backports-2.8 main \
> /etc/apt/sources.list.d/haproxy.list; \
# Install haproxy
apt-get -qq update; \
apt-get -yqq dist-upgrade; \
apt-get -yqq install haproxy=2.8.\*; \
# Socket dir
#mkdir -p /usr/local/run/haproxy; \
chown -R haproxy:haproxy /usr/local/run/haproxy; \
# Add cron jobs
chmod 0644 /etc/cron.d/ocsp-cron && crontab /etc/cron.d/ocsp-cron; \
chmod 0644 /etc/cron.d/renew-cron && crontab /etc/cron.d/renew-cron; \
# Generate diffie helmann
if [ ! -f /usr/local/etc/haproxy/dhparams.pem ]; then openssl dhparam -out "/usr/local/etc/haproxy/dhparams.pem" 4096; fi; \
# Permission
chmod a+x /usr/local/bin/docker-entrypoint.sh; \
chown -R haproxy:haproxy /usr/local/etc/certbot; \
chown -R haproxy:haproxy /usr/local/etc/haproxy

USER haproxy
WORKDIR /var/lib/haproxy

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
