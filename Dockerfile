FROM	alpine:3.22 AS build
ARG		HAPROXY_BRANCH=devel
ARG		HAPROXY_MAJOR=3.5
ARG		HAPROXY_VERSION=3.5-dev0
ARG		TARGETPLATFORM
ARG		VCS_REF
ENV		DATAPLANE_URL=https://github.com/haproxytech/dataplaneapi.git

RUN		{	if [[ "$TARGETPLATFORM" == *arm\/v* ]]; then \
				PLATFORM_SPECIFIC="openssl-dev" ; \
			fi ; \
			apk --no-cache --upgrade --virtual build-dependencies add \
				automake \
				autoconf \
				make \
				cmake \
				gcc \
				g++ \
				binutils \
				libtool \
				pkgconf \
				gawk \
				libffi-dev \
				libxml2-dev \
				libxslt-dev \
				build-base \
				git \
				lua5.4-dev \
				zlib-dev \
				linux-headers \
				pcre2-dev \
				wget \
				perl openssl-dev \
				tar $PLATFORM_SPECIFIC ; \
		}

WORKDIR		/usr/src

RUN		{	wget -q https://www.haproxy.org/download/$HAPROXY_MAJOR/src/$HAPROXY_BRANCH/haproxy-$HAPROXY_VERSION.tar.gz ; \
                        tar xzf haproxy-$HAPROXY_VERSION.tar.gz ; \
			cd haproxy-$HAPROXY_VERSION ; \
			if [[ "$TARGETPLATFORM" == *arm\/v* ]]; then \
				PLATFORM_SPECIFIC="USE_QUIC_OPENSSL_COMPAT=1" ; \
			fi ; \
			PKG_CONFIG_PATH=/usr/local/lib/pkgconfig make all -j$(nproc) TARGET=linux-musl USE_THREAD=1 USE_LIBCRYPT=1 \  
				USE_LUA=1 LUA_INC=/usr/include/lua5.4 LUA_LIB=/usr/lib/lua5.4 SUBVERS="-$VCS_REF" \
				USE_OPENSSL=1 EXTRAVERSION="/${TARGETPLATFORM/linux/docker}" \
				USE_PCRE2=1 USE_PCRE2_JIT=1 PCREDIR= USE_TFO=1 USE_PROMEX=1 USE_QUIC=1 IGNOREGIT=1 \
				$PLATFORM_SPECIFIC \
			&& make install ; \    
		}

RUN		{	apk del build-dependencies ; \
			rm -rf  /usr/local/share \
				/usr/local/lib/perl5 ; \
		}


FROM		alpine:3.22
ARG		HAPROXY_VERSION
ARG		BUILD_DATE
ARG		VCS_REF
ARG		BUILD_DATE
MAINTAINER	Joram Knaack <joramk@gmail.com>
LABEL		org.label-schema.build-date=$BUILD_DATE \
		org.label-schema.vcs-url="https://github.com/joramk/haproxy.git" \
		org.label-schema.vcs-ref=$VCS_REF \
		org.label-schema.schema-version="1.0.0-rc1" \
		org.label-schema.name="HAProxy $HAPROXY_VERSION" \
		org.label-schema.description="HAProxy $HAPROXY_VERSION-$VCS_REF/$TARGETPLATFORM" \
		org.label-schema.vendor="Joram Knaack" \
		org.label-schema.build-date=$BUILD_DATE \
		org.label-schema.docker.cmd="docker run -d -p 80:80 -p 443:443 -v haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg joramk/haproxy"
ENV		container=docker

COPY		--from=build	/usr/local	/usr/local
COPY				assets		/usr/local

RUN		{	if [[ "$TARGETPLATFORM" == *arm\/v* ]]; then \
                                PLATFORM_SPECIFIC="openssl" ; \
                        fi ; \
			apk --no-cache --upgrade add \
				bash \
				ca-certificates \
				libffi \
				python3 \
				lua5.4 \
				pcre2 \
				expat \
				incron \
				bash \
				zlib \
				certbot \
				socat \
				coreutils $PLATFORM_SPECIFIC ; \
			mkdir -p /usr/local/etc/haproxy/letsencrypt /usr/local/etc/letsencrypt ; \
			ln -s /usr/local/etc/haproxy /etc/haproxy ; \
			ln -s /usr/local/etc/letsencrypt /etc/letsencrypt ; \
			rm -rf /var/cache/apk/* ; \
			chmod +x /usr/local/sbin/* ; \
			touch /usr/local/etc/haproxy/dataplaneapi.yml ; \
			echo "/lib:/usr/local/lib:/usr/lib" > "/etc/ld-musl-$(uname -m).path" ; \
		}

RUN		haproxy -vv
EXPOSE		80 443
HEALTHCHECK CMD	kill -0 1 || exit 1
STOPSIGNAL	SIGUSR1
VOLUME		[ "/etc/haproxy", "/etc/letsencrypt" ]
ENTRYPOINT	[ "docker-entrypoint.sh" ]
CMD		[ "haproxy", "-V", "-W", "-f", "/usr/local/etc/haproxy/haproxy.cfg" ]
