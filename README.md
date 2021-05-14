[![Update spack develop version](https://github.com/haampie/spack-batteries-included/actions/workflows/update-spack.yaml/badge.svg?branch=master)](https://github.com/haampie/spack-batteries-included/actions/workflows/update-spack.yaml)

# 🔋 Spack with batteries included (linux/x86_64)

[Spack](https://github.com/spack/spack) is a build tool, and build tools should be trivial to install.

This repo offers a single file executable for Spack:

```console
$ wget -qO spack.x https://github.com/haampie/spack-batteries-included/releases/download/develop/spack-x86_64.x
$ chmod +x spack.x
$ ./spack.x install zstd +programs ~shared build_type=Release
```

## How does it work?
`spack.x` consists of a slightly hacked version of the AppImage runtime concatenated
with a big squashfs file which includes `binutils`, `bzip2`, `clingo`, `curl`, `file`,
`git`, `gmake`, `gzip`, `openssl`, `patch`, `patchelf`, `python`, `tar`, `unzip`, `xz`,
`zstd` and their dependencies.

When you run `./spack.x [args]` it will use `fusermount` to
mount this squashfs file in a temporary directory, and then execute the
entrypoint executable [AppRun](bootstrap-spack/AppRun).

The AppRun executable sets some environment variables like `PATH` and
`DL_LIBRARY_PATH` to the bin and lib folders of the squashfs file, and then it
executes `python3 path/to/copy/of/spack/bin/spack [args]`.

When the command is done running, the runtime unmounts the squashfs file again.

## What version of Spack is shipped?

The URL above gives you a rolling release of Spack's develop branch, which is updated
hourly. The exact commit SHA is included as a file and can be retrieved like this:

```console
$ ./spack.x --squashfs-extract spack_sha && cat spack/spack_sha
[prints the Spack commit sha]
```

## Supported platforms

- CentOS 7 and above
- Ubuntu 14.04 and above
- Debian 8 and above
- Fedora 20 and above
- OpenSUSE 13 and above
- Arch Linux
- Gentoo
- Windows Subsystem for Linux 2 with any of the above distro's.

The system dependencies are glibc 2.17 and above and optionally the fusermount
executable. If your system supports rootless containers it likely has fusermount
installed already!

## Differences from AppImage runtime
- it uses `zstd` for good compression;
- it dynamically links against libfuse instead of dlopen'ing it, this is
  to support the latest version of squashfuse without patching it everywhere.


## Caveats
**immutability** The squashfs mountpoint is a readonly folder, meaning that
spack can't write to spack/{var,opt} folders. spack.x is configured to use some
non-standard directories, see `spack.x config blame config` for details.

Note, spack.x applies [this patch](https://github.com/spack/spack/pull/20158/)
to ensure that log files are written to the `config:misc_cache` folder.

**openssl**: curl/git/openssl have to use system certificates. I'm not making any
assumptions on the system, but rather I'm just setting the `SSL_CERT_DIR`
and `GIT_SSL_CAPATH` variables to a list of common paths. This seems to work fine
on most systems.

If your certificates are in a non-standard location, point `SSL_CERT_DIR`
and `GIT_SSL_CAPATH` to it, or in some cases `SSL_CERT_FILE` and `GIT_SSL_CERT`.

## My system doesn't have fusermount, what now?

fusermount is used to mount a squashfs file included in the binary. If you don't
want that, you can just extract it:

```
$ ./spack.x --squashfs-extract
$ ./spack/spack
usage: spack [-hkV] [--color {always,never,auto}] COMMAND ...
```

but working with the extracted `spack` folder can come with a large
performance penalty, especially on Lustre filesystems in HPC centers.

## Can I run spack.x inside a container?

Yes, but please don't! Since fusermount is a setuid binary, you will need to
run a privileged container, which is never a good idea.

The recommended way to run spack.x inside a container is to just extract it:

```console
$ spack.x --squashfs-extract
```

If you insist on running spack.x in Docker, this is one way to do it:

```console
$ sudo docker run --privileged --device /dev/fuse -it -v $PWD/spack.x:/bin/spack.x ubuntu:18.04
# apt-get update && apt-get install fuse
# spack.x --version
```

## Running an executable shipped with spack.x directly

If you want to run an executable shipped with `spack.x` directly instead
of invoking spack (the default entrypoint), try this:

```console
$ NO_ENTRYPOINT= ./spack.x which python
/tmp/.mount_spack.h0zr1h/view/bin/python
```

--------------------------------------------------------------------------------

## How do I build spack.x myself?

Initially you may need docker to get a rootfs filesystem for centos 7.

Building goes like this:

```console
make rootfs-with-spack
make
```

You'll find the output in

```
build/output
```
