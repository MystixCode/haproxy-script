#!/bin/bash

copy_cert_files() {
    for dir in "/etc/letsencrypt/live/"*; do
        if [[ -d "$dir" ]]; then
            local domain_name=$(basename "$dir")
            if [[ -e "$dir/fullchain.pem" ]]; then
                cp "$dir/fullchain.pem" "/etc/ssl/private/${domain_name//./_}.crt"
                echo "/etc/ssl/private/${domain_name//./_}.crt"
            fi
            if [[ -e "$dir/privkey.pem" ]]; then
                cp "$dir/privkey.pem" "/etc/ssl/private/${domain_name//./_}.crt.key"
                echo "/etc/ssl/private/${domain_name//./_}.crt.key"
            fi
        fi
    done
}

echo "- - Renew certs - - - - - - - - - - - - - - - - - -"
#certbot renew
certbot renew --force-renew

echo "- - Copy certs - - - - - - - - - - - - - - - - - -"
copy_cert_files

/usr/local/etc/haproxy/ocsp.sh

# # Reload haproxy with https conf
# echo "- - Reload haproxy with new certs - - - - - - - - - - - - - - - - - -"
# haproxy -f /usr/local/etc/haproxy/haproxy.cfg -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)