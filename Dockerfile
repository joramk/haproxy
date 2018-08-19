FROM		python:alpine3.8 AS build

RUN		{	apk --no-cache --update --virtual build-dependencies add \
				libffi-dev \
				libxml2-dev \
				libxslt-dev \
				openssl-dev \
				python-dev \
				build-base \
				git \
				lua5.3-dev \
				zlib-dev \
				linux-headers \
				perl \
				pcre-dev; \
			pip install certbot ; \
		}

WORKDIR		/usr/src

RUN		{	git clone https://github.com/openssl/openssl.git ; \
			git clone https://github.com/haproxy/haproxy.git ; \
		}

RUN		{	cd openssl \
			&& ./config no-async no-shared \
			&& make all \
			&& make install_sw ; \
		}

RUN             {	cd haproxy \ 
                        && make all TARGET=linux2628 \  
                                USE_LUA=1 LUA_INC=/usr/include/lua5.3 LUA_LIB=/usr/lib/lua5.3 \
                                USE_OPENSSL=1 SSL_INC=/usr/local/include SSL_LIB=/usr/local/lib \
                                USE_PCRE=1 PCREDIR= USE_ZLIB=1 \
                        && make install ; \    
                }

RUN		{	rm -rf  /usr/local/share \
				/usr/local/lib/perl5 \
				/usr/local/include/openssl ; \
		}


FROM 		alpine:3.8
MAINTAINER	Joram Knaack <joramk@gmail.com>

ENV 		HAPROXY_MAJOR       1.8
ENV 		container           docker

COPY --from=build	/usr/local 	/usr/local
COPY			assets		/usr/local

RUN		{	apk --no-cache --update add libffi lua5.3 pcre openssl expat incron bash zlib ; \
			mkdir -p /usr/local/etc/haproxy /etc/letsencrypt ; \
			touch /usr/local/etc/haproxy/haproxy.cfg ; \
			chmod +x /usr/local/sbin/* ; \
			rm -rf /var/cache/apk/* ; \
		}

EXPOSE			80 443
ENTRYPOINT		[ "/usr/local/sbin/docker-entrypoint.sh" ]
CMD 			[ "haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg" ]
