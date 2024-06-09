
# HAProxy Alpine Docker image
## Compiled features
- TLS 1.3 and QUIC support with OpenSSL 3.3
- Latest Alpine 3.20 base image
- Includes python3 and LUA 5.3 scripting
- Prometheus export enabled

## Supported tags and respective `Dockerfile` links

-	[`3.0-lts`, `3.0`, `latest`](https://github.com/joramk/haproxy/blob/3.0-lts/Dockerfile)
-	[`2.9`](https://github.com/joramk/haproxy/blob/2.9/Dockerfile)
-	[`2.8-lts`, `2.8`](https://github.com/joramk/haproxy/tree/2.8-lts)
-	[`2.6-lts`, `2.6`](https://github.com/joramk/haproxy/tree/2.6-lts)
-	[`2.4-lts`, `2.4`](https://github.com/joramk/haproxy/tree/2.4-lts)
-	[`2.2-lts`, `2.2`](https://github.com/joramk/haproxy/tree/2.2-lts)

## How to run

    docker run -d -p 80:80 -p 443:443 --restart=unless-stopped \
        -v /etc/docker/letsencrypt:/etc/letsencrypt \
        -v /etc/docker/haproxy:/usr/local/etc/haproxy \
        -e "TIMEZONE=Europe/Berlin" \
        -e "HAPROXY_LETSENCRYPT=1" \
        -e "HAPROXY_LETSENCRYPT_OCSP=1" \
        -e "HAPROXY_LETSENCRYPT_RENEW=1" \
        -e "HAPROXY_INCROND=1" \
    joramk/haproxy:latest 

## Working with certificates

### Issue new certificate
    docker exec -ti <container_name> certbot-issue example.tld yourmail@domain.com 

### Manually renew certificates
    docker exec -ti <container_name> certbot-renew --force-renewal

## Supported architectures
`amd64`, `arm32v6`, `arm32v7`, `arm64`

## Repository and bug reports
Please see https://github.com/joramk/haproxy/issues for filing issues.
