export TARGET ?= x86_64
DOCKER ?= docker
CURL ?= curl
PATCH ?= patch
UNSHARE ?= unshare -rm ./unshare.sh

all: spack.develop.x

rootfs:
	unshare -rm /bin/sh -c 'rm -rf rootfs && mkdir rootfs && docker export $$(docker create centos:7) | tar --no-same-owner -xC rootfs'

rootfs-setup-spack: rootfs
	$(UNSHARE) setup.sh

1_ccache:
	$(UNSHARE) spack -e /build/1_ccache external find --not-buildable cmake
	$(UNSHARE) spack -e /build/1_ccache install -j $$(nproc) -v

2_compiler:
	$(UNSHARE) spack -e /build/2_compiler install -j $$(nproc) -v

# A Go tool that allows you to rewrite symlinks, rpaths and runpaths
# and make all relative with respect to the root of the bootstrap folder.
3_environment:
	$(UNSHARE) go build -gccgoflags "-s -w" -o /build/3_environment/make_relative_env /build/3_environment/make_relative_env.go
	$(UNSHARE) go build -gccgoflags "-s -w" -o /build/3_environment/prune /build/3_environment/prune.go

4_runtime:
	$(UNSHARE) spack -e /build/4_runtime external find --not-buildable python
	$(UNSHARE) spack -e /build/4_runtime install -j $$(nproc) -v
	$(UNSHARE) make -C /build/4_runtime CFLAGS=-I/build/4_runtime/view/include LDFLAGS=-L/build/4_runtime/view/lib

5_spack:
	$(UNSHARE) spack -e /build/5_spack install -j $$(nproc) -v

# Build spack.x with the latest spack develop version as a tarball from github
spack.develop.x: runtime bootstrap-install-spack-develop spack.x

# Build spack.x but don't download a new version of spack itself from github
spack.x: runtime.x bootstrap spack.x-quick

# Just rebuild spack.x file without rebuilding the runtime / bootstrap bits.
spack.x-quick: squashfs
	cat build/runtime build/spack.squashfs > build/spack.x
	chmod +x build/spack.x

squashfs: docker
	rm -f build/spack.squashfs
	$(UNSHARE) mksquashfs /build/5_spack /build/spack.squashfs -all-root

env-tools: compiler env-tools/make_relative_env.go env-tools/prune.go
	$(DOCKER) run $(DOCKER_FLAGS) -w /env-tools $(IMAGE_NAME) go build -gccgoflags "-s -w" -o make_relative_env make_relative_env.go
	$(DOCKER) run $(DOCKER_FLAGS) -w /env-tools $(IMAGE_NAME) go build -gccgoflags "-s -w" -o prune prune.go

# Create a runtime executable for AppImage (using zstd and dynamic linking against libfuse)
runtime: docker appimage-runtime/spack.yaml compiler
	

compiler: docker compiler/spack.yaml
	$(DOCKER) run $(DOCKER_FLAGS) -w /compiler $(IMAGE_NAME) spack --color=always -e . external find --not-buildable pkg-config cmake autoconf automake libtool m4
	$(DOCKER) run $(DOCKER_FLAGS) -w /compiler $(IMAGE_NAME) spack --color=always -e . install -v

runtime.x: runtime
	rm -f output/runtime.squashfs
	$(DOCKER) run $(DOCKER_FLAGS) -w /appimage-runtime $(IMAGE_NAME) \
		/env-tools/make_relative_env . view install
	$(DOCKER) run $(DOCKER_FLAGS) -w /output $(IMAGE_NAME) \
		/appimage-runtime/view/bin/mksquashfs /appimage-runtime runtime.squashfs -all-root
	cat appimage-runtime/runtime output/runtime.squashfs > output/runtime.x
	chmod +x output/runtime.x

# Install spack's own dependencies using the docker image, remove its build dependencies
# and remove static libaries too. Then try to make all paths relative using the Go script.
bootstrap: docker env-tools/make_relative_env env-tools/prune bootstrap-spack/spack.yaml runtime compiler
	$(DOCKER) run $(DOCKER_FLAGS) \
		-e SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt" \
		-e CCACHE_DIR=/ccache \
		-w /bootstrap-spack \
		$(IMAGE_NAME) \
		spack --color=always -e . install --fail-fast -v
	$(DOCKER) run $(DOCKER_FLAGS) -w /bootstrap-spack $(IMAGE_NAME) spack --color=always -e . gc -y
	$(DOCKER) run $(DOCKER_FLAGS) -w /bootstrap-spack $(IMAGE_NAME) bash -c 'find . -iname "*.a" | xargs rm -f'
	$(DOCKER) run $(DOCKER_FLAGS) -w /bootstrap-spack $(IMAGE_NAME) bash -c 'find . -iname "__pycache__" | xargs rm -rf'
	$(DOCKER) run $(DOCKER_FLAGS) -w /bootstrap-spack $(IMAGE_NAME) /env-tools/make_relative_env . view install
	$(DOCKER) run $(DOCKER_FLAGS) -w /bootstrap-spack $(IMAGE_NAME) \
		/env-tools/prune . \
			view/share/aclocal \
			view/share/doc \
			view/share/info \
			view/share/locale \
			view/share/man \
			view/include \
			view/share/gettext/archive.dir.tar.gz \
			view/lib/python3.8/test
	$(DOCKER) run $(DOCKER_FLAGS) -w /bootstrap-spack $(IMAGE_NAME) ./AppRun python -m compileall spack/ install/ 1> /dev/null || true

# Download the latest version of spack as a tarball from GitHub
# Notice, we apply the patch from https://github.com/spack/spack/pull/20158/
bootstrap-install-spack-develop: bootstrap
	rm -rf bootstrap-spack/spack
	mkdir bootstrap-spack/spack
	$(CURL) -Ls "https://api.github.com/repos/spack/spack/tarball/develop" | tar --strip-components=1 -xz -C bootstrap-spack/spack
	$(PATCH) -p1 -d bootstrap-spack/spack -i $(CURDIR)/bootstrap-spack/20158.patch
	cp bootstrap-spack/config.yaml bootstrap-spack/spack/etc/spack/
	$(DOCKER) run $(DOCKER_FLAGS) -w /bootstrap-spack $(IMAGE_NAME) bash -c 'find . -iname "__pycache__" | xargs rm -rf'
	$(DOCKER) run $(DOCKER_FLAGS) -w /bootstrap-spack $(IMAGE_NAME) ./AppRun python -m compileall spack/ 1> /dev/null || true



clean:
	rm -f build/spack.x build/spack.squashfs

clean-1_ccache:
	rm -rf build/1_ccache/install build/1_ccache/spack.lock build/1_ccache/.spack-env build/1_ccache/view

clean-2_compiler:
	rm -rf build/2_compiler/install build/2_compiler/spack.lock build/2_compiler/.spack-env build/2_compiler/view

clean-3_environment:
	rm -rf build/3_environment/make_relative_env build/3_environment/prune

clean-4_runtime:
	rm -rf build/4_runtime/install build/4_runtime/spack.lock build/4_runtime/.spack-env build/4_runtime/view

clean-5_spack:
	rm -rf build/5_spack/install build/5_spack/spack.lock build/5_spack/.spack-env build/5_spack/view
