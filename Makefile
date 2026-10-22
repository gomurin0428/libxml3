PREFIX ?= /usr/local
ADA_BIN ?= $(HOME)/.local/share/ada/candidate-14/bin
export PATH := $(ADA_BIN):$(PATH)
CC ?= cc
CXX ?= c++
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Iinclude

.PHONY: build test-api compare check prove install clean test-sanitize

build:
	$(ADA_BIN)/gprbuild -p -P libxml3.gpr

tests/api-test: tests/api-test.c include/libxml3.h
	$(CC) $(CFLAGS) $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/differential-libxml3: tests/differential.c include/libxml/parser.h include/libxml/tree.h
	$(CC) $(CFLAGS) $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/differential-system: tests/differential.c
	$(CC) -std=c11 -Wall -Wextra $< $$(pkg-config --cflags --libs libxml-2.0) -o $@

tests/header-smoke.o: tests/header-smoke.cpp include/libxml3.h
	$(CXX) -std=c++17 -Wall -Wextra -Wpedantic -Werror -Iinclude -c $< -o $@

test-api: build tests/api-test tests/header-smoke.o
	LD_LIBRARY_PATH=lib ./tests/api-test

compare: build tests/differential-libxml3 tests/differential-system
	LD_LIBRARY_PATH=lib ./tests/differential-libxml3 > tests/differential-libxml3.out
	./tests/differential-system > tests/differential-system.out
	diff -u tests/differential-system.out tests/differential-libxml3.out

check: build tests/header-smoke.o
	@for symbol in xmlInitParser xmlCleanupParser xmlReadMemory xmlParseMemory \
		xmlReadDoc xmlParseDoc xmlDocGetRootElement xmlFreeDoc xmlNodeGetContent \
		xmlGetProp xmlHasProp xmlFirstElementChild xmlNextElementSibling \
		xmlChildElementCount xmlStrcmp xmlStrEqual xmlStrlen xmlFree xml3ReadMemory; do \
		nm -D --defined-only lib/libxml3.so | awk '{sub(/@@.*/, "", $$3); print $$3}' | grep -qx "$$symbol" || exit 1; \
	done

prove:
	$(ADA_BIN)/gnatprove -P proof.gpr --level=2 --report=all --checks-as-errors=on

install: build
	install -d $(DESTDIR)$(PREFIX)/lib $(DESTDIR)$(PREFIX)/include/libxml \
		$(DESTDIR)$(PREFIX)/lib/pkgconfig
	install -m 755 lib/libxml3.so $(DESTDIR)$(PREFIX)/lib/
	install -m 644 include/libxml/*.h $(DESTDIR)$(PREFIX)/include/libxml/
	install -m 644 include/libxml3.h $(DESTDIR)$(PREFIX)/include/
	sed 's|@prefix@|$(PREFIX)|g' libxml3.pc.in > \
		$(DESTDIR)$(PREFIX)/lib/pkgconfig/libxml3.pc

test-sanitize: build
	$(CC) $(CFLAGS) -fsanitize=address,undefined tests/api-test.c -Llib -lxml3 -o tests/api-test-sanitize
	ASAN_OPTIONS=detect_leaks=0 LD_LIBRARY_PATH=lib ./tests/api-test-sanitize

clean:
	rm -rf obj lib tests/api-test tests/header-smoke.o tests/differential-libxml3 \
		tests/differential-system tests/api-test-sanitize tests/*.out
