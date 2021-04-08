# Spack with batteries included (linux/amd64)

It would be great if installing Spack was easy and had itself 0 dependencies*.

That's what this repository is about:

```
$ wget [todo: i have to upload the final binary]/spack.x && chmod +x spack.x
$ ./spack.x --version
```

\* Technically `libfuse2.so.2`, `libpthread.so.0`, `libc.so.6`, `libdl.so.2` are
  still required deps, but they should be installed on your system (hopefully).

## Building a docker image with an old glibc, libfuse, spack, patchelf

```console
$ cd docker
$ DOCKER_BUILDKIT=1 docker build --progress=plain -t spack-old-glibc .
```

## (optional) Building a tool to make rpaths, runpaths, symlinks relative
This is not containerized yet, but who needs that for go...
```console
$ cd env-tools
$ go build -ldflags "-s -w" make_relative_env.go
```
The binary is so small and static anyways, so it's included in git.

## Using this image to build all spack dependencies for x86_64
```console
$ docker run --rm -v $PWD/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack spack-old-glibc spack --color=always -e . install --fail-fast -v
$ docker run --rm -v $PWD/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack spack-old-glibc spack -e . gc -y
$ docker run --rm -v $PWD/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack spack-old-glibc bash -c 'find . -iname "*.a" | xargs rm'
$ docker run --rm -v $PWD/bootstrap-spack:/bootstrap-spack -v $PWD/env-tools:/env-tools -w /bootstrap-spack spack-old-glibc /env-tools/make_relative_env . view install
```

## "Install spack"
Just using the develop version here:
```console
$ curl -Ls "https://api.github.com/repos/spack/spack/tarball/develop" | tar --strip-components=1 -xz -C bootstrap-spack/spack
```

## Build the minimal AppImage runtime (with spack of course)
```console
$ docker run --rm -v $PWD/appimage-runtime:/appimage-runtime -w /appimage-runtime spack-old-glibc spack -e . external find --not-buildable libfuse pkg-config cmake autoconf automake libtool m4
$ docker run --rm -v $PWD/appimage-runtime:/appimage-runtime -w /appimage-runtime spack-old-glibc spack -e . concretize -f
$ docker run --rm -v $PWD/appimage-runtime:/appimage-runtime -w /appimage-runtime spack-old-glibc spack -e . install -v
$ docker run --rm -v $PWD/appimage-runtime:/appimage-runtime -w /appimage-runtime -e C_INCLUDE_PATH=/appimage-runtime/view/include -e LIBRARY_PATH=/appimage-runtime/view/lib spack-old-glibc make
```

## Creating the Spack Appimage with mksquashfs

```console
$ rm -f output/spack.squashfs output/spack.x
$ docker run --rm -v $PWD/appimage-runtime:/appimage-runtime -v $PWD/bootstrap-spack:/bootstrap-spack -v $PWD/output:/output -w /output spack-old-glibc /appimage-runtime/view/bin/mksquashfs /bootstrap-spack spack.squashfs
$ cat appimage-runtime/runtime output/spack.squashfs > output/spack.x
$ chmod +x output/spack.x
```
