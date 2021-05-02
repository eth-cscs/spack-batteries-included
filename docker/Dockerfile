FROM centos:7

ENV PATH="$PATH:/opt/spack/bin"

ARG TARGET=x86_64

RUN yum update -y \
 && yum install -y epel-release \
 && yum update -y \
 && yum --enablerepo epel install -y \
        autoconf \
        automake \
        bison \
        bzip2 \
        ca-certificates \
        curl \
        file \
        findutils \
        flex \
        fuse \
        fuse-devel \
        git \
        gcc \
        gcc-c++ \
        libtool \
        make \
        patch \
        python3 \
        unzip \
        which \
 && rm -rf /var/cache/yum \
 && yum clean all

# Install spack
RUN mkdir -p /opt/spack && \
    curl -Ls "https://api.github.com/repos/spack/spack/tarball/develop" | tar --strip-components=1 -xz -C /opt/spack

# Install cmake as a system dependency for now
RUN curl -Ls "https://github.com/Kitware/CMake/releases/download/v3.20.1/cmake-3.20.1-linux-${TARGET}.tar.gz" | tar --strip-components=1 -xz -C /usr/local

# Adds a patch to drop -g and always use -O for small binaries :)
COPY ./patches /patches

RUN cd /opt/spack && \
    git apply /patches/ccache.patch \
              /patches/curl.patch \
              /patches/gettext.patch \
              /patches/hack-wrapper.patch \
              /patches/tar.patch
