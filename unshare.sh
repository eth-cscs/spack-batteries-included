#!/bin/bash -e

# Make the system work nice
mount --rbind /dev rootfs/dev
mount --rbind /sys rootfs/sys
touch rootfs/proc/cpuinfo    && mount --bind /proc/cpuinfo rootfs/proc/cpuinfo
touch rootfs/etc/resolv.conf && mount --bind /etc/resolv.conf rootfs/etc/resolv.conf

# Mount some scripts we need
touch rootfs/bin/setup.sh    && mount -o ro,bind setup.sh rootfs/bin/setup.sh

# Mount a bunch of our workspace directories
mkdir -p rootfs/build        && mount --bind build rootfs/build

# Enter rootfs and execute something!
chroot rootfs env --ignore-environment - \
    HOME=/root \
    PATH=/build/5_runtime/view/bin:/build/4_environment:/build/3_more_tools/view/bin:/build/2_compiler/view/bin:/build/1_ccache/view/bin:/bin:/opt/spack/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin \
    CCACHE_DIR=/build/ccache \
    SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt \
    GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt \
    TARGET=$(arch) \
    "$@"