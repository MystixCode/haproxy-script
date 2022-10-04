#!/usr/bin/env python3

import os

# Change these values:
###################################################################
email="info@yourdomain.xyz"
domain="yourdomain.xyz"
domainsAndProxyPass=[
    {
        "domain": "yourdomain.xyz",
        "proxy_passes": [
            "0.0.0.0:3000",
            "192.168.1.100:3001"
        ]
    },
    {
        "domain": "sub1.yourdomain.xyz",
        "proxy_passes": [
            "0.0.0.0:4000",
            "192.168.1.101:4001"
        ]
    },
    {
        "domain": "sub2.yourdomain.xyz",
        "proxy_passes": [
            "0.0.0.0:5000",
            "192.168.1.102:5001"
        ]
    }
]
###################################################################

print("haproxy-script")

#make it a comma separated string
domainsComma = ""
first=True
for item in domainsAndProxyPass:
    if first == True:
        domainsComma=item["domain"]
        first=False
    else:
        domainsComma=domainsComma+","+item["domain"]

domainUnderline=domain.replace(".", "_")

def configure_haproxy_container():
    #replace lines in file
    os.system(f"sed -i 's/^domains=.*/domains={domainsComma}/' copy/start.sh")
    os.system(f"sed -i 's/^domain=.*/domain={domain}/' copy/start.sh")
    os.system(f"sed -i 's/^email=.*/email={email}/' copy/start.sh")
    os.system(f"sed -i 's/^domain_underline=.*/domain_underline={domainUnderline}/' copy/start.sh")
	
    for item in domainsAndProxyPass:

        with open('copy/haproxy_https.cfg') as f:
            if "# ACL for "+item['domain'] in f.read():
                print("acl already exists in file")
            else:
                insertText ="\ \ \ \ # ACL for "+item['domain']+" and www."+item['domain']+"\\n\ \ \ \ acl ACL_"+item['domain']+" hdr(host) -i "+item['domain']+" www."+item['domain']+"\\n"
                afterText = "## ACL RULES"
                os.system("sed -i '/"+afterText+"/a "+insertText+"' copy/haproxy_https.cfg")
                
                insertText = "\ \ \ \ use_backend "+item['domain']+" if ACL_"+item['domain']+"\\n"
                afterText = "## BACKENDS"
                os.system("sed -i '/"+afterText+".*/a "+insertText+"' copy/haproxy_https.cfg")

        servers = ""
        for x in item["proxy_passes"]:
            servers +="        server             "+x+"    "+x+"    check maxconn 5000\n"

        appendText = """\nbackend """+item['domain']+"""
        mode http
        balance roundrobin
        #option httpchk HEAD /
        http-response set-header X-Frame-Options SAMEORIGIN
        http-response set-header X-XSS-Protection 1;mode=block
        http-response set-header X-Content-Type-Options nosniff
"""+servers

        with open('copy/haproxy_https.cfg') as f:
            if "\nbackend "+item['domain'] in f.read():
                print("backend already exists in file")
            else:
                with open("copy/haproxy_https.cfg", "a") as file_object: # Append
                    file_object.write(appendText)

def build_haproxy_container():
    os.system("docker build -t haproxy-img -f Dockerfile .")

def run_haproxy_container():
    os.system("docker run --rm --name haproxy \
    -v copy:/usr/local/etc/haproxy \
    -v tls:/etc/ssl/private \
    -it \
    -p 7777:7777 \
    -p 80:80 \
    -p 443:443 \
    -p 8899:8899 \
    haproxy-img")

configure_haproxy_container()
build_haproxy_container()
run_haproxy_container()
