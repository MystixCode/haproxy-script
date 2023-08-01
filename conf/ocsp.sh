#!/bin/bash

shopt -s nullglob  # Enable nullglob to prevent executing the loop if no files are found

# Certificates path and names
ssl_dir="/etc/ssl/private"
dir="/usr/local/etc/haproxy/ocsp"
certs="${ssl_dir}/*.pem"

# Check if any certificate files are found before proceeding with the loop
if [[ -n $certs ]]; then
    for cert in $certs; do
        # Get the issuer URI, download its certificate and convert into PEM format
        issuer_uri=$(openssl x509 -in $cert -text -noout | grep 'CA Issuers' | cut -d: -f2,3)
        issuer_name=$(echo ${issuer_uri#*//} | while read -r fname; do echo ${fname%.*}; done)
        mkdir -p $dir
        issuer_pem="${dir}/${issuer_name}.pem"
        wget -q -O- $issuer_uri | openssl x509 -inform DER -outform PEM -out $issuer_pem

        # Get the OCSP URL from the certificate
        ocsp_url=$(openssl x509 -noout -ocsp_uri -in $cert)

        # Extract the hostname from the OCSP URL
        ocsp_host=$(echo $ocsp_url | cut -d/ -f3)

        # Create/update the ocsp response file and update HAProxy
        ocsp_file="${ssl_dir}/${cert##*/}.ocsp"
        echo "** ocsp *****************************"
        # echo "cert: ${cert}"
        # echo "issuer_uri: ${issuer_uri}"
        # echo "issuer_name: ${issuer_name}"
        # echo "issuer_pem: ${issuer_pem}"
        # echo "ocsp_url: ${ocsp_url}"
        # echo "ocsp_host: ${ocsp_host}"
        # echo "ocsp_file: ${ocsp_file}"
        openssl ocsp -noverify -no_nonce -issuer $issuer_pem -cert $cert -url $ocsp_url -header Host=$ocsp_host -respout $ocsp_file
        
        # Reload haproxy
        haproxy -f /usr/local/etc/haproxy/haproxy_tls.cfg -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)

        # Update the OCSP response for HAProxy
        echo -e "set ssl ocsp-response <<\n$(base64 $ocsp_file)\n" | socat stdio /run/haproxy/admin.sock

        # Reload haproxy again
        haproxy -f /usr/local/etc/haproxy/haproxy_tls.cfg -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)

    done
else
    echo "No certificate files found in the specified directory."
fi

exit 0
