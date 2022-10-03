#!/bin/bash

# install dependencies
apt-get -qq update
apt-get -yqq upgrade
apt-get -yqq install apt-transport-https lsb-release ca-certificates curl gnupg certbot wget socat

# needed for socket in haproxy_http.cfg
mkdir /run/haproxy/
touch /var/run/haproxy.pid

# add repo key
curl https://haproxy.debian.net/bernat.debian.org.gpg | gpg --dearmor > /usr/share/keyrings/haproxy.debian.net.gpg

# add repo
echo deb '[signed-by=/usr/share/keyrings/haproxy.debian.net.gpg]' http://haproxy.debian.net bullseye-backports-2.6 main > /etc/apt/sources.list.d/haproxy.list

# install haproxy
apt-get -qq update
apt-get -yqq install haproxy=2.6.\*

# check if haproxy.cfg is valid
/usr/sbin/haproxy -c -f /usr/local/etc/haproxy/haproxy_http.cfg
