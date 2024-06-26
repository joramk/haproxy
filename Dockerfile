ARG		ALPINE_VERSION=3.20

FROM		golang:alpine$ALPINE_VERSION AS build
ARG		HAPROXY_BRANCH
ARG		HAPROXY_MAJOR
ARG		HAPROXY_VERSION
ARG		TARGETPLATFORM
ARG		VCS_REF
ENV		DATAPLANE_VERSION 2.9.4
ENV		DATAPLANE_URL https://github.com/haproxytech/dataplaneapi.git
	
RUN	{	if [[ "$TARGETPLATFORM" == *arm\/v* ]]; then \
			PLATFORM_SPECIFIC="openssl-dev" ; \
		fi ; \
		mkdir -p /usr/local/sbin ; \
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
			perl \
			tar $PLATFORM_SPECIFIC ; \
	}

WORKDIR		/usr/src

RUN	{	if [[ "$TARGETPLATFORM" != *arm\/v* ]]; then \
			wget -q https://github.com/quictls/openssl/archive/refs/tags/openssl-3.1.5-quic1.tar.gz ; \
			tar xzf openssl-3.1.5-quic1.tar.gz ; \
			cd openssl-openssl-3.1.5-quic1 ; \
			./config no-tests --libdir=lib --prefix=/usr/local ; \
			make -j$(nproc) && make install_sw ; \
		fi ; \
	}

RUN	{	git clone "${DATAPLANE_URL}" dataplaneapi && \
		cd dataplaneapi && \
		git checkout "v${DATAPLANE_VERSION}" && \
		make build && cp build/dataplaneapi /usr/local/sbin/ ; \
	}

RUN	{	wget -q https://github.com/opentracing/opentracing-cpp/archive/refs/tags/v1.6.0.tar.gz ; \
		tar xzf v1.6.0.tar.gz ; \
		cd opentracing-cpp-1.6.0 ; \
		mkdir build && cd build ; \
		cmake -DCMAKE_INSTALL_PREFIX=/usr/local .. ; \
		make -j$(nproc) && make install ; \
		ln -s /usr/local/include/opentracing-c-wrapper-1-1-3 /usr/local/include/opentracing-c-wrapper ; \
	}

RUN	{	wget -q https://github.com/haproxytech/opentracing-c-wrapper/archive/refs/tags/v1.1.3.tar.gz ; \
		tar xzf v1.1.3.tar.gz ; \
		cd opentracing-c-wrapper-1.1.3 ; \
		./scripts/bootstrap ; \
		./configure --prefix=/usr/local --with-opentracing=/usr/local ; \
		make -j$(nproc) && make install ; \
	}

RUN	{	wget -q https://www.haproxy.org/download/$HAPROXY_MAJOR/src/$HAPROXY_BRANCH/haproxy-$HAPROXY_VERSION.tar.gz ; \
                tar xzf haproxy-$HAPROXY_VERSION.tar.gz ; \
		cd haproxy-$HAPROXY_VERSION ; \
		if [[ "$TARGETPLATFORM" == *arm\/v* ]]; then \
			PLATFORM_SPECIFIC="USE_QUIC_OPENSSL_COMPAT=1" ; \
		else \
			PLATFORM_SPECIFIC="SSL_INC=/usr/local/include SSL_LIB=/usr/local/lib LDFLAGS=\"-Wl,-rpath,/usr/local/lib\"" ; \
		fi ; \
		PKG_CONFIG_PATH=/usr/local/lib/pkgconfig make all -j$(nproc) TARGET=linux-musl USE_THREAD=1 USE_LIBCRYPT=1 \  
			USE_LUA=1 LUA_INC=/usr/include/lua5.4 LUA_LIB=/usr/lib/lua5.4 EXTRAVERSION="-$VCS_REF" \
			USE_OPENSSL=1 SUBVERS="/$TARGETPLATFORM" USE_OT=1 OT_USE_VARS=1 OT_LIB=/usr/local/lib OT_INC=/usr/local/include OT_RUNPATH=1 \
			USE_PCRE2=1 USE_PCRE2_JIT=1 PCREDIR= USE_TFO=1 USE_PROMEX=1 USE_QUIC=1 IGNOREGIT=1 \
			$PLATFORM_SPECIFIC \
		&& make install ; \    
	}

RUN	{	apk del build-dependencies ; \
		rm -rf  /usr/local/share /usr/local/go \
			/usr/local/lib/perl5 ; \
	}


FROM		alpine:$ALPINE_VERSION
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
		org.label-schema.description="HAProxy $HAPROXY_VERSION/$TARGETPLATFORM-$VCS_REF" \
		org.label-schema.vendor="Joram Knaack" \
		org.label-schema.build-date=$BUILD_DATE \
		org.label-schema.docker.cmd="docker run -d -p 80:80 -p 443:443 -v haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg joramk/haproxy"
ENV		container docker

COPY		--from=build	/usr/local	/usr/local
COPY				assets		/usr/local

RUN	{	if [[ "$TARGETPLATFORM" == *arm\/v* ]]; then \
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
		touch /usr/local/etc/haproxy/dataplaneapi.yml && \
		echo "/lib:/usr/local/lib:/usr/lib" > "/etc/ld-musl-$(uname -m).path" ; \
	}

RUN		haproxy -vv
EXPOSE		80 443
HEALTHCHECK CMD	kill -0 1 || exit 1
STOPSIGNAL	SIGUSR1
VOLUME		[ "/etc/haproxy", "/etc/letsencrypt" ]
ENTRYPOINT	[ "docker-entrypoint.sh" ]
CMD		[ "haproxy", "-V", "-W", "-f", "/usr/local/etc/haproxy/haproxy.cfg" ]
