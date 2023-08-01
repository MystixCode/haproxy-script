#!/bin/bash

haproxy_init_file=/usr/local/etc/haproxy/haproxy_init.cfg
haproxy_tls_file=/usr/local/etc/haproxy/haproxy_tls.cfg

# Function to obtain SSL certificate
get_certificate() {
    echo "- - Obtain SSL certificate - - - - - - - - - - - - - - - - - - - - - - - -"
    local domain="$1"
    local email="$2"

    local acme_url="https://acme-staging-v02.api.letsencrypt.org/directory"
    if [ "$prod_flag" = "true" ]; then
        acme_url="https://acme-v02.api.letsencrypt.org/directory"
    fi

    if ! certbot_output=$(certbot certonly --standalone \
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
        -vv 2>&1); then

        echo "$certbot_output" | awk '/Error/ { if (!seen[$0]++) print }'
    fi

    # copy certificate files to desired location

    cat "/etc/letsencrypt/live/$domain/fullchain.pem" "/etc/letsencrypt/live/$domain/privkey.pem" > "/etc/ssl/private/${domain//./_}.pem"

    echo "/etc/ssl/private/${domain//./_}.pem $domain" >> /usr/local/etc/haproxy/crt-list.txt
    #echo "etc/ssl/private/${domain//./_}.pem [ocsp-update] $domain" > /usr/local/etc/haproxy/crt-list.txt

    #echo "add ssl crt-list /usr/local/etc/haproxy/crt-list.txt /etc/ssl/private/${domain//./_}.pem" | socat stdio unix-connect:/run/haproxy/admin.sock    
    #echo -e "add ssl crt-list /usr/local/etc/haproxy/crt-list.txt <<\n/etc/ssl/private/${domain//./_}.pem [ocsp-update] $domain\n" | socat stdio unix-connect:/run/haproxy/admin.sock
    
    # [[ -e "/etc/letsencrypt/live/$domain/fullchain.pem" ]] && cp "/etc/letsencrypt/live/$domain/fullchain.pem" "/etc/ssl/private/${domain//./_}.crt" && echo "/etc/ssl/private/${domain//./_}.crt"
    # [[ -e "/etc/letsencrypt/live/$domain/privkey.pem" ]] && cp "/etc/letsencrypt/live/$domain/privkey.pem" "/etc/ssl/private/${domain//./_}.crt.key" && echo "/etc/ssl/private/${domain//./_}.crt.key"
}

# Function to add lines to $haproxy_tls_file
add_haproxy_config() {
    echo "- - Add lines to $haproxy_tls_file  - - - - - - - - - - - - - - - - - - - - - - -"

    local domain="$1"
    shift
    local ip_port_pairs=("$@")

    # Temporary file to store the frontend configuration
    tmp_frontend=$(mktemp)

    # Add frontend configuration to the temporary file before the #automated-frontend-tag
    sed "/#automated-frontend-tag/i \\
    acl ACL_$domain hdr(host) -i $domain www.$domain \\
    use_backend $domain if ACL_$domain \\
" $haproxy_tls_file > "$tmp_frontend"

    # Temporary file to store the updated backend configuration
    tmp_backend=$(mktemp)

    # Build backend configuration for all IP:Port pairs
    backend_config="backend $domain \\
    mode http \\
    balance roundrobin \\
    http-response set-header X-Frame-Options SAMEORIGIN \\
    http-response set-header X-XSS-Protection 1;mode=block \\
    http-response set-header X-Content-Type-Options nosniff \\
    #filter compression \\
    #compression direction both \\
    #compression offload \\
    #compression algo-req gzip \\
    #compression type-req application/json \\
    #compression algo-res gzip \\
    #compression type-res text/css text/html text/javascript text/plain"

    for ip_port in "${ip_port_pairs[@]}"; do
        backend_config+=" \\
    server $ip_port $ip_port check maxconn 200"
    done

    # Add the new backend configuration to the temporary file
    sed "/#automated-backend-tag/i \\
$backend_config \\
" "$tmp_frontend" > "$tmp_backend"

    # Replace the original haproxy_tls.cfg file with the updated configuration
    cat "$tmp_backend" > $haproxy_tls_file

    # Clean up the temporary files
    rm "$tmp_frontend" "$tmp_backend"
}

#start rsyslogd
echo "- - Start rsyslogd  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
rsyslogd

# Start haproxy with http conf
echo "- - Start haproxy with http conf  - - - - - - - - - - - - - - - - - - - - - - -"
haproxy -f $haproxy_init_file -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)

# Process command-line options
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

            # Check if domains are provided before proceeding with certificate and HAProxy configuration
            if [[ -n $domain && -n $email && ${#ip_port_pairs[@]} -gt 0 ]]; then
                if [[ -f "/etc/ssl/private/${domain//./_}.pem" ]]; then
                    echo "Certificate files for $domain already exist. Skipping certificate generation."
                else
                    get_certificate "$domain" "$email"
                fi
                add_haproxy_config "$domain" "${ip_port_pairs[@]}"
            else
                echo "Invalid or missing input for domain, email, or IP:Port pairs. Skipping certificate generation and HAProxy configuration."
            fi

            shift
            ;;
    esac
done

# Generate diffie-helman
echo "- - Generate diffie-helman  - - - - - - - - - - - - - - - - - - - - - - - - - -"
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
echo "- - Reload haproxy with https conf  - - - - - - - - - - - - - - - - - - - - - -"
haproxy -f $haproxy_tls_file -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)

# Add ocsp cronjob
echo "- - Add ocsp cronjob - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "0 3 * * * /usr/local/etc/haproxy/ocsp.sh" | tee /etc/crontab

# Add renew cronjob
echo "- - Add renew cronjob - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "0 0 * * * /usr/local/etc/haproxy/renew.sh" | tee /etc/crontab

# Run ocsp.sh
echo "- - Run ocsp.sh  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
/usr/local/etc/haproxy/ocsp.sh

# Run container in a loop
echo "- - Run container in a loop  - - - - - - - - - - - - - - - - - - - - - - - - -"
#tail -f /dev/null
tail -f /var/log/haproxy.log
