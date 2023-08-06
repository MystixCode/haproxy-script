#!/bin/bash
set -e

echo
echo docker-entrypoint.sh
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo

conf_file="/usr/local/etc/certbot/conf/conf.yml"

# Extract the email using awk
email=$(awk '/^ *email:/ { print $2 }' "$conf_file")
echo "Email: $email"

# Extract the prod flag
prod=$(awk '/^ *prod:/ { print $2 }' "$conf_file")
echo "Prod: $prod"

haproxy -D -f /usr/local/etc/haproxy/haproxy_init.cfg

# Extract the domains array using awk / foreach domain in domains
awk '/^ *domains:/,/]/ { if ($0 ~ /\[/) next; if ($0 ~ /\]/) exit; gsub(/^ +|,$/, ""); print }' "$conf_file" |
while read -r domain; do
    echo
    echo "Obtaining cert for $domain"

    ssl_dir="/usr/local/etc/certbot/conf/live"
    haproxy_cert_dir="/usr/local/etc/haproxy/certs"
    fullchain_path="$ssl_dir/$domain/fullchain.pem"
    privkey_path="$ssl_dir/$domain/privkey.pem"

    if [ ! -e "$haproxy_cert_dir/${domain//./_}.pem" ]; then
        acme_url="https://acme-staging-v02.api.letsencrypt.org/directory"
        if [ "$prod" = "true" ]; then
            acme_url="https://acme-v02.api.letsencrypt.org/directory"
        fi

        certbot certonly --standalone \
            -q \
            -d "$domain" \
            -n \
            --preferred-challenges http \
            --http-01-port 8443 \
            --server "$acme_url" \
            --email "$email" \
            --agree-tos \
            --redirect \
            --uir \
            --hsts \
            --key-type ecdsa \
            --elliptic-curve secp384r1 \
            --staple-ocsp \
            --must-staple \
            --config-dir /usr/local/etc/certbot/conf \
            --work-dir /usr/local/etc/certbot/work \
            --logs-dir /usr/local/etc/certbot/log \
            -vv

        if [ -f "$fullchain_path" ] && [ -f "$privkey_path" ]; then
            echo "Creating PEM in $haproxy_cert_dir/${domain//./_}.pem"
            # merge+copy certificate files to desired location
            cat "$ssl_dir/$domain/fullchain.pem" "$ssl_dir/$domain/privkey.pem" > "$haproxy_cert_dir/${domain//./_}.pem"
        else
            echo "Either fullchain.pem or privkey.pem (or both) are missing for domain $domain in $ssl_dir."
        fi
    else
        echo "Cert already exists for domain $domain. Skipping."
    fi
    #add to crt-list
    echo "$haproxy_cert_dir/${domain//./_}.pem $domain" >> /usr/local/etc/haproxy/crt-list
    #echo "etc/ssl/private/${domain//./_}.pem [ocsp-update on] $domain" > /usr/local/etc/haproxy/crt-list
    #echo "add ssl crt-list /usr/local/etc/haproxy/crt-list /etc/ssl/private/${domain//./_}.pem" | socat stdio unix-connect:/run/haproxy/admin.sock
done

# Run ocsp.sh
echo
echo "Run ocsp.sh"
/usr/local/etc/haproxy/ocsp/ocsp.sh

#kill haproxy_init.cfg instance
killall -15 haproxy

echo "Run command"
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- haproxy "$@"
fi

if [ "$1" = 'haproxy' ]; then
	shift # "haproxy"
	# if the user wants "haproxy", let's add a couple useful flags
	#   -W  -- "master-worker mode" (similar to the old "haproxy-systemd-wrapper"; allows for reload via "SIGUSR2")
	#   -db -- disables background mode
	set -- haproxy -W -db "$@"
fi

exec "$@"
