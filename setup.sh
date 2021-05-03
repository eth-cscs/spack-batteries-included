#!/bin/bash -e

yum install -y \
    bzip2 \
    ca-certificates \
    curl \
    file \
    gcc \
    gcc-c++ \
    gzip \
    make \
    patch \
    python3 \
    tar \
    unzip \
    which \
    xz

rm -rf /var/cache/yum
yum clean all

# Install spack
mkdir -p /opt/spack && curl -Ls "https://api.github.com/repos/spack/spack/tarball/develop" | tar --strip-components=1 -xz -C /opt/spack

# Install a relatively recent cmake
curl -Ls "https://github.com/Kitware/CMake/releases/download/v3.20.1/cmake-3.20.1-linux-$(arch).tar.gz" | tar --strip-components=1 -xz -C /usr/local

patch -p1 -d /opt/spack -i /build/patches/hack-wrapper.patch

patch -p1 -d /opt/spack -i /build/patches/autoconf.patch
patch -p1 -d /opt/spack -i /build/patches/curl.patch
patch -p1 -d /opt/spack -i /build/patches/flex.patch
patch -p1 -d /opt/spack -i /build/patches/gettext.patch
patch -p1 -d /opt/spack -i /build/patches/help2man.patch
patch -p1 -d /opt/spack -i /build/patches/squashfuse.patch
patch -p1 -d /opt/spack -i /build/patches/tar.patch
