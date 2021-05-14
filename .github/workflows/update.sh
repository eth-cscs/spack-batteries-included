#!/bin/sh

set -xeu

ARCH=${ARCH:-$(arch)}

# Get the SHA of the latest spack release
SPACK_SHA=$(git ls-remote https://github.com/spack/spack.git | grep refs/heads/develop | head -n1 | awk '{ print $1}')
echo "Using spack SHA $SPACK_SHA"

# Download the latest stable spack.x release and the latest runtime.x
export BASE_VERSION="v1.6.3"
echo "Downloading spack-$ARCH.x from version $BASE_VERSION"

curl -LfSs -o "runtime-$ARCH-fuse2"  "https://github.com/haampie/spack-batteries-included/releases/download/$BASE_VERSION/runtime-$ARCH-fuse2"
curl -LfSs -o "runtime-$ARCH-fuse3"  "https://github.com/haampie/spack-batteries-included/releases/download/$BASE_VERSION/runtime-$ARCH-fuse3"
curl -LfSs -o "spack-$ARCH-old.x"    "https://github.com/haampie/spack-batteries-included/releases/download/$BASE_VERSION/spack-$ARCH.x"
curl -LSsf -o hack-wrapper.patch     "https://github.com/haampie/spack-batteries-included/raw/$BASE_VERSION/build/patches/hack-wrapper.patch"
curl -LSsf -o 20158.patch            "https://github.com/haampie/spack-batteries-included/raw/$BASE_VERSION/build/6_spack/20158.patch"
curl -LSsf -o config.yaml            "https://github.com/haampie/spack-batteries-included/raw/$BASE_VERSION/build/6_spack/config.yaml"

echo "9034e1ca5d8ac9b9cefac2630fc8b0cca0a5e7db07303b94723b60438c9c5a41 runtime-$ARCH-fuse2"  | sha256sum --check
echo "df16b30988b6aa95c8f6a8356dd5e593b74c7e831eed87395f58f20af9da8b41 runtime-$ARCH-fuse3"  | sha256sum --check
echo "dde176c26d5925f211cb42b15ec59a69543fbd53b501094ae4b089e470ad613a spack-$ARCH-old.x"    | sha256sum --check
echo "1c83a51b49cfbc4faf90b01ac944fedf47ad8a6528d45454503ded5bfa3ef97e hack-wrapper.patch"   | sha256sum --check
echo "4e0624b1c4527429f36aa5cff12266b4611f228731e3a01be1f06e075daf6571 20158.patch"          | sha256sum --check
echo "2783a5cb8d712bad1e1b6193d745cb56438f6a3e0b83638687df1f9e2b1cb206 config.yaml"          | sha256sum --check

chmod +x "spack-$ARCH-old.x"
export PATH="$PWD:$PATH"

# Extract them.
(
    mkdir -p "$ARCH" && cd "$ARCH" || exit 1

    echo "Extracting spack-$ARCH.x $BASE_VERSION"
    "spack-$ARCH-old.x" --squashfs-extract
    cd spack || exit 1
    rm -rf spack_src && mkdir spack_src

    echo "Download Spack $SPACK_SHA"
    curl -LfSs "https://api.github.com/repos/spack/spack/tarball/$SPACK_SHA" | tar --strip-components=1 -xz -C spack_src
    echo "$SPACK_SHA" > spack_sha

    # Apply the patch that allows you to drop specifying --log-file
    patch -p1 -d spack_src -i "$GITHUB_WORKSPACE/20158.patch"
    patch -p1 -d spack_src -i "$GITHUB_WORKSPACE/hack-wrapper.patch"
    cp "$GITHUB_WORKSPACE/config.yaml" spack_src/etc/spack/

    find . '(' -iname '*.pyc' -o -iname '__pycache__' ')' -print0 | xargs --null rm -rf
    NO_ENTRYPOINT='' "spack-$ARCH-old.x" python -m compileall spack_src/ install/ view/ ._view/ || true

    # Create a new squashfs file
    NO_ENTRYPOINT='' "spack-$ARCH-old.x" mksquashfs . "../../spack-$ARCH.squashfs" -all-root
) 

# Overwrite spack.x
cat "runtime-$ARCH-fuse2" "spack-$ARCH.squashfs" > "spack-$ARCH.x"
cat "runtime-$ARCH-fuse3" "spack-$ARCH.squashfs" > "spack-$ARCH-fuse3.x"