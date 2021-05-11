v1.6.3
- Don't set the MAGIC environment variable so that libtool can use its
  hard-coded /usr/bin/file executable. `file` is still shipped, but the magic
  file is set using a wrapper script.

v1.6.2
- Add zstd executables and remove some unused shared libs.

v1.6.1
- Fix shell argument escaping; previously spack.x build-env spec -- /bin/bash -c 'echo hi' would drop the quotes when passing arguments to spack.

v1.6.0
- Add a flag `SPACK_OPTIMIZATION_FLAGS` which you can use to intercept `-O*` and `-g` flags and replace them by whatever you want.
  For instance if a package `pkg` defaults to `-O2 -g` flags, setting `SPACK_OPTIMIZATION_FLAGS="-Os" spack install pkg` will drop the `-g` and replace `-O2` with `-Os`.

v1.5.0
- No more docker (except maybe for creating the base rootfs) but just chroot

v1.4.0
- Include `mksquashfs` as an additional tool.
- Introduce the `NO_ENTRYPOINT` variable which allows you to run `NO_ENTRYPOINT= spack.x [command]` which will run `[command]` directly in the shell (after spack.x is mounted, and environment modifications are done)

v1.3.0
- Bootstrap GCC 10 with C, C++ and Go support in CentOS 7 to build spack dependencies

v1.2.3
- Smaller binaries with some gcc flags

v1.2.2
- Update the deployment script not to use 3rd-party github actions
- Make the final binary a bit smaller
- Add some caching for local builds of bootstrap binaries in spack.x

v1.2.1
- Do not ship the binutils assembler anymore, since it maybe result in incompatibilities when combined with system linker

v1.2.0
- Clingo concretizer is now enabled by default
- Use glibc 2.17 instead of 2.23 by switching the Docker base image to Centos 7
- Add a patched version of patchelf as it was broken
- Make the binary a bit smaller by deleting docs, locales, etc.

v1.1.0
- Add ccache by default

v1.0.5
- Just drop perl as a dependency entirely

v1.0.4
- Generate PERL5LIB paths

v1.0.3
- Generate `__pycache__` before packaging.
- Remove `ld` from binutils, which was included by accident

v1.0.2
- Add patchelf
- Add more variables: `GIT_SSL_CAPATH`, `GIT_TEMPLATE_DIR`, `TERMINFO`.
- Add a patch so that `--log-file` doesn't have to be set on the CLI
- Add Github Action to repack things.
- Improve the readme

v1.0.1
- Replace README.md steps with a `Makefile`.
- Add `file` and `binutils` as dependencies.
- Fix an issue where hardlinks in `git` and `binutils` broke relative RPATHs
  using `$ORIGIN`. The Go script now replaces all subsequent occurences of
  hardlinks with symlinks to the first occurence.
- WIP to make `spack.x` pass its own test.

v1.0.0
- Import of a minimal working example
