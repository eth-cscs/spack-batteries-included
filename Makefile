DOCKER ?= docker
CURL ?= curl
GO ?= go
IMAGE_NAME ?= spack-old-glibc
PATCH ?= patch

all: spack.develop.x

# Build spack.x with the latest spack develop version as a tarball from github
spack.develop.x: runtime bootstrap-install-spack-develop spack.x

# Build spack.x but don't download a new version of spack itself from github
spack.x: runtime bootstrap spack.x-quick

# Just rebuild spack.x file without rebuilding the runtime / bootstrap bits.
spack.x-quick: squashfs
	cat appimage-runtime/runtime output/spack.squashfs > output/spack.x
	chmod +x output/spack.x

# Build a docker image with an old version of glibc
docker: docker/Dockerfile
	DOCKER_BUILDKIT=1 $(DOCKER) build --progress=plain -t $(IMAGE_NAME) docker/

squashfs: docker
	rm -f output/spack.squashfs
	$(DOCKER) run --rm -v $(CURDIR)/appimage-runtime:/appimage-runtime \
					-v $(CURDIR)/bootstrap-spack:/bootstrap-spack \
					-v $(CURDIR)/output:/output \
					-w /output $(IMAGE_NAME) \
					/appimage-runtime/view/bin/mksquashfs \
					/bootstrap-spack spack.squashfs


# A Go tool that allows you to rewrite symlinks, rpaths and runpaths
# and make all relative with respect to the root of the bootstrap folder.
env-tools: env-tools/make_relative_env.go env-tools/prune.go
	$(GO) build -ldflags "-s -w" -o env-tools/make_relative_env env-tools/make_relative_env.go
	$(GO) build -ldflags "-s -w" -o env-tools/prune env-tools/prune.go

# Create a runtime executable for AppImage (using zstd and dynamic linking against libfuse)
runtime: docker appimage-runtime/spack.yaml
	$(DOCKER) run --rm -v $(CURDIR)/appimage-runtime:/appimage-runtime -w /appimage-runtime $(IMAGE_NAME) spack --color=always -e . external find --not-buildable libfuse pkg-config cmake autoconf automake libtool m4
	$(DOCKER) run --rm -v $(CURDIR)/appimage-runtime:/appimage-runtime -w /appimage-runtime $(IMAGE_NAME) spack --color=always -e . install -v
	$(DOCKER) run --rm -v $(CURDIR)/appimage-runtime:/appimage-runtime -w /appimage-runtime $(IMAGE_NAME) make clean
	$(DOCKER) run --rm -v $(CURDIR)/appimage-runtime:/appimage-runtime -w /appimage-runtime -e C_INCLUDE_PATH=/appimage-runtime/view/include -e LIBRARY_PATH=/appimage-runtime/view/lib $(IMAGE_NAME) make CC=/opt/rh/devtoolset-9/root/usr/bin/gcc

runtime.x: runtime
	rm -f output/runtime.squashfs
	$(DOCKER) run --rm -v $(CURDIR)/appimage-runtime:/appimage-runtime \
					-v $(CURDIR)/output:/output \
					-w /output $(IMAGE_NAME) \
					/appimage-runtime/view/bin/mksquashfs \
					/appimage-runtime runtime.squashfs
	cat appimage-runtime/runtime output/runtime.squashfs > output/runtime.x
	chmod +x output/runtime.x

# Install spack's own dependencies using the docker image, remove its build dependencies
# and remove static libaries too. Then try to make all paths relative using the Go script.
bootstrap: docker env-tools/make_relative_env env-tools/prune bootstrap-spack/spack.yaml runtime
	$(DOCKER) run --rm -e SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt" -v $(CURDIR)/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack $(IMAGE_NAME) spack --color=always -e . install --fail-fast -v
	$(DOCKER) run --rm -v $(CURDIR)/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack $(IMAGE_NAME) spack --color=always -e . gc -y
	$(DOCKER) run --rm -v $(CURDIR)/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack $(IMAGE_NAME) bash -c 'find . -iname "*.a" | xargs rm -f'
	$(DOCKER) run --rm -v $(CURDIR)/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack $(IMAGE_NAME) bash -c 'find . -iname "__pycache__" | xargs rm -rf'
	# we have strip built as part of bootstrap but who strips strip? it panics.
	$(DOCKER) run --rm -v $(CURDIR)/bootstrap-spack:/bootstrap-spack -v $(CURDIR)/env-tools:/env-tools -v $(CURDIR)/appimage-runtime:/appimage-runtime -w /bootstrap-spack $(IMAGE_NAME) /bin/bash -c 'export PATH="/appimage-runtime/view/bin/:$$PATH"; /env-tools/make_relative_env . view install'
	$(DOCKER) run --rm -v $(CURDIR)/bootstrap-spack:/bootstrap-spack -v $(CURDIR)/env-tools:/env-tools -v $(CURDIR)/appimage-runtime:/appimage-runtime -w /bootstrap-spack $(IMAGE_NAME) /env-tools/prune . view/share/aclocal view/share/doc view/share/info view/share/locale view/share/man view/include
	$(DOCKER) run --rm -v $(CURDIR)/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack $(IMAGE_NAME) ./AppRun python -m compileall spack/ 1> /dev/null || true

# Download the latest version of spack as a tarball from GitHub
# Notice, we apply the patch from https://github.com/spack/spack/pull/20158/
bootstrap-install-spack-develop: bootstrap
	rm -rf bootstrap-spack/spack
	mkdir bootstrap-spack/spack
	$(CURL) -Ls "https://api.github.com/repos/spack/spack/tarball/develop" | tar --strip-components=1 -xz -C bootstrap-spack/spack
	$(PATCH) -p1 -d bootstrap-spack/spack -i $(CURDIR)/bootstrap-spack/20158.patch
	cp bootstrap-spack/config.yaml bootstrap-spack/spack/etc/spack/
	$(DOCKER) run --rm -v $(CURDIR)/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack $(IMAGE_NAME) bash -c 'find . -iname "__pycache__" | xargs rm -rf'
	$(DOCKER) run --rm -v $(CURDIR)/bootstrap-spack:/bootstrap-spack -w /bootstrap-spack $(IMAGE_NAME) ./AppRun python -m compileall spack/ 1> /dev/null || true

clean:
	rm -f output/spack.x output/spack.squashfs

clean-bootstrap:
	rm -rf bootstrap-spack/install bootstrap-spack/.spack-env bootstrap-spack/view bootstrap-spack/spack.lock

clean-runtime:
	rm -rf appimage-runtime/runtime.o appimage-runtime/runtime appimage-runtime/spack.lock appimage-runtime/install appimage-runtime/.spack-env appimage-runtime/view

clean-docker:
	$(DOCKER) rmi $(IMAGE_NAME)
