ARG		HAPROXY_BRANCH=devel
ARG             HAPROXY_MAJOR=3.1
ARG             HAPROXY_VERSION=3.1-dev0
ARG		ALPINE_VERSION=3.20

FROM		alpine:$ALPINE_VERSION AS build
ARG		HAPROXY_BRANCH
ARG		HAPROXY_MAJOR
ARG		HAPROXY_VERSION

RUN		{	apk --no-cache --upgrade --virtual build-dependencies add \
				libssl3 \
                                libcrypto3 \
				libc-dev \
				libffi-dev \
				openssl-dev \
				libxml2-dev \
				libxslt-dev \
				build-base \
				git \
				lua5.3-dev \
				zlib-dev \
				linux-headers \
				pcre2-dev \
				wget \
				perl \
				tar ; \
		}

WORKDIR	/usr/src

RUN		{	wget -q https://www.haproxy.org/download/$HAPROXY_MAJOR/src/$HAPROXY_BRANCH/haproxy-$HAPROXY_VERSION.tar.gz ; \
			tar xzf haproxy-$HAPROXY_VERSION.tar.gz ; \
			wget -q https://github.com/quictls/openssl/archive/refs/tags/openssl-3.1.5-quic1.tar.gz ; \
			tar xzf openssl-3.1.5-quic1.tar.gz ; \
		}

RUN		{	cd openssl-openssl-3.1.5-quic1 ; \
			mkdir -p /usr/local/quictls ; \
			./config --libdir=lib --prefix=/usr/local/quictls ; \
			make -j$(nproc) && make install_sw ; \
		}

RUN		{	cd haproxy-$HAPROXY_VERSION \ 
				&& make all -j$(nproc) TARGET=linux-libc USE_THREAD=1 USE_LIBCRYPT=1 \  
					USE_LUA=1 LUA_INC=/usr/include/lua5.3 LUA_LIB=/usr/lib/lua5.3 \
					USE_OPENSSL=1 SSL_INC=/usr/include SSL_LIB=/usr/lib SUBVERS="-$(uname -m)" \
					USE_PCRE2=1 USE_PCRE2_JIT=1 PCREDIR= USE_TFO=1 USE_PROMEX=1 USE_QUIC=1 IGNOREGIT=1 \
					SSL_INC=/usr/local/quictls/include SSL_LIB=/usr/local/quictls/lib LDFLAGS="-Wl,-rpath,/usr/local/quictls/lib" \
				&& make install ; \    
		}

RUN		{	apk del build-dependencies ; \
			rm -rf  /usr/local/share \
				/usr/local/lib/perl5 ; \
		}


FROM		alpine:$ALPINE_VERSION
ARG		HAPROXY_VERSION
ARG		BUILD_DATE
ARG		VCS_REF
MAINTAINER	Joram Knaack <joramk@gmail.com>
LABEL		org.label-schema.build-date=$BUILD_DATE \
		org.label-schema.vcs-url="https://github.com/joramk/haproxy.git" \
		org.label-schema.vcs-ref=$VCS_REF \
		org.label-schema.schema-version="1.0.0-rc1" \
		org.label-schema.name="HAProxy $HAPROXY_VERSION" \
		org.label-schema.description="HAProxy $HAPROXY_VERSION with quicTLS support" \
		org.label-schema.vendor="Joram Knaack" \
		org.label-schema.docker.cmd="docker run -d -p 80:80 -p 443:443 -v haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg joramk/haproxy"
ENV		container docker

COPY --from=build       /usr/local      /usr/local
COPY                    assets          /usr/local

RUN		{	apk --no-cache --upgrade add bash \
				libssl3 \
				libcrypto3 \
				openssl \
				libffi \
				python3 \
				lua5.3 \
				pcre2 \
				expat \
				incron \
				bash \
				zlib \
				certbot \
				socat \
				coreutils ; \
			mkdir -p /usr/local/etc/haproxy/letsencrypt /usr/local/etc/letsencrypt ; \
			ln -s /usr/local/etc/haproxy /etc/haproxy ; \
			ln -s /usr/local/etc/letsencrypt /etc/letsencrypt ; \
			rm -rf /var/cache/apk/* ; \
			chmod +x /usr/local/sbin/* ; \
		}

EXPOSE			80 443
HEALTHCHECK CMD	kill -0 1 || exit 1
STOPSIGNAL		SIGUSR1
VOLUME			[ "/etc/haproxy", "/etc/letsencrypt" ]
ENTRYPOINT		[ "docker-entrypoint.sh" ]
CMD			[ "haproxy", "-V", "-W", "-f", "/usr/local/etc/haproxy/haproxy.cfg" ]
