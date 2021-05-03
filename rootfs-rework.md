```
unshare -rm /bin/bash -c 'rm -rf rootfs && mkdir rootfs && docker export $(docker create centos:7) | tar --no-same-owner -xC rootfs'
unshare -rm ./unshare.sh
```

export PATH="/appimage-runtime/view/bin:/compiler/view/bin:/build-tools/.spack-env/view/bin/:/bin:/opt/spack/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin"
export CCACHE_DIR=/ccache
export SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt"
export TARGET=$(arch)
