v1.0.1
- Replace README.md steps with a `Makefile`.
- Add `file` and `binutils` as dependencies.
- Fix an issue where hardlinks in `git` and `binutils` broke relative RPATHs
  using `$ORIGIN`. The Go script now replaces all subsequent occurences of
  hardlinks with symlinks to the first occurence.
- WIP to make `spack.x` pass its own test.

v1.0.0
- Import of a minimal working example