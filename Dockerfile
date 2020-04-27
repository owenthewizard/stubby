# Base distro to build with
FROM alpine:3.11 as builder

# Versions to build
ARG YAML_VERSION
ARG GETDNS_VERSION

# User and group to run as
USER nobody:nogroup

# Self-explanatory
WORKDIR "/tmp"

# Build flags
ENV CPPFLAGS -D_FORTIFY_SOURCE=2
ENV CFLAGS -Ofast -DNDEBUG -fomit-frame-pointer -static-pie -Wl,--gc-sections  \
    -Wl,--hash-style=gnu -ffunction-sections -fdata-sections -s -pipe -fno-plt \
    -Wl,-z,relro -Wl,-z,now -fstack-protector-strong -fPIE -w

# CMake args
ENV CMAKE_ARGS -DBUILD_GETDNS_QUERY=OFF -DBUILD_GETDNS_SERVER_MON=OFF          \
    -DBUILD_LIBEV=OFF -DBUILD_LIBEVENT2=OFF -DBUILD_LIBUV=OFF                  \
    -DBUILD_STUBBY=ON -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=MinSizeRel        \
    -DENABLE_DSA=OFF -DENABLE_SHARED=OFF -DENABLE_STATIC=ON                    \
    -DENABLE_STUB_ONLY=ON -DENABLE_UNBOUND_EVENT_API=OFF                       \
    -DOPENSSL_CRYPTO_LIBRARY=/usr/lib/libcrypto.a                              \
    -DOPENSSL_SSL_LIBRARY=/usr/lib/libssl.a -DUSE_GNUTLS=OFF -DUSE_LIBIDN2=OFF

# Add the sources
ADD --chown=nobody:nogroup https://getdnsapi.net/releases/getdns-1-6-0/getdns-${GETDNS_VERSION}.tar.gz .
ADD --chown=nobody:nogroup https://getdnsapi.net/releases/getdns-1-6-0/getdns-${GETDNS_VERSION}.tar.gz.asc .
ADD --chown=nobody:nogroup https://pyyaml.org/download/libyaml/yaml-${YAML_VERSION}.tar.gz .
COPY --chown=nobody:nogroup SHA256SUMS .

# Install build deps
USER root:root
RUN apk --no-cache add cmake gcc gnupg libc-dev make openssl-dev openssl-libs-static
USER nobody:nogroup

# Verify signatures and hashes
RUN gpg --batch --homedir=/tmp --auto-key-retrieve --verify getdns-${GETDNS_VERSION}.tar.gz.asc getdns-${GETDNS_VERSION}.tar.gz
RUN sha256sum -c SHA256SUMS

# Extract sources, configure, compile, install
# All in one run because we `cd`
RUN \
    tar xzf yaml-${YAML_VERSION}.tar.gz && \
    cd yaml-${YAML_VERSION} && \
    ./configure --enable-static --disable-shared \
        CFLAGS="${CFLAGS}" CPPFLAGS="${CPPFLAGS}" && \
    make -j$(nproc)

USER root:root
RUN cd yaml-${YAML_VERSION} && make install
USER nobody:nogroup

# Likewise but for our other code
RUN \
    tar xzf getdns-${GETDNS_VERSION}.tar.gz && \
    cd getdns-${GETDNS_VERSION} && \
    cmake . ${CMAKE_ARGS} && \
    make -j$(nproc) stubby && \
    strip --strip-unneeded stubby/stubby


FROM busybox:1.31.1-musl

ARG GETDNS_VERSION

ENV HEALTHCHECK_DOMAIN cloudflare-dns.com
ENV LOG_LEVEL 5
ENV STUBBY_CONFIG /etc/stubby.yml
ENV STUBBY_ARGS ""

EXPOSE 5300

HEALTHCHECK --interval=1m --timeout=10s --start-period=5s --retries=2 \
    CMD nslookup ${HEALTHCHECK_DOMAIN} 127.0.0.1:5300

ENTRYPOINT stubby -v ${LOG_LEVEL} -C ${STUBBY_CONFIG} ${STUBBY_ARGS}

COPY --from=builder /etc/ssl/certs/* /certs/
COPY --from=builder /tmp/getdns-${GETDNS_VERSION}/stubby/stubby /usr/bin/

COPY stubby.yml /tmp/

# Remove comments, squeeze empty lines
# No cat -s in BusyBox :(
RUN grep -v '^#' /tmp/stubby.yml | uniq - /etc/stubby.yml

# Drop privileges
USER nobody:nogroup
