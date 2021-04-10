CC            = gcc-9
CFLAGS        = -std=gnu99 -Wall -Os -D_FILE_OFFSET_BITS=64
STRIP         = strip
MAGIC         = echo "8: 414902" | xxd -r -
MKDIR         = mkdir -p
COPY          = cp -f
LIBS          = -lfuse -lsquashfuse -lsquashfuse_ll -lzstd -lpthread -ldl
INC           = -I/usr/include/fuse

all: runtime
.PHONY: all embed mrproper

# Prepare 1024 bytes of space for updateinformation
1024_blank_bytes:
	#printf '\0%.0s' {0..1023} > $@
	echo "03FF: 00" | xxd -r > $@
	stat $@

# Compile runtime but do not link
runtime.o: runtime.c
	$(CC) $(INC) -c $(CFLAGS) $^

# Add .upd_info and .sha256_sig sections
embed: 1024_blank_bytes runtime
	objcopy --add-section .upd_info=1024_blank_bytes \
		--set-section-flags .upd_info=noload,readonly runtime
	objcopy --add-section .sha256_sig=1024_blank_bytes \
		--set-section-flags .sha256_sig=noload,readonly runtime
	stat runtime

runtime: runtime.o
	$(CC) $(CFLAGS) $^ $(LIBS) -o runtime

install: runtime embed
	$(MKDIR) build
	$(COPY) runtime build
	$(STRIP) build/runtime
	# Insert AppImage magic bytes at offset 8
	# verify with : xxd -ps -s 0x8 -l 3 build/runtime
	$(MAGIC) build/runtime

clean:
	rm -f *.o 1024_blank_bytes runtime

