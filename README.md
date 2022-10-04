# haproxy-script
Script to install containerized haproxy with letsencrypt cert

## Prerequisites
- Debian 11 server with sudo and git
- A domain name configured with dns record type A to your WAN IP. For example:
  - [empty]  ->  WAN IP
  - www      ->  WAN IP
  - api      ->  WAN IP
 - (optional) CAA dns record yourdomain.xyz->letsencrypt.org
  
- On your router: port forwarding for http port 80 and https port 443 to your debian server.

## Installation

First change the variable values in haproxy-script.py \
Then run it:

```bash
cd haproxy-script
chmod u+x haproxy-script.py
./haproxy-script.py
```

## Additional info:
The haproxy container creates 2 volumes and copies configuration there. you can cleanup your complete docker env with:
```bash
if [ "$(docker ps -a -q)" = "" ]; then echo "no containers running"; else docker kill $(docker ps -a -q); fi && docker system prune --volumes -af
```

Access the volumes on the server like this:
```bash
sudo ls -l /var/lib/docker/volumes/copy/_data
sudo ls -l /var/lib/docker/volumes/tls/_data
```

Access the haproxy container like this:
```bash
docker exec -it haproxy /bin/bash
```

Run a command in the container like this:
```bash
docker exec -it haproxy ls -l
```

Check the ocsp response like this:
```bash
echo quit | openssl s_client -connect <your.domain>:443 -status
```
