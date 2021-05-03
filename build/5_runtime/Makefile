CC            = gcc
CFLAGS        = -std=gnu99 -Os -D_FILE_OFFSET_BITS=64 -ffunction-sections -fdata-sections -Wl,--gc-sections
STRIP         = strip
MAGIC         = echo "8: 414902" | xxd -r -
MKDIR         = mkdir -p
COPY          = cp -f
LIBS          = -lsquashfuse -lsquashfuse_ll -lzstd -lpthread -ldl

all: runtime-fuse2 runtime-fuse3

.PHONY: all embed mrproper

# Prepare 1024 bytes of space for updateinformation
1024_blank_bytes:
	#printf '\0%.0s' {0..1023} > $@
	echo "03FF: 00" | xxd -r > $@
	stat $@

# Compile runtime
runtime-fuse2.o: runtime.c
	$(CC) -I$(CURDIR)/view/fuse2/include -I$(CURDIR)/view/fuse2/include/fuse -o runtime-fuse2.o -c $(CFLAGS) $^

runtime-fuse2: runtime-fuse2.o
	$(CC) $(CFLAGS) $^ -L$(CURDIR)/view/fuse2/lib -L$(CURDIR)/view/fuse2/lib64 $(LIBS) -lfuse -o runtime-fuse2

runtime-fuse3.o: runtime.c
	$(CC) -I$(CURDIR)/view/fuse3/include -I$(CURDIR)/view/fuse3/include/fuse3 -o runtime-fuse3.o -c $(CFLAGS) $^

runtime-fuse3: runtime-fuse3.o
	$(CC) $(CFLAGS) $^ -L$(CURDIR)/view/fuse3/lib -L$(CURDIR)/view/fuse3/lib64 $(LIBS) -lfuse3 -o runtime-fuse3

# Add .upd_info and .sha256_sig sections
embed: 1024_blank_bytes runtime-fuse2 runtime-fuse3
	objcopy --add-section .upd_info=1024_blank_bytes \
		--set-section-flags .upd_info=noload,readonly runtime-fuse2
	objcopy --add-section .upd_info=1024_blank_bytes \
		--set-section-flags .upd_info=noload,readonly runtime-fuse3
	stat runtime

clean:
	rm -f *.o 1024_blank_bytes runtime-fuse2 runtime-fuse3

