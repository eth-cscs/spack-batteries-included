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
