#!/bin/sh

set -xeu

ARCH=${ARCH:-$(arch)}

curl -fsS \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/eth-cscs/spack-batteries-included/releases > release_info.json

# Get the release url
release_id="$(< release_info.json jq -r '.[] | select(.tag_name=="develop") | .id')"

if [ -z "$release_id" ]; then
    echo "Couldn't get release id"
    exit 1
fi

echo "Using release id $release_id"

for name in "spack-$ARCH.x" "spack-$ARCH-fuse3.x" "spack-$ARCH.squashfs"
do
    # Get the asset url
    asset_url="$(< release_info.json jq -r --arg name "$name" '.[] | select(.tag_name=="develop") | .assets[] | select(.name==$name) | .url')"

    # Delete the asset
    if [ -n "$asset_url" ]; then
        echo "Deleting remote $name"
        curl -fsS \
             -X DELETE \
             -H "Authorization: Bearer $GITHUB_TOKEN" \
             -H "Accept: application/vnd.github.v3+json" \
             "$asset_url"
    fi

    # Upload a new one.
    echo "Uploading $name"
    curl -fsS \
         -X POST \
         -H "Authorization: Bearer $GITHUB_TOKEN" \
         -H "Content-Type: application/octet-stream" \
         --data-binary "@$name" \
         "https://uploads.github.com/repos/eth-cscs/spack-batteries-included/releases/$release_id/assets?name=$name)"
done