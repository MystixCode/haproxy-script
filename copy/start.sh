#!/bin/bash

# vars
domains=<replace>
domain=<replace>
email=<replace>
domain_underline=<replace>


# start haproxy with http conf
haproxy -f /usr/local/etc/haproxy/haproxy_http.cfg \
           -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)

# Letsencrypt certificate
#--server https://acme-staging-v02.api.letsencrypt.org/directory \
#--force-renewal \
#--staple-ocsp \
#--must-staple \

certbot certonly --standalone \
-d $domains \
-n \
--preferred-challenges http \
--http-01-port 8443 \
--server https://acme-staging-v02.api.letsencrypt.org/directory \
--email $email \
--agree-tos \
--redirect \
--uir \
--hsts \
--rsa-key-size 4096 \
--staple-ocsp \
--must-staple

#cat /etc/letsencrypt/live/$domain/fullchain.pem /etc/letsencrypt/live/$domain/privkey.pem > /etc/ssl/private/$domain.pem

cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/ssl/private/$domain_underline.crt
cp /etc/letsencrypt/live/$domain/privkey.pem /etc/ssl/private/$domain_underline.crt.key

# generate diffie-helman
#openssl dhparam -out /usr/local/etc/haproxy/dhparams.pem 4096

# reload haproxy with https conf
haproxy -f /usr/local/etc/haproxy/haproxy_https.cfg \
           -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)

# add ocsp cronjob
echo "0 3 * * * /usr/local/etc/haproxy/ocsp.sh" | tee /etc/crontab

# run ocsp.sh
/usr/local/etc/haproxy/ocsp.sh

# run container in loop
tail -f /dev/null
