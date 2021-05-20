DOCKER ?= docker
CURL ?= curl
PATCH ?= patch
UNSHARE ?= unshare -rm --pid --fork --mount-proc ./unshare.sh
TARGET ?= $(shell arch)

all: spack.develop.x

rootfs:
	unshare -rm /bin/sh -c 'rm -rf rootfs && mkdir rootfs && docker export $$(docker create centos:7) | tar --no-same-owner -xC rootfs'

rootfs-with-spack: rootfs
	$(UNSHARE) setup.sh

1_ccache:
	$(UNSHARE) spack -e /build/1_ccache external find --not-buildable cmake
	$(UNSHARE) spack -e /build/1_ccache install -j $$(nproc) -v
	$(UNSHARE) spack -e /build/1_ccache gc -y

2_compiler: 1_ccache
	$(UNSHARE) spack -e /build/2_compiler install -j $$(nproc) -v
	$(UNSHARE) spack -e /build/2_compiler gc -y

3_more_tools: 2_compiler
	$(UNSHARE) spack -e /build/3_more_tools install -j $$(nproc) -v
	$(UNSHARE) spack -e /build/3_more_tools gc -y

# A Go tool that allows you to rewrite symlinks, rpaths and runpaths
# and make all relative with respect to the root of the bootstrap folder.
4_environment: 3_more_tools
	$(UNSHARE) go build -o /build/4_environment/make_relative_env /build/4_environment/make_relative_env.go
	$(UNSHARE) go build -o /build/4_environment/prune /build/4_environment/prune.go
	$(UNSHARE) go build -o /build/4_environment/fix_file /build/4_environment/fix_file.go

5_runtime: 4_environment
	$(UNSHARE) spack -e /build/5_runtime install -j $$(nproc) -v
	$(UNSHARE) spack -e /build/5_runtime gc -y
	$(UNSHARE) make -C /build/5_runtime

6_spack: 5_runtime
	$(UNSHARE) spack -e /build/6_spack install -j $$(nproc) -v
	$(UNSHARE) spack -e /build/6_spack gc -y
	$(UNSHARE) bash -c 'cd /build/6_spack && find . -iname "*.a" | xargs rm -f'
	$(UNSHARE) bash -c 'cd /build/6_spack && find . -iname "__pycache__" | xargs rm -rf'
	$(UNSHARE) make_relative_env /build/6_spack .
	$(UNSHARE) prune /build/6_spack \
		$$(readlink build/6_spack/view)/share/aclocal \
		$$(readlink build/6_spack/view)/share/doc \
		$$(readlink build/6_spack/view)/share/info \
		$$(readlink build/6_spack/view)/share/locale \
		$$(readlink build/6_spack/view)/share/man \
		$$(readlink build/6_spack/view)/include \
		$$(readlink build/6_spack/view)/share/gettext/archive.dir.tar.gz \
		$$(readlink build/6_spack/view)/lib/python3.8/test
	$(UNSHARE) fix_file /build/6_spack/$$(readlink build/6_spack/view)/bin/file
	$(UNSHARE) bash -c 'cd /build/6_spack && ./spack python -m compileall spack_src/ install/ ._view/ 1> /dev/null || true'

# Download the latest version of spack as a tarball from GitHub
bump_spack: 6_spack
	$(UNSHARE) rm -rf /build/6_spack/spack_src
	$(UNSHARE) mkdir /build/6_spack/spack_src
	$(UNSHARE) bash -c 'curl -Ls "https://api.github.com/repos/spack/spack/tarball/develop" | tar --strip-components=1 -xz -C /build/6_spack/spack_src'
	$(UNSHARE) cp /build/6_spack/config.yaml /build/6_spack/spack_src/etc/spack/
	$(UNSHARE) bash -c 'cd /build/6_spack && find . -iname "__pycache__" | xargs rm -rf'
	$(UNSHARE) bash -c 'cd /build/6_spack && ./spack python -m compileall spack_src/ install/ ._view/ 1> /dev/null || true'

squashfs: 6_spack
	$(UNSHARE) rm -f /build/output/spack-$(TARGET).squashfs
	$(UNSHARE) mksquashfs /build/6_spack /build/output/spack-$(TARGET).squashfs -all-root

# Just rebuild spack.x file without rebuilding the runtime / bootstrap bits.
spack.x-quick: squashfs
	cp -f build/5_runtime/runtime-fuse2 build/output/runtime-$(TARGET)-fuse2
	cp -f build/5_runtime/runtime-fuse3 build/output/runtime-$(TARGET)-fuse3
	cat build/output/runtime-$(TARGET)-fuse2 build/output/spack-$(TARGET).squashfs > build/output/spack-$(TARGET).x
	cat build/output/runtime-$(TARGET)-fuse3 build/output/spack-$(TARGET).squashfs > build/output/spack-$(TARGET)-fuse3.x
	chmod +x build/output/spack-$(TARGET).x build/output/spack-$(TARGET)-fuse3.x

# Build spack.x but don't download a new version of spack itself from github
spack.x: 6_spack spack.x-quick

# Build spack.x with the latest spack develop version as a tarball from github
spack.develop.x: bump_spack spack.x

clean:
	rm -f build/spack.x build/spack.squashfs

clean-1_ccache:
	rm -rf build/1_ccache/install build/1_ccache/spack.lock build/1_ccache/.spack-env build/1_ccache/view build/1_ccache/._view

clean-2_compiler:
	rm -rf build/2_compiler/install build/2_compiler/spack.lock build/2_compiler/.spack-env build/2_compiler/view build/2_compiler/._view

clean-3_more_tools:
	rm -rf build/3_more_tools/install build/3_more_tools/spack.lock build/3_more_tools/.spack-env build/3_more_tools/view build/3_more_tools/._view

clean-4_environment:
	rm -rf build/4_environment/make_relative_env build/4_environment/prune build/4_environment/fix_file

clean-5_runtime:
	rm -rf build/5_runtime/install build/5_runtime/spack.lock build/5_runtime/.spack-env build/5_runtime/view build/5_runtime/._view

clean-6_spack:
	rm -rf build/6_spack/install build/6_spack/spack.lock build/6_spack/.spack-env build/6_spack/view build/6_spack/._view

cleanall: clean-1_ccache clean-2_compiler clean-3_more_tools clean-4_environment clean-5_runtime clean-6_spack 
