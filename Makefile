# LuaFics Makefile

# Load configuration
include config

src/timeseal.so: src/timeseal.c
	$(CC) $(CFLAGS) $(LDFLAGS) $(LUALINK) -o $@ $<

doc/index.html: luadoc/*.luadoc
	luadoc --nofiles -d doc luadoc/*.luadoc

all: src/timeseal.so
doc: doc/index.html

clean:
	rm -f src/*.so src/*.o || true
	rm -fr doc || true

install: src/timeseal.so
	$(INSTALL) src/timeseal.so $(INSTALL_TOP_LIB)
	$(INSTALL) src/fics.lua $(INSTALL_TOP_SHARE)

uninstall:
	rm -f $(INSTALL_TOP_LIB)/timeseal.so || true
	rm -f $(INSTALL_TOP_SHARE)/fics.lua || true

.phony: all clean install uninstall doc
.default: all

