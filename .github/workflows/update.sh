#!/bin/sh

set -xeu

ARCH=${ARCH:-$(arch)}

# Get the SHA of the latest spack release
SPACK_SHA=$(git ls-remote https://github.com/spack/spack.git | grep refs/heads/develop | head -n1 | awk '{ print $1}')
echo "Using spack SHA $SPACK_SHA"

# Download the latest stable spack.x release and the latest runtime.x
export BASE_VERSION="v2.3.1"
echo "Downloading spack-$ARCH.x from version $BASE_VERSION"

curl -LfSs -o "runtime-$ARCH-fuse2"  "https://github.com/haampie/spack-batteries-included/releases/download/$BASE_VERSION/runtime-$ARCH-fuse2"
curl -LfSs -o "runtime-$ARCH-fuse3"  "https://github.com/haampie/spack-batteries-included/releases/download/$BASE_VERSION/runtime-$ARCH-fuse3"
curl -LfSs -o "spack-$ARCH-old.x"    "https://github.com/haampie/spack-batteries-included/releases/download/$BASE_VERSION/spack-$ARCH.x"

echo "aa269f3af2303925ec8752ed326200a91f65896a17ac80583bfe15d79c161470 runtime-$ARCH-fuse2"  | sha256sum --check
echo "aa89a9add9d3a44351df31d29953081fdf9bf1d41a479721f655faaf52851932 runtime-$ARCH-fuse3"  | sha256sum --check
echo "c7fff39dd7bbdeb9b795a956dd7ca4a76aae37d106c8a04744b3bc6b7690aae1 spack-$ARCH-old.x"    | sha256sum --check

chmod +x "spack-$ARCH-old.x"
export PATH="$PWD:$PATH"

# Extract them.
(
    mkdir -p "$ARCH" && cd "$ARCH" || exit 1

    echo "Extracting spack-$ARCH.x $BASE_VERSION"
    "spack-$ARCH-old.x" --squashfs-extract 1> /dev/null
    cd spack || exit 1
    rm -rf spack_src && mkdir spack_src

    echo "Download Spack $SPACK_SHA"
    curl -LfSs "https://api.github.com/repos/spack/spack/tarball/$SPACK_SHA" | tar --strip-components=1 -xz -C spack_src
    echo "$SPACK_SHA" > spack_sha

    patch -p1 -d spack_src -i "$GITHUB_WORKSPACE/build/patches/hack-wrapper.patch"
    cp "$GITHUB_WORKSPACE/build/6_spack/config.yaml" spack_src/etc/spack/

    find . '(' -iname '*.pyc' -o -iname '__pycache__' ')' -print0 | xargs --null rm -rf
    NO_ENTRYPOINT='' "spack-$ARCH-old.x" python -m compileall -q spack_src/ install/ view/ ._view/ || true

    # Create a new squashfs file
    NO_ENTRYPOINT='' "spack-$ARCH-old.x" mksquashfs . "../../spack-$ARCH.squashfs" -all-root
) 

# Overwrite spack.x
cat "runtime-$ARCH-fuse2" "spack-$ARCH.squashfs" > "spack-$ARCH.x"
cat "runtime-$ARCH-fuse3" "spack-$ARCH.squashfs" > "spack-$ARCH-fuse3.x"