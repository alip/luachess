# LuaFics Makefile

# Load configuration
include config

LUA_PATH="src/?.lua;$(shell lua -e 'print(package.path)')"
LUA_CPATH="src/?.so;$(shell lua -e 'print(package.cpath)')"

all: src/ficsutils.so examples/itelnet/iutils.so

src/ficsutils.so: src/ficsutils.c
	$(CC) $(CFLAGS) $(LDFLAGS) $(LUALIBS) -o $@ $<

examples/itelnet/iutils.so: examples/itelnet/iutils.c
	$(CC) $(CFLAGS) $(LDFLAGS) $(LUALIBS) -o $@ $<

doc/index.html: luadoc/*.luadoc
	luadoc --nofiles -d doc luadoc/*.luadoc
	cp luadoc/logo.png doc/

doc: doc/index.html

test: all
	@LUA_PATH=$(LUA_PATH) LUA_CPATH=$(LUA_CPATH) lunit test/*.lua

clean:
	rm -f src/*.so src/*.o || true
	rm -fr doc || true

install: src/ficsutils.so
	$(INSTALL) src/ficsutils.so $(INSTALL_TOP_LIB)
	$(INSTALL) src/fics.lua $(INSTALL_TOP_SHARE)
	$(INSTALL) src/ficsparser.lua $(INSTALL_TOP_SHARE)

uninstall:
	rm -f $(INSTALL_TOP_LIB)/ficsutils.so || true
	rm -f $(INSTALL_TOP_SHARE)/fics.lua || true

upload-www: doc
	rsync --delete -avze ssh doc/* shell.nonlogic.org:htdocs/html/projects/luafics
	ssh shell.nonlogic.org chmod -R o+r htdocs/html/projects/luafics

.PHONY: all clean install uninstall doc
.DEFAULT: all

