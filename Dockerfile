FROM debian:jessie

ENV TERM xterm
ENV VARNISH_PORT 8080
ENV VARNISH_MEMORY 100m
ENV VARNISH_VERSION=4.1.0
ENV VARNISH_SHA256SUM=4a6ea08e30b62fbf25f884a65f0d8af42e9cc9d25bf70f45ae4417c4f1c99017

EXPOSE 8080

COPY start.sh /usr/local/bin/start
CMD ["start"]

RUN \
  chmod +x /usr/local/bin/start \
  && useradd -r -s /bin/false varnishd

# Install Varnish source build dependencies.
RUN apt-get update && apt-get install -y --no-install-recommends \
    automake \
    build-essential \
    ca-certificates \
    curl \
    libedit-dev \
    libjemalloc-dev \
    libncurses-dev \
    libpcre3-dev \
    libtool \
    pkg-config \
    python-docutils \
    libgeoip-dev \
    libmhash-dev \
    rsyslog \
    python-pip \
    python-dev \
    libmysqlclient-dev \
    libcurl4-gnutls-dev \
    libmicrohttpd-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
  
# Download GeoIP country code data file
RUN \
  curl -sfL http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz -o GeoIP.dat.gz && \
  gzip -d GeoIP.dat.gz && \
  mkdir -p /usr/share/GeoIP && \
  mv -f GeoIP.dat /usr/share/GeoIP/

RUN mkdir -p /usr/local/src && \
  cd /usr/local/src && \
  curl -sfLO https://repo.varnish-cache.org/source/varnish-$VARNISH_VERSION.tar.gz && \
  echo "${VARNISH_SHA256SUM} varnish-$VARNISH_VERSION.tar.gz" | sha256sum -c - && \
  tar -xzf varnish-$VARNISH_VERSION.tar.gz && \
  cd varnish-$VARNISH_VERSION && \
  ./autogen.sh && \
  ./configure && \
  make install && \
  rm ../varnish-$VARNISH_VERSION.tar.gz

# Install Querystring Varnish module
ENV QUERYSTRING_VERSION=0.3
RUN \
  cd /usr/local/src/ && \
  curl -sfL https://github.com/Dridi/libvmod-querystring/archive/v$QUERYSTRING_VERSION.tar.gz -o libvmod-querystring-$QUERYSTRING_VERSION.tar.gz && \
  tar -xzf libvmod-querystring-$QUERYSTRING_VERSION.tar.gz && \
  cd libvmod-querystring-$QUERYSTRING_VERSION && \
  ./autogen.sh && \
  ./configure VARNISHSRC=/usr/local/src/varnish-$VARNISH_VERSION && \
  make install && \
  rm -rf ../libvmod-querystring-$QUERYSTRING_VERSION*

RUN cp /usr/local/src/varnish-4.1.0/varnish.m4 /usr/share/aclocal/

# Install GeoIP Varnish module
ENV GEOIP_VERSION=master
RUN \
  cd /usr/local/src/ && \
  curl -sfL https://github.com/varnish/libvmod-geoip/archive/${GEOIP_VERSION}.tar.gz -o $GEOIP_VERSION.tar.gz && \
  tar -xzf $GEOIP_VERSION.tar.gz && \
  cd libvmod-geoip-$GEOIP_VERSION && \
  ./autogen.sh && \
  ./configure VARNISHSRC=/usr/local/src/varnish-$VARNISH_VERSION && \
  make install && \
  rm -rf ../libvmod-geoip* ../${GEOIP_VERSION}.tar.gz

# Install Cookie Varnish module
ENV COOKIE_VERSION=master
RUN \
  cd /usr/local/src/ && \
  curl -sfL https://github.com/varnish/libvmod-cookie/archive/${COOKIE_VERSION}.tar.gz -o $COOKIE_VERSION.tar.gz && \
  tar -xzf $COOKIE_VERSION.tar.gz && \
  cd libvmod-cookie-$COOKIE_VERSION && \
  ./autogen.sh && \
  ./configure VARNISHSRC=/usr/local/src/varnish-$VARNISH_VERSION && \
  make install && \
  rm -rf ../libvmod-cookie* ../${COOKIE_VERSION}.tar.gz

# Install Digest Varnish module
ENV DIGEST_VERSION=master
RUN \
  cd /usr/local/src/ && \
  curl -sfL https://github.com/varnish/libvmod-digest/archive/${DIGEST_VERSION}.tar.gz -o $DIGEST_VERSION.tar.gz && \
  tar -xzf $DIGEST_VERSION.tar.gz && \
  cd libvmod-digest-$DIGEST_VERSION && \
  ./autogen.sh && \
  ./configure VARNISHSRC=/usr/local/src/varnish-$VARNISH_VERSION && \
  make install && \
  rm -rf ../libvmod-digest* ../${DIGEST_VERSION}.tar.gz

# Install Language Varnish module
ENV LANGUAGE_VERSION=master
RUN \
  cd /usr/local/src/ && \
  curl -sfL https://github.com/dynamo-media/varnish-vmod-lang/archive/${LANGUAGE_VERSION}.tar.gz -o $LANGUAGE_VERSION.tar.gz && \
  tar -xzf $LANGUAGE_VERSION.tar.gz && \
  cd varnish-vmod-lang-$LANGUAGE_VERSION && \
  ./autogen.sh && \
  ./configure VARNISHSRC=/usr/local/src/varnish-$VARNISH_VERSION && \
  make install && \
  rm -rf ../varnish-vmod-lang* ../${LANGUAGE_VERSION}.tar.gz

# Install Header Varnish module
ENV HEADER_VERSION=4.1
RUN \
  cd /usr/local/src/ && \
  curl -sfL https://github.com/varnish/libvmod-header/archive/${HEADER_VERSION}.tar.gz -o $HEADER_VERSION.tar.gz && \
  tar -xzf $HEADER_VERSION.tar.gz && \
  cd libvmod-header-$HEADER_VERSION && \
  ./autogen.sh && \
  ./configure VARNISHSRC=/usr/local/src/varnish-$VARNISH_VERSION && \
  make install && \
  rm -rf ../libvmod-header* ../${HEADER_VERSION}.tar.gz

# Install urlcode Varnish module
ENV URLCODE_VERSION=master
RUN \
  cd /usr/local/src/ && \
  curl -sfL https://github.com/fastly/libvmod-urlcode/archive/${URLCODE_VERSION}.tar.gz -o $URLCODE_VERSION.tar.gz && \
  tar -xzf $URLCODE_VERSION.tar.gz && \
  cd libvmod-urlcode-$URLCODE_VERSION && \
  ./autogen.sh && \
  ./configure VARNISHSRC=/usr/local/src/varnish-$VARNISH_VERSION && \
  make install && \
  rm -rf ../libvmod-urlcode* ../${URLCODE_VERSION}.tar.gz

# Install varnish-agent
RUN \
  cd /tmp &&\
  curl -sfL https://github.com/varnish/vagent2/archive/master.tar.gz -o master.tar.gz && \
  tar -xzf master.tar.gz && \
  cd vagent2-master && \
  ./autogen.sh && \
  ./configure && \
  make CFLAGS="-Wall -Wextra -Werror" && \
  make install && \
  rm -rf ../vagent* ../master.tar.gz
