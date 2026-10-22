PREFIX ?= /usr/local
ADA_BIN ?= $(HOME)/.local/share/ada/candidate-14/bin
export PATH := $(ADA_BIN):$(PATH)
CC ?= cc
CXX ?= c++
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Iinclude
PUBLIC_HEADERS := $(wildcard include/libxml/*.h) include/libxml3.h
REFERENCE := $(CURDIR)/build/reference
REFERENCE_VERSION := $(shell /usr/bin/python3 -c 'import json; print(json.load(open("compat/baseline.json"))["version_number"])')

.PHONY: build test-api test-namespace compare compare-system check prove install clean test-sanitize reference inventory check-inventory

build:
	$(ADA_BIN)/gprbuild -p -P libxml3.gpr

tests/api-test tests/differential-libxml3: | build

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

reference:
	/usr/bin/python3 eng/build_reference.py

inventory:
	/usr/bin/python3 eng/api_inventory.py

check-inventory:
	/usr/bin/python3 -m unittest discover -s tests -p 'test_api_inventory.py'
	/usr/bin/python3 eng/api_inventory.py --check

tests/differential-reference: tests/differential.c compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Werror -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_VERSION=$(REFERENCE_VERSION) \
		-DXML3_REFERENCE_VERSION_STRING='"$(REFERENCE_VERSION)"' $< \
		-L$(REFERENCE)/lib -Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so:
	@echo 'Pinned reference is missing. Run make reference first.' >&2
	@exit 1

compare: build tests/differential-libxml3 tests/differential-reference
	LD_LIBRARY_PATH=lib ./tests/differential-libxml3 > tests/differential-libxml3.out
	LD_LIBRARY_PATH=$(REFERENCE)/lib ./tests/differential-reference > tests/differential-reference.out
	diff -u tests/differential-reference.out tests/differential-libxml3.out

compare-system: build tests/differential-libxml3 tests/differential-system
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
		tests/differential-system tests/differential-reference tests/api-test-sanitize \
		tests/namespace-test tests/namespace-test-sanitize tests/*.out
