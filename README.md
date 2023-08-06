# haproxy-script
Script to install containerized haproxy with letsencrypt cert

- TLSv1.3 only
- ocsp
- hsts
- caa policy
- ip blocking
- geo blocking
- rate limiting
- cache
- letsencrypt

https://www.ssllabs.com/ssltest/
<img src="100.png" width="100%" height="100%">

## Depenencies
- Debian 12
- git
- docker
- A domain name configured with dns record type A pointing to your WAN IP. For example:

  | Domain  | WAN IP |
  | ------------- | ------------- |
  | example.dev  | 142.250.203.110  |
  | sub1.example.dev  | 142.250.203.110  |
  | sub2.example.dev  | 142.250.203.110  |

 - (optional) CAA dns record pointing to letsencrypt.org. For example:

    | Domain  | letsencrypt domain |
    | ------------- | ------------- |
    | example.dev  | letsencrypt.org  |
    | sub1.example.dev  | letsencrypt.org  |
    | sub2.example.dev  | letsencrypt.org  |
  
- On your router: port forwarding for http port 80 and https port 443 and letsencrypt port 8443 to your debian server.

## Configure
- `cp usr/local/etc/certbot/conf/example-conf.yml usr/local/etc/certbot/conf/conf.yml`
- Edit usr/local/etc/certbot/conf/conf.yml
- `cp usr/local/etc/haproxy/example-haproxy.cfg usr/local/etc/haproxy/haproxy.cfg`
- Edit usr/local/etc/haproxy/haproxy.cfg

## Build and run

```bash
if [ -n "$(docker ps -q -f name=haproxy)" ]; then docker kill haproxy; fi && \
if [ -n "$(docker ps -a -q -f name=haproxy)" ]; then docker rm haproxy; fi && \
if [ -n "$(docker images -q haproxy-img)" ]; then docker rmi haproxy-img; fi && \
docker build --progress=plain -t haproxy-img -f Dockerfile . && \
docker run --rm --name haproxy \
-it \
-p 7777:7777 \
-p 80:80 \
-p 443:443 \
-p 8443:8443 \
haproxy-img
```

## Additional info:

Copy the certs, dh-key to local:
```bash
docker cp haproxy:/usr/local/etc/haproxy/dhparams.pem /home/$USER/git/haproxy-script/usr/local/etc/haproxy
docker cp haproxy:/usr/local/etc/haproxy/certs/. /home/$USER/git/haproxy-script/usr/local/etc/haproxy/certs
```

Access the haproxy container like this:
```bash
docker exec -it haproxy /bin/bash
```

Run a command in the container like this:
```bash
docker exec -it haproxy cat /usr/local/etc/haproxy/haproxy.cfg
```

Check the ocsp response like this:
```bash
echo quit | openssl s_client -connect <your.domain>:443 -status
```

Show haproxy info:
```bash
echo "show info" | socat stdio /usr/local/run/haproxy/admin.sock
```

Show haproxy cache:
```bash
echo "show cache" | socat stdio /usr/local/run/haproxy/admin.sock
```

Reload: #TODO: why this not working?
```bash
echo "reload" | socat stdio /usr/local/run/haproxy/admin.sock
```
