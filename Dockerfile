FROM		python:alpine3.8 AS build

ENV		HAPROXY_MAJOR	1.8
ENV		HAPROXY_VERSION	1.8.13
ENV		OPENSSL_VERSION	1.1.1-pre8

RUN		{	apk --no-cache --update --virtual build-dependencies add \
				libffi-dev \
				libxml2-dev \
				libxslt-dev \
				python-dev \
				build-base \
				git \
				lua5.3-dev \
				zlib-dev \
				linux-headers \
				perl \
				pcre-dev \
				wget \
				tar ; \
		}

WORKDIR		/usr/src

RUN		{	wget https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz ; \
			tar xvzf openssl-$OPENSSL_VERSION.tar.gz ; \
			wget https://www.haproxy.org/download/$HAPROXY_MAJOR/src/haproxy-$HAPROXY_VERSION.tar.gz ; \
			tar xvzf haproxy-$HAPROXY_VERSION.tar.gz ; \
		}

RUN		{	cd openssl-$OPENSSL_VERSION \
			&& ./config no-async enable-tls1_3 \
			&& make all \
			&& make install_sw ; \
		}

RUN             {	cd haproxy-$HAPROXY_VERSION \ 
                        && make all TARGET=linux2628 \  
                                USE_LUA=1 LUA_INC=/usr/include/lua5.3 LUA_LIB=/usr/lib/lua5.3 \
                                USE_OPENSSL=1 SSL_INC=/usr/local/include SSL_LIB=/usr/local/lib \
                                USE_PCRE=1 PCREDIR= USE_ZLIB=1 \
                        && make install ; \    
                }

RUN		{	pip install certbot ; \
			rm -rf  /usr/local/share \
				/usr/local/lib/perl5 \
				/usr/local/include/openssl ; \
		}


FROM 		alpine:3.8
MAINTAINER	Joram Knaack <joramk@gmail.com>

ENV 		container           docker

COPY --from=build	/usr/local 	/usr/local
COPY			assets		/usr/local

RUN		{	apk --no-cache --update add \
				libffi \
				lua5.3 \
				pcre \
				expat \
				incron \
				bash \
				zlib \
				socat \
				coreutils ; \
			apk update && apk upgrade ; \
			mkdir -p /usr/local/etc/haproxy/letsencrypt /usr/local/etc/letsencrypt ; \
			ln -s /usr/local/etc/haproxy /etc/haproxy ; \
			ln -s /usr/local/etc/letsencrypt /etc/letsencrypt ; \
			chmod +x /usr/local/sbin/* ; \
			rm -rf /var/cache/apk/* ; \
		}

EXPOSE			80 443
HEALTHCHECK CMD		kill -0 1 || exit 1
STOPSIGNAL		SIGUSR1
ENTRYPOINT		[ "docker-entrypoint.sh" ]
CMD 			[ "haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg" ]
