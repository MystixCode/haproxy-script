#!/bin/bash

shopt -u nullglob

# Certificates path and names
SSL_DIR="/etc/ssl/private"
DIR="/usr/local/etc/haproxy/ocsp"
CERTS="${SSL_DIR}/*.crt"

for CERT in $CERTS; do
    # Get the issuer URI, download it's certificate and convert into PEM format
    ISSUER_URI=$(openssl x509 -in $CERT -text -noout | grep 'CA Issuers' | cut -d: -f2,3)
    ISSUER_NAME=$(echo ${ISSUER_URI#*//} | while read -r fname; do echo ${fname%.*}; done)
    mkdir -p $DIR
    ISSUER_PEM="${DIR}/${ISSUER_NAME}.pem"
    wget -q -O- $ISSUER_URI | openssl x509 -inform DER -outform PEM -out $ISSUER_PEM

    # Get the OCSP URL from the certificate
    ocsp_url=$(openssl x509 -noout -ocsp_uri -in $CERT)

    # Extract the hostname from the OCSP URL
    ocsp_host=$(echo $ocsp_url | cut -d/ -f3)

    # Create/update the ocsp response file and update HAProxy
    OCSP_FILE="${SSL_DIR}/${CERT##*/}.ocsp"
    echo "** DEBUG **********************************************"
    echo "CERT: ${CERT}"
    echo "ISSUER_URI: ${ISSUER_URI}"
    echo "ISSUER_NAME: ${ISSUER_NAME}"
    echo "ISSUER_PEM: ${ISSUER_PEM}"
    echo "ocsp_url: ${ocsp_url}"
    echo "ocsp_host: ${ocsp_host}"
    echo "OCSP_FILE: ${OCSP_FILE}"
    echo "******************************************************"
    openssl ocsp -noverify -no_nonce -issuer $ISSUER_PEM -cert $CERT -url $ocsp_url -header Host=$ocsp_host -respout $OCSP_FILE

    #Reload haproxy
    haproxy -f /usr/local/etc/haproxy/haproxy_https.cfg \
            -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)

    #[[ $? -eq 0 ]] && [[ $(pidof haproxy) ]] && [[ -s $OCSP_FILE ]] && echo -e "set ssl ocsp-response <<\n$(base64 $OCSP_FILE)\n" | socat stdio unix-connect:/run/haproxy/admin.sock
    echo -e "set ssl ocsp-response <<\n$(base64 $OCSP_FILE)\n" | socat stdio /run/haproxy/admin.sock

    #Reload haproxy
    haproxy -f /usr/local/etc/haproxy/haproxy_https.cfg \
            -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)

done

exit 0
