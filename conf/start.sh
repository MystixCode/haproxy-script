#!/bin/bash

# Function to check if certificate files exist
has_certificate() {
    local domain="$1"
    [[ -f "/etc/ssl/private/${domain//./_}.crt" && -f "/etc/ssl/private/${domain//./_}.crt.key" ]]
}

# Function to obtain SSL certificate
get_certificate() {
    local domain="$1"
    local email="$2"

    local acme_url="https://acme-staging-v02.api.letsencrypt.org/directory"
    if [ "$prod_flag" = "true" ]; then
        acme_url="https://acme-v02.api.letsencrypt.org/directory"
    fi

    echo "acme_url: $acme_url"

    certbot certonly --standalone \
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
        --rsa-key-size 4096 \
        --staple-ocsp \
        --must-staple \
        -vv
    
    # copy certificate files to desired location
    [[ -e "/etc/letsencrypt/live/$domain/fullchain.pem" ]] && cp "/etc/letsencrypt/live/$domain/fullchain.pem" "/etc/ssl/private/${domain//./_}.crt"
    [[ -e "/etc/letsencrypt/live/$domain/privkey.pem" ]] && cp "/etc/letsencrypt/live/$domain/privkey.pem" "/etc/ssl/private/${domain//./_}.crt.key"
}

# Function to add lines to haproxy.cfg
add_haproxy_config() {
    local domain="$1"
    shift
    local ip_port_pairs=("$@")

    # Add frontend configuration before the #automated-frontend-tag
    sed -i "/#automated-frontend-tag/i \\
    acl ACL_$domain hdr(host) -i $domain www.$domain \\
    use_backend $domain if ACL_$domain \\
    " /usr/local/etc/haproxy/haproxy.cfg

    # Add backend configuration before the #automated-backend-tag
    sed -i "/#automated-backend-tag/i \\
    backend $domain \\
        mode http \\
        balance roundrobin \\
        http-response set-header X-Frame-Options SAMEORIGIN \\
        http-response set-header X-XSS-Protection 1;mode=block \\
        http-response set-header X-Content-Type-Options nosniff \\
    " /usr/local/etc/haproxy/haproxy.cfg

    # Add server entries to backend
    for ip_port in "${ip_port_pairs[@]}"; do
        sed -i "/#automated-backend-tag/i \\
        server $ip_port $ip_port check maxconn 200 \\
        " /usr/local/etc/haproxy/haproxy.cfg
    done
}

# Start haproxy with http conf
haproxy -f /usr/local/etc/haproxy/haproxy_init.cfg -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)

# Process command-line options using while loop and case statement
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prod)
            prod_flag="true"
            shift
            ;;
        *)
            domain_entry="$1"
            IFS=',' read -ra domain_info <<< "$domain_entry"

            domain="${domain_info[0]}"
            email="${domain_info[1]}"
            ip_port_pairs=("${domain_info[@]:2}")

            # Your existing logic to generate certificates and add HAProxy configurations
            if has_certificate "$domain"; then
                echo "Certificate files for $domain already exist. Skipping certificate generation."
            else
                get_certificate "$domain" "$email"
                add_haproxy_config "$domain" "${ip_port_pairs[@]}"
            fi

            shift
            ;;
    esac
done

# generate diffie-helman
dhparams_file="/usr/local/etc/haproxy/dhparams.pem"

# Check if the DH params file already exists
if [ ! -f "$dhparams_file" ]; then
    # Generate DH parameters using openssl
    openssl dhparam -out "$dhparams_file" 4096
    echo "DH parameters generated and saved to $dhparams_file"
else
    echo "DH parameters file $dhparams_file already exists. Skipping generation."
fi

# Reload haproxy with https conf
haproxy -f /usr/local/etc/haproxy/haproxy.cfg -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)

# Add ocsp cronjob
echo "0 3 * * * /usr/local/etc/haproxy/ocsp.sh" | tee /etc/crontab

# Run ocsp.sh
/usr/local/etc/haproxy/ocsp.sh

# Run container in a loop
tail -f /dev/null
