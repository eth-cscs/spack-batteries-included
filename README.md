[![Update spack develop version](https://github.com/haampie/spack-batteries-included/actions/workflows/update-spack.yaml/badge.svg?branch=master)](https://github.com/haampie/spack-batteries-included/actions/workflows/update-spack.yaml)

# 🔋 Spack with batteries included (linux/amd64)

Spack is a build tool, and build tools should be trivial to install.

This repo offers a single file executable for Spack:

```console
$ wget https://github.com/haampie/spack-batteries-included/releases/download/develop/spack.x
$ ./spack.x --version
```

## What version of Spack is shipped?

The URL above gives you a rolling release of Spack's develop branch, which is updated
hourly. The exact commit SHA is included as a file and can be retrieved like this:

```console
$ ./spack.x --appimage-extract spack_sha && cat squashfs-root/spack_sha
[prints the Spack commit sha]
```

## What are the actual dependencies?

Technically the system dependencies are the following shared libraries:
- `libc.so.6`
- `libcrypt.so.1`
- `libdl.so.2`
- `libfuse2.so.2`
- `libm.so.6`
- `libpthread.so.0`
- `libresolv.so.2`
- `librt.so.1`
- `libutil.so.1`

of which libfuse2 is the only non-standard dependency. If your system supports
rootless containers it likely has FUSE installed already! We can't statically
link libfuse because it [calls a setuid executable with a hard-coded path](https://github.com/libfuse/libfuse/blob/f4eaff6af0be41f48368213bd72161c2c092a50f/lib/mount.c#L117-L121).

Note: libfuse3 is supported too, but I have to polish the build script a bit.

TODO: The [AppRun](bootstrap-spack/AppRun) file should be replaced with a static executable, as it currently adds a dependency on `sh` and `readlink`.

## How does it work?
`spack.x` consists of a slightly hacked version of the AppImage runtime concatenated
with a big squashfs file which includes `binutils`, `bzip2`, `clingo`, `curl`, `file`,
`git`, `gmake`, `gzip`, `openssl`, `patch`, `python`, `tar`, `unzip`, `xz`, `zstd` and
their dependencies.

When you run `./spack.x [args]` it will use `fusermount` (through libfuse) to
mount this squashfs file in a temporary directory, and then execute the
entrypoint binary [AppRun](bootstrap-spack/AppRun).

The AppRun executable sets some environment variables like `PATH` and
`DL_LIBRARY_PATH` to the bin and lib folders of the squashfs file, and then it
executes `python3 path/to/copy/of/spack/bin/spack [args]`.

When the command is done running, the runtime unmounts the squashfs file again.

## Differences from AppImage runtime
- it uses `zstd` for good compression;
- it dynamically links against libfuse instead of dlopen'ing it, this is
  to support the latest version of squashfuse without patching it everywhere.


## Caveats
**immutability** The squashfs mountpoint is a readonly folder, meaning that
spack can't write to spack/{var,opt} folders. Therefore, you'll have to setup
some config to make spack not write to those paths. The easiest way is to just
use a single environment `spack.yaml` file, like this:

```yaml
spack:
  specs:
  - your-spec
  - and-another-spec
  view: ./view               # not required but useful sometimes
  config:
    concretizer: clingo      # clingo is included in spack.x
    module_roots:
      tcl: ./tcl_modules     # avoid writing to readonly mountpoint
      lmod: ./lmod_modules   # avoid writing to readonly mountpoint
    install_tree:
      root: ./install        # avoid writing to readonly mountpoint
```

And then you run `spack.x` like this:

```console
$ ls
spack.yaml spack.x
$ ./spack.x -e . install
```

Note, spack.x applies [this patch](https://github.com/spack/spack/pull/20158/)
to ensure that log files are written to the `config:misc_cache` folder.

**openssl**: curl/openssl have to use system certificates. I'm not making any
assumptions on the system, but rather I'm just setting the `SSL_CERT_DIR` env
variable to a list of common paths. This seems to work fine on most systems.

If your certificates are in a non-standard location, set `SSL_CERT_DIR`
yourself.

## My system doesn't have libfuse, what now?

libfuse is used to mount a squashfs file included in the binary. If you don't
want that, you can download the squashfs file and extract it.

```
$ wget https://github.com/haampie/spack-batteries-included/releases/download/develop/spack.squashfs
$ unsquashfs spack.squashfs
$ ./squashfs-root/AppRun 
usage: spack [-hkV] [--color {always,never,auto}] COMMAND ...
```

but working with the extracted `squashfs-root` folder can come with a large
performance penalty, especially on Lustre filesystems in HPC centers.

## Can I run spack.x inside a container?

Yes, but please don't! The reason is that spack.x needs to call fusermount
through libfuse. Since fusermount is a setuid binary, you will need to run a
privileged container, which is never a good idea.

The recommended way to run spack.x inside a container is to just extract it:

```console
$ ./spack.x --appimage-extract
$ docker run -it -v $PWD/squashfs-root:/spack ubuntu:18.04
# ln -s /spack/AppRun /bin/spack
# spack --version
```

If you insist on running spack.x in Docker, this is how to do it:

```console
$ sudo docker run --privileged --device /dev/fuse -it -v $PWD/spack.x:/bin/spack.x ubuntu:18.04
# apt-get update && apt-get install fuse
# ./spack.x --version
```

--------------------------------------------------------------------------------

## How do I build spack.x myself?

It's best to install rootless Docker on your system:

https://docs.docker.com/engine/security/rootless/

Optionally you need `curl` (to download the latest spack) and `go` (to build a
tool for making spack environments relocatable). Since the Go executable is small
and static, it's actually just included in the git repo, so you likely don't need
to recompile it.

To build the latest everything from scratch (docker image, appimage runtime,
spack dependencies), run:

```console
make
```

Afterwards you may want to use just

```console
make spack.x
```

so that make does not download a new Spack tarball each time.

Or even:

```console
make spack.x-quick
```

which does not rebuild the bootstrap and runtime environments, but just creates
the `spack.x` binary -- this is useful if you modified `bootstrap/spack` by
hand and just need to bundle it into `spack.x`.

The final products are:

```
output/spack.x            # the executable + archive
output/spack.squashfs     # just an archive, in case your system doesn't have libfuse.
```
