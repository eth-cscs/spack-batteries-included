#!/bin/sh

set -xeu

ARCH=${ARCH:-$(arch)}

# Get the SHA of the latest spack release
SPACK_SHA=$(git ls-remote https://github.com/spack/spack.git | grep refs/heads/develop | head -n1 | awk '{ print $1}')
echo "Using spack SHA $SPACK_SHA"

# Download the latest stable spack.x release and the latest runtime.x
export BASE_VERSION="v2.3.2"
echo "Downloading spack-$ARCH.x from version $BASE_VERSION"

curl -LfSs -o "runtime-$ARCH-fuse2"  "https://github.com/eth-cscs/spack-batteries-included/releases/download/$BASE_VERSION/runtime-$ARCH-fuse2"
curl -LfSs -o "runtime-$ARCH-fuse3"  "https://github.com/eth-cscs/spack-batteries-included/releases/download/$BASE_VERSION/runtime-$ARCH-fuse3"
curl -LfSs -o "spack-$ARCH-old.x"    "https://github.com/eth-cscs/spack-batteries-included/releases/download/$BASE_VERSION/spack-$ARCH.x"

echo "3f3be2781919f3ed47a4400f41227f01581e2f34d1beb2cf6988bbdae6514e8d runtime-$ARCH-fuse2"  | sha256sum --check
echo "334d32b0fba99539e4112f420299a14ad938ba140eb8c4ef0c9fa7f53d180728 runtime-$ARCH-fuse3"  | sha256sum --check
echo "4e075729dba6c2c2b7383063c0a1342167cb8375c7c61880e860d451aa5d830b spack-$ARCH-old.x"    | sha256sum --check

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

    cp "$GITHUB_WORKSPACE/build/6_spack/config.yaml" "$GITHUB_WORKSPACE/build/6_spack/modules.yaml" spack_src/etc/spack/

    find . '(' -iname '*.pyc' -o -iname '__pycache__' ')' -print0 | xargs --null rm -rf
    NO_ENTRYPOINT='' "spack-$ARCH-old.x" python -m compileall -q spack_src/ install/ view/ ._view/ || true

    # Create a new squashfs file
    NO_ENTRYPOINT='' "spack-$ARCH-old.x" mksquashfs . "../../spack-$ARCH.squashfs" -all-root
) 

# Overwrite spack.x
cat "runtime-$ARCH-fuse2" "spack-$ARCH.squashfs" > "spack-$ARCH.x"
cat "runtime-$ARCH-fuse3" "spack-$ARCH.squashfs" > "spack-$ARCH-fuse3.x"