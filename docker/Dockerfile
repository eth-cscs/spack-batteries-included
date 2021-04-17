FROM centos:7

ENV PATH="$PATH:/opt/spack/bin"

RUN yum update -y \
 && yum install -y epel-release \
 && yum update -y \
 && yum --enablerepo epel groupinstall -y "Development Tools" \
 && yum --enablerepo epel install -y \
        curl \
        centos-release-scl \
        findutils \
        fuse \
        fuse-devel \
        git \
        gnupg2 \
        hostname \
        iproute \
        make \
        patch \
        python3 \
        tcl \
        unzip \
        which \
 && yum install -y devtoolset-9 \
 && rm -rf /var/cache/yum \
 && yum clean all

# Install spack
RUN mkdir -p /opt/spack && \
    curl -Ls "https://api.github.com/repos/spack/spack/tarball/develop" | tar --strip-components=1 -xz -C /opt/spack

# Install cmake as a system dependency for now
RUN curl -Ls "https://github.com/Kitware/CMake/releases/download/v3.20.1/cmake-3.20.1-linux-x86_64.tar.gz" | tar --strip-components=1 -xz -C /usr/local

# Apply horrible patch to drop -g and always use -Os
# this is not really necessary, but well, it gives us small binaries :)
RUN --mount=type=bind,source=patches,target=/patches \
    cd /opt/spack && \
    git apply /patches/curl.patch \
              /patches/gettext.patch \
              /patches/hack-wrapper.patch \
              /patches/tar.patch \
              /patches/ccache.patch \
              /patches/patchelf.patch

