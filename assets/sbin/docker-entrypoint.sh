#!/bin/bash
unset IFS
set -eo pipefail

# Compatibility setting
if [ ! -z "$TZ" ]; then
	TIMEZONE="$TZ"
fi

# Set the containers timezone
if [ ! -z "$TIMEZONE" ] && [ -e "/usr/share/zoneinfo/$TIMEZONE" ]; then
	ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
fi

# Reload HAProxy when config changes
if [ ! -z "$HAPROXY_INCROND" ]; then
	echo "/etc/haproxy IN_MODIFY,IN_NO_LOOP kill -HUP 1" >/etc/incron.d/haproxy
fi

# Reload HAProxy when certificate or OCSP information changes
if [ ! -z "$HAPROXY_LETSENCRYPT_INCROND" ]; then
	echo "/etc/haproxy/letsencrypt/*.pem IN_MODIFY,IN_NO_LOOP kill -HUP 1" >/etc/incron.d/letsencrypt
	echo "/etc/haproxy/letsencrypt/*.pem.ocsp IN_MODIFY,IN_NO_LOOP kill -HUP 1" >/etc/incron.d/letsencrypt-ocsp
fi

# Issue certificates for given domains if no certificate already exists
if [ ! -z "$HAPROXY_LETSENCRYPT" ]; then
	touch /.env-haproxy-letsencrypt
	domains=()
	for var in $(compgen -e); do
	        if [[ "$var" =~ LETSENCRYPT_DOMAIN_.* ]]; then
       		        domains+=( "${!var}" )
	        fi
	done
	for entry in "${domains[@]}"; do
       		array=(${entry//,/ })
		if [ ! -e "/etc/letsencrypt/live/${array[0]}/cert.pem" ]; then
	       		/usr/local/sbin/certbot-issue ${array[@]}
		fi
	done
fi

if [ ! -z "$HAPROXY_LETSENCRYPT_RENEW" ]; then
        touch /.env-haproxy-letsencrypt-renew
fi

if [ ! -z "$HAPROXY_LETSENCRYPT_OCSP" ]; then
	touch /.env-haproxy-letsencrypt-ocsp
	/usr/local/sbin/certbot-ocsp --fetch-only
fi

if [ ! -z "$HAPROXY_INCROND" ] || [ ! -z "$HAPROXY_LETSENCRYPT_INCROND" ]; then
        incrond
fi

if [ ! -z "$HAPROXY_LETSENCRYPT_RENEW" ] || [ ! -z "$HAPROXY_LETSENCRYPT_OCSP" ]; then
	crond -c /usr/local/etc/cron.d
fi

mkdir -p /etc/haproxy/letsencrypt

exec "$@"
