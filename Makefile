# LuaFics Makefile

# Load configuration
include config

LUA_PATH="src/?.lua;$(shell lua -e 'print(package.path)')"
LUA_CPATH="src/?.so;$(shell lua -e 'print(package.cpath)')"

all: src/timeseal.so examples/itelnet/iutils.so

src/timeseal.so: src/timeseal.c
	$(CC) $(CFLAGS) $(LDFLAGS) $(LUALIBS) -o $@ $<

examples/itelnet/iutils.so: examples/itelnet/iutils.c
	$(CC) $(CFLAGS) $(LDFLAGS) $(LUALIBS) -o $@ $<

doc/index.html: luadoc/*.luadoc
	luadoc --nofiles -d doc luadoc/*.luadoc

doc: doc/index.html

test: all
	@LUA_PATH=$(LUA_PATH) LUA_CPATH=$(LUA_CPATH) lunit test/*.lua

clean:
	rm -f src/*.so src/*.o || true
	rm -fr doc || true

install: src/timeseal.so
	$(INSTALL) src/timeseal.so $(INSTALL_TOP_LIB)
	$(INSTALL) src/fics.lua $(INSTALL_TOP_SHARE)

uninstall:
	rm -f $(INSTALL_TOP_LIB)/timeseal.so || true
	rm -f $(INSTALL_TOP_SHARE)/fics.lua || true

upload-www: doc/index.html
	rsync -avze ssh doc/* shell.nonlogic.org:htdocs/html/projects/LuaFics

.phony: all clean install uninstall doc
.default: all

