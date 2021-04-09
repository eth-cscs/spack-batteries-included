# Spack with batteries included (linux/amd64)

It would be great if installing Spack was easy and had itself 0 dependencies¹.

That's what this repository is about:

```
$ wget https://github.com/haampie/spack-batteries-included/releases/download/v1.0.0/spack.x && chmod +x spack.x
$ ./spack.x --version
```

¹ Technically the system dependencies are the following shared libraries:
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
link libfuse because it calls a setuid executable with a hard-coded path.

## How does it work?
`spack.x` consists of a slightly hacked² version of the AppImage runtime concatenated
with a big squashfs file which includes `bzip2`, `clingo`, `curl`, `git`,
`gmake`, `gzip`, `openssl`, `patch`, `python`, `tar`, `unzip`, `xz`, `zstd` and
their dependencies.

² it uses zstd for good compression and dynamically links against libfuse
instead of dlopen'ing it.

When you run `./spack.x [args]` it will use fusermount (through libfuse) to mount
this squahfs file in a temporary directory, and then execute the entrypoint
binary [AppRun](bootstrap-spack/AppRun).

The AppRun executable sets some environment variables like PATH and
`DL_LIBRARY_PATH` to the bin and lib folders of the squashfs file, and then it
executes `python3 path/to/copy/of/spack/bin/spack [args]`.

When the command is done running, the runtime unmounts the squashfs file again.

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
    source_cache: ./cache    # avoid writing to readonly mountpoint
    misc_cache: ./misc_cache # avoid writing to readonly mountpoint
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
$ ./spack.x -e . install --log-file log.log
```
For some reason `--log-file` is the only thing you *need* to specify on the
command line to avoid that spack fails with readonly filesystem errors; it
can't be set in the `config:` section :(.

**openssl**: curl/openssl have to use system certificates. I'm not making any
assumptions on the system, but rather I'm just setting the `SSL_CERT_DIR` env
variable to a list of common paths. This seems to work fine on most systems.

If your certificates are in a non-standard location, set `SSL_CERT_DIR`
yourself.

## My system doesn't have libfuse, what now?

libfuse is just for self-mounting magic, if you don't want that, you can extract
the squashfs folder (assuming you have libfuse available at least somewhere):

```
$ spack.x --appimage-extract
$ ./squashfs-root/AppRun 
usage: spack [-hkV] [--color {always,never,auto}] COMMAND ...
```

but obviously this is not great on your average Lustre filesystem.

--------------------------------------------------------------------------------

## How do I build spack.x myself?

### Building a docker image with an old glibc, libfuse, spack, patchelf
Notice: I'm using rootless Docker for everything, this solves many file
ownership issues inside/outside containers!

```console
$ cd docker
$ DOCKER_BUILDKIT=1 docker build --progress=plain -t spack-old-glibc .
```

### (optional) Building a tool to make rpaths, runpaths, symlinks relative
This is not containerized yet, but who needs that for go...
```console
$ cd env-tools
$ go build -ldflags "-s -w" make_relative_env.go
```
The binary is so small and static anyways, so it's included in git.

### Using this image to build all spack dependencies for x86_64
```console
$ docker run --rm -e SSL_CERT_DIR=/etc/ssl/certs/ -v $PWD/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack spack-old-glibc spack --color=always -e . install --fail-fast -v
$ docker run --rm -v $PWD/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack spack-old-glibc spack -e . gc -y
$ docker run --rm -v $PWD/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack spack-old-glibc bash -c 'find . -iname "*.a" | xargs rm'
$ docker run --rm -v $PWD/bootstrap-spack:/bootstrap-spack -v $PWD/env-tools:/env-tools -w /bootstrap-spack spack-old-glibc /env-tools/make_relative_env . view install
```

### "Install spack"
Just using the develop version here:
```console
$ curl -Ls "https://api.github.com/repos/spack/spack/tarball/develop" | tar --strip-components=1 -xz -C bootstrap-spack/spack
```

### Build the minimal AppImage runtime (with spack of course)
```console
$ docker run --rm -v $PWD/appimage-runtime:/appimage-runtime -w /appimage-runtime spack-old-glibc spack -e . external find --not-buildable libfuse pkg-config cmake autoconf automake libtool m4
$ docker run --rm -v $PWD/appimage-runtime:/appimage-runtime -w /appimage-runtime spack-old-glibc spack -e . concretize -f
$ docker run --rm -v $PWD/appimage-runtime:/appimage-runtime -w /appimage-runtime spack-old-glibc spack -e . install -v
$ docker run --rm -v $PWD/appimage-runtime:/appimage-runtime -w /appimage-runtime -e C_INCLUDE_PATH=/appimage-runtime/view/include -e LIBRARY_PATH=/appimage-runtime/view/lib spack-old-glibc make
```

### Creating the Spack Appimage with mksquashfs

```console
$ rm -f output/spack.squashfs output/spack.x
$ docker run --rm -v $PWD/appimage-runtime:/appimage-runtime -v $PWD/bootstrap-spack:/bootstrap-spack -v $PWD/output:/output -w /output spack-old-glibc /appimage-runtime/view/bin/mksquashfs /bootstrap-spack spack.squashfs
$ cat appimage-runtime/runtime output/spack.squashfs > output/spack.x
$ chmod +x output/spack.x
```
