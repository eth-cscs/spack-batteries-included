FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive \
    PATH="$PATH:/opt/spack/bin"

# Install spack deps with recent compiler
RUN apt-get update -qq -y && \
    apt-get install --no-install-recommends -qq -y software-properties-common && \
    add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
    apt-get update -qq -y && \
    apt-get install -qqy  --no-install-recommends \
        autoconf \
        automake \
        bzip2 \
        ca-certificates \
        curl \
        file \
        fuse \
        g++-9 \
        gcc-9 \
        gfortran-9 \
        git \
        gnupg2 \
        iproute2 \
        libfuse-dev \
        libtool \
        lmod \
        locales \
        lua-posix \
        m4 \
        make \
        patch \
        patchelf \
        pkg-config \
        python3 \
        python3-pip \
        python3-setuptools \
        tar \
        tcl \
        unzip \
        xz-utils \
        && \
    rm -rf /var/lib/apt/lists/*

# Install spack
RUN mkdir -p /opt/spack && \
    curl -Ls "https://api.github.com/repos/spack/spack/tarball/develop" | tar --strip-components=1 -xz -C /opt/spack

# Apply horrible patch to drop -g and always use -Os
# this is not really necessary, but well, it gives us small binaries :)
RUN --mount=type=bind,source=hack-wrapper.patch,target=/root/hack-wrapper.patch \
    cd /opt/spack && \
    git apply /root/hack-wrapper.patch

# Install cmake as a system dependency for now
RUN curl -Ls "https://github.com/Kitware/CMake/releases/download/v3.20.0/cmake-3.20.0-linux-x86_64.tar.gz" | tar --strip-components=1 -xz -C /usr/local
