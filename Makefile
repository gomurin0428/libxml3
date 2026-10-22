PREFIX ?= /usr/local
ADA_BIN ?= $(HOME)/.local/share/ada/candidate-14/bin
export PATH := $(ADA_BIN):$(PATH)
CC ?= cc
CXX ?= c++
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Iinclude
PUBLIC_HEADERS := $(wildcard include/libxml/*.h) include/libxml3.h

.PHONY: build test-api test-namespace compare check prove install clean test-sanitize

build:
	$(ADA_BIN)/gprbuild -p -P libxml3.gpr

tests/api-test: tests/api-test.c $(PUBLIC_HEADERS)
	$(CC) $(CFLAGS) $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/namespace-test: tests/namespace-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/namespace-test-sanitize: tests/namespace-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -fsanitize=address,undefined $< -Llib -lxml3 -o $@

tests/differential-libxml3: tests/differential.c $(PUBLIC_HEADERS)
	$(CC) $(CFLAGS) $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/differential-system: tests/differential.c
	$(CC) -std=c11 -Wall -Wextra $< $$(pkg-config --cflags --libs libxml-2.0) -o $@

tests/header-smoke.o: tests/header-smoke.cpp $(PUBLIC_HEADERS)
	$(CXX) -std=c++17 -Wall -Wextra -Wpedantic -Werror -Iinclude -c $< -o $@

test-api: build tests/api-test tests/header-smoke.o tests/namespace-test
	LD_LIBRARY_PATH=lib ./tests/api-test
	LD_LIBRARY_PATH=lib ./tests/namespace-test

test-namespace: tests/namespace-test
	LD_LIBRARY_PATH=lib ./tests/namespace-test

compare: build tests/differential-libxml3 tests/differential-system
	LD_LIBRARY_PATH=lib ./tests/differential-libxml3 > tests/differential-libxml3.out
	./tests/differential-system > tests/differential-system.out
	diff -u tests/differential-system.out tests/differential-libxml3.out

check: build tests/header-smoke.o
	@for symbol in xmlInitParser xmlCleanupParser xmlReadMemory xmlParseMemory \
		xmlReadDoc xmlParseDoc xmlDocGetRootElement xmlFreeDoc xmlNodeGetContent \
		xmlGetProp xmlHasProp xmlSearchNs xmlSearchNsByHref xmlHasNsProp \
		xmlGetNsProp xmlGetNoNsProp xmlFirstElementChild xmlNextElementSibling \
		xmlChildElementCount xmlStrcmp xmlStrEqual xmlStrlen xmlFree xml3ReadMemory; do \
		nm -D --defined-only lib/libxml3.so | awk '{sub(/@@.*/, "", $$3); print $$3}' | grep -qx "$$symbol" || exit 1; \
	done

prove:
	$(ADA_BIN)/gnatprove -P proof.gpr --mode=all --prover=cvc5,z3 --timeout=10 -j4

install: build
	install -d $(DESTDIR)$(PREFIX)/lib $(DESTDIR)$(PREFIX)/include/libxml \
		$(DESTDIR)$(PREFIX)/lib/pkgconfig
	install -m 755 lib/libxml3.so $(DESTDIR)$(PREFIX)/lib/
	install -m 644 include/libxml/*.h $(DESTDIR)$(PREFIX)/include/libxml/
	install -m 644 include/libxml3.h $(DESTDIR)$(PREFIX)/include/
	sed 's|@prefix@|$(PREFIX)|g' libxml3.pc.in > \
		$(DESTDIR)$(PREFIX)/lib/pkgconfig/libxml3.pc

test-sanitize: build tests/namespace-test-sanitize
	$(CC) $(CFLAGS) -fsanitize=address,undefined tests/api-test.c -Llib -lxml3 -o tests/api-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/api-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/namespace-test-sanitize

clean:
	rm -rf obj lib tests/api-test tests/header-smoke.o tests/differential-libxml3 \
		tests/differential-system tests/api-test-sanitize tests/namespace-test \
		tests/namespace-test-sanitize tests/*.out
