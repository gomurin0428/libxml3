PREFIX ?= /usr/local
ADA_BIN ?= $(HOME)/.local/share/ada/candidate-14/bin
export PATH := $(ADA_BIN):$(PATH)
CC ?= cc
CXX ?= c++
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Iinclude
PUBLIC_HEADERS := $(wildcard include/libxml/*.h) include/libxml3.h
REFERENCE := $(CURDIR)/build/reference
REFERENCE_VERSION := $(shell /usr/bin/python3 -c 'import json; print(json.load(open("compat/baseline.json"))["version_number"])')

.PHONY: build test-api test-namespace test-namespace-edit test-unicode test-encoding test-resources test-errors test-oom test-fuzz test-dom test-dom-core test-dom-bridge test-runtime test-dom-projection test-string-exception test-attributes test-serialization test-content-edit compare compare-system check prove install clean test-sanitize reference inventory check-inventory

build:
	$(ADA_BIN)/gprbuild -p -P libxml3.gpr -XLIBXML3_PROFILE=production

.PHONY: build-development test-development

build-development:
	$(ADA_BIN)/gprbuild -p -P libxml3.gpr -XLIBXML3_PROFILE=development

test-development: build-development tests/runtime-test tests/string-exception-test \
		tests/namespace-test tests/attribute-test tests/namespace-edit-test \
		tests/serialization-test-development tests/content-edit-test-development
	LD_LIBRARY_PATH=lib/development ./tests/runtime-test
	LD_LIBRARY_PATH=lib/development ./tests/string-exception-test
	LD_LIBRARY_PATH=lib/development ./tests/namespace-test
	LD_LIBRARY_PATH=lib/development ./tests/attribute-test
	LD_LIBRARY_PATH=lib/development ./tests/namespace-edit-test
	LD_LIBRARY_PATH=lib/development ./tests/serialization-test-development
	LD_LIBRARY_PATH=lib/development ./tests/content-edit-test-development

tests/dom-core-test: tests/dom_core_test.adb tests/dom_core_test.gpr \
		src/xml3_dom.ads src/xml3_dom.adb src/xml3_dom_allocation.ads src/xml3_dom_allocation.adb
	$(ADA_BIN)/gprbuild -p -P tests/dom_core_test.gpr -o dom-core-test

test-dom-core: tests/dom-core-test
	./tests/dom-core-test

tests/dom-bridge-test: tests/dom_bridge_test.adb tests/dom_bridge_test.gpr tests/dom_bridge_facade.c \
		src/xml3_dom_store.ads src/xml3_dom_store.adb \
		src/xml3_dom_store-queries.ads src/xml3_dom_store-queries.adb \
		src/xml3_dom_store-properties.ads src/xml3_dom_store-properties.adb \
		src/xml3_dom_store-documents.ads src/xml3_dom_store-documents.adb \
		src/xml3_dom-materialize.ads src/xml3_dom-materialize.adb \
		src/xml3_dom-import.ads src/xml3_dom-import.adb \
		src/xml3_dom.ads src/xml3_dom.adb src/xml3_dom_allocation.ads src/xml3_dom_allocation.adb \
		src/xml3_native_memory.ads src/xml3_native_memory.adb src/xml3_dom_bridge.ads src/xml3_dom_bridge.adb \
		src/xml3_dom_constructors.ads src/xml3_dom_constructors.adb src/xml3_namespaces.ads src/xml3_namespaces.adb \
		src/xml3_text.ads src/xml3_text.adb src/xml3_parser.ads src/xml3_parser.adb \
		src/xml3_encoding.ads src/xml3_encoding.adb
	$(ADA_BIN)/gprbuild -p -P tests/dom_bridge_test.gpr -o dom-bridge-test

test-dom-bridge: tests/dom-bridge-test
	./tests/dom-bridge-test

tests/api-test tests/differential-libxml3: | build

tests/api-test: tests/api-test.c $(PUBLIC_HEADERS)
	$(CC) $(CFLAGS) $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/namespace-test: tests/namespace-test.c $(PUBLIC_HEADERS) Makefile | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,--enable-new-dtags,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/namespace-test-sanitize: tests/namespace-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -fsanitize=address,undefined $< -Llib -lxml3 -o $@

tests/namespace-edit-test: tests/namespace-edit-test.c $(PUBLIC_HEADERS) Makefile | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,--enable-new-dtags,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/namespace-edit-test-reference: tests/namespace-edit-test.c compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Wpedantic -Werror -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_TEST \
		-DXML3_REFERENCE_VERSION_STRING='"$(REFERENCE_VERSION)"' $< -L$(REFERENCE)/lib \
		-Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/namespace-edit-test-sanitize: tests/namespace-edit-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -fsanitize=address,undefined $< -Llib -lxml3 -o $@

tests/serialization-test: tests/serialization-test.c tests/oom-shim.c \
		$(PUBLIC_HEADERS) Makefile | build
	$(CC) $(CFLAGS) -Werror -pthread $< tests/oom-shim.c -Llib \
		-Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/serialization-test-reference: tests/serialization-test.c \
		compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h \
		build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Wpedantic -Werror -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_TEST $< -L$(REFERENCE)/lib \
		-Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/serialization-test-development: tests/serialization-test.c \
		$(PUBLIC_HEADERS) Makefile | build-development
	$(CC) $(CFLAGS) -Werror -DXML3_DEVELOPMENT_TEST $< \
		-Llib/development -Wl,-rpath,'$$ORIGIN/../lib/development' -lxml3 -o $@

tests/content-edit-test: tests/content-edit-test.c $(PUBLIC_HEADERS) Makefile | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/content-edit-test-reference: tests/content-edit-test.c compat/baseline.json \
		build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Wpedantic -Werror -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_TEST $< -L$(REFERENCE)/lib \
		-Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/content-edit-test-development: tests/content-edit-test.c \
		$(PUBLIC_HEADERS) Makefile | build-development
	$(CC) $(CFLAGS) -Werror $< -Llib/development \
		-Wl,-rpath,'$$ORIGIN/../lib/development' -lxml3 -o $@

tests/content-edit-test-sanitize: tests/content-edit-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -fsanitize=address,undefined $< -Llib -lxml3 -o $@

test-content-edit: tests/content-edit-test tests/content-edit-test-reference
	LD_LIBRARY_PATH=lib ./tests/content-edit-test
	LD_LIBRARY_PATH=$(REFERENCE)/lib ./tests/content-edit-test-reference

test-serialization: tests/serialization-test tests/serialization-test-reference
	LD_LIBRARY_PATH=lib ./tests/serialization-test
	LD_LIBRARY_PATH=$(REFERENCE)/lib ./tests/serialization-test-reference

tests/differential-libxml3: tests/differential.c $(PUBLIC_HEADERS)
	$(CC) $(CFLAGS) $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/differential-system: tests/differential.c
	$(CC) -std=c11 -Wall -Wextra $< $$(pkg-config --cflags --libs libxml-2.0) -o $@

tests/header-smoke.o: tests/header-smoke.cpp $(PUBLIC_HEADERS)
	$(CXX) -std=c++17 -Wall -Wextra -Wpedantic -Werror -Iinclude -c $< -o $@

tests/unicode-test: tests/unicode-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/unicode-test-reference: tests/unicode-test.c compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Werror -I$(REFERENCE)/include/libxml2 -DXML3_REFERENCE_VERSION=$(REFERENCE_VERSION) -DXML3_REFERENCE_VERSION_STRING='"$(REFERENCE_VERSION)"' $< -L$(REFERENCE)/lib -Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/resource-test: tests/resource-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/resource-test-reference: tests/resource-test.c compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Werror -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_VERSION=$(REFERENCE_VERSION) \
		-DXML3_REFERENCE_VERSION_STRING='"$(REFERENCE_VERSION)"' $< \
		-L$(REFERENCE)/lib -Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/resource-test-sanitize: tests/resource-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -fsanitize=address,undefined $< -Llib -lxml3 -o $@

tests/error-test: tests/error-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -pthread $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/error-test-reference: tests/error-test.c compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Werror -pthread -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_TEST \
		-DXML3_REFERENCE_VERSION_STRING='"$(REFERENCE_VERSION)"' $< -L$(REFERENCE)/lib \
		-Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/error-snapshot: tests/error-snapshot.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/error-snapshot-reference: tests/error-snapshot.c compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Werror -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_TEST \
		-DXML3_REFERENCE_VERSION_STRING='"$(REFERENCE_VERSION)"' $< -L$(REFERENCE)/lib \
		-Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/encoding-snapshot: tests/encoding-snapshot.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/encoding-snapshot-reference: tests/encoding-snapshot.c compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Wpedantic -Werror -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_TEST \
		-DXML3_REFERENCE_VERSION_STRING='"$(REFERENCE_VERSION)"' $< -L$(REFERENCE)/lib \
		-Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/encoding-test: tests/encoding-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/encoding-test-reference: tests/encoding-test.c compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Wpedantic -Werror -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_TEST \
		-DXML3_REFERENCE_VERSION_STRING='"$(REFERENCE_VERSION)"' $< -L$(REFERENCE)/lib \
		-Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/encoding-unit-test: tests/encoding_test.adb tests/encoding_test.gpr \
		src/xml3_text.ads src/xml3_text.adb src/xml3_encoding.ads src/xml3_encoding.adb
	$(ADA_BIN)/gprbuild -p -P tests/encoding_test.gpr -o encoding-unit-test

tests/encoding-resource-test: tests/encoding-resource-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/encoding-resource-test-sanitize: tests/encoding-resource-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -fsanitize=address,undefined $< -Llib -lxml3 -o $@

tests/encoding-resource-test-reference: tests/encoding-resource-test.c compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Wpedantic -Werror -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_TEST \
		-DXML3_REFERENCE_VERSION_STRING='"$(REFERENCE_VERSION)"' $< -L$(REFERENCE)/lib \
		-Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/encoding-test-sanitize: tests/encoding-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -fsanitize=address,undefined $< -Llib -lxml3 -o $@

tests/dom-test: tests/dom-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/dom-test-reference: tests/dom-test.c compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Wpedantic -Werror -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_TEST \
		-DXML3_REFERENCE_VERSION_STRING='"$(REFERENCE_VERSION)"' $< -L$(REFERENCE)/lib \
		-Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/dom-test-sanitize: tests/dom-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -fsanitize=address,undefined $< -Llib -lxml3 -o $@

tests/attribute-test: tests/attribute-test.c $(PUBLIC_HEADERS) Makefile | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,--enable-new-dtags,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/attribute-test-reference: tests/attribute-test.c compat/baseline.json build/reference/include/libxml2/libxml/xmlversion.h build/reference/lib/libxml2.so
	$(CC) -std=c11 -Wall -Wextra -Wpedantic -Werror -I$(REFERENCE)/include/libxml2 \
		-DXML3_REFERENCE_TEST \
		-DXML3_REFERENCE_VERSION_STRING='"$(REFERENCE_VERSION)"' $< -L$(REFERENCE)/lib \
		-Wl,-rpath,'$$ORIGIN/../build/reference/lib' -lxml2 -o $@

tests/attribute-test-sanitize: tests/attribute-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -fsanitize=address,undefined $< -Llib -lxml3 -o $@

tests/runtime-test: tests/runtime-test.c tests/oom-shim.c $(PUBLIC_HEADERS) Makefile | build
	$(CC) $(CFLAGS) -Werror -pthread $< tests/oom-shim.c -Llib \
		-Wl,--enable-new-dtags,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/runtime-test-sanitize: tests/runtime-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -pthread -DXML3_RUNTIME_NO_OOM \
		-fsanitize=address,undefined $< -Llib -lxml3 -o $@

tests/dom-lock-test: tests/dom_lock_test.gpr tests/dom_lock_test.adb \
		tests/dom_lock_test_mutex.c src/xml3_dom_lock.ads src/xml3_dom_lock.adb
	$(ADA_BIN)/gprbuild -p -P tests/dom_lock_test.gpr -o dom-lock-test

tests/dom-projection-test: tests/dom_projection_test.gpr tests/dom_projection_test.adb \
		tests/dom_projection_probe.c src/xml3_native_memory.ads src/xml3_native_memory.adb
	$(ADA_BIN)/gprbuild -p -P tests/dom_projection_test.gpr -o dom-projection-test

tests/string-exception-test: tests/string-exception-test.c tests/oom-shim.c \
		$(PUBLIC_HEADERS) Makefile | build
	$(CC) $(CFLAGS) -Werror $< tests/oom-shim.c -Llib \
		-Wl,--enable-new-dtags,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

test-string-exception: tests/string-exception-test
	LD_LIBRARY_PATH=lib ./tests/string-exception-test

tests/error-test-sanitize: tests/error-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -pthread -fsanitize=address,undefined $< -Llib -lxml3 -o $@

tests/oom-test: tests/oom-test.c tests/oom-shim.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror $< tests/oom-shim.c -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/fuzz-test: tests/fuzz-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror $< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

tests/fuzz-test-sanitize: tests/fuzz-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -fsanitize=address,undefined $< -Llib -lxml3 -o $@

test-unicode: tests/unicode-test tests/unicode-test-reference
	LD_LIBRARY_PATH=lib ./tests/unicode-test
	LD_LIBRARY_PATH=$(REFERENCE)/lib ./tests/unicode-test-reference

test-encoding: tests/encoding-snapshot tests/encoding-snapshot-reference \
		tests/encoding-test tests/encoding-test-reference tests/encoding-unit-test
	LD_LIBRARY_PATH=lib ./tests/encoding-test
	LD_LIBRARY_PATH=$(REFERENCE)/lib ./tests/encoding-test-reference
	./tests/encoding-unit-test
	/usr/bin/python3 tests/compare-encoding.py

test-dom: tests/dom-test tests/dom-test-reference
	LD_LIBRARY_PATH=lib ./tests/dom-test
	LD_LIBRARY_PATH=$(REFERENCE)/lib ./tests/dom-test-reference

test-attributes: tests/attribute-test tests/attribute-test-reference
	LD_LIBRARY_PATH=lib ./tests/attribute-test
	LD_LIBRARY_PATH=$(REFERENCE)/lib ./tests/attribute-test-reference

test-runtime: tests/runtime-test tests/dom-lock-test tests/string-exception-test
	LD_LIBRARY_PATH=lib ./tests/runtime-test
	./tests/dom-lock-test
	LD_LIBRARY_PATH=lib ./tests/string-exception-test

test-dom-projection: tests/dom-projection-test
	./tests/dom-projection-test

test-resources: tests/resource-test tests/resource-test-reference \
		tests/error-snapshot tests/error-snapshot-reference \
		tests/encoding-resource-test tests/encoding-resource-test-reference
	LD_LIBRARY_PATH=lib ./tests/resource-test
	LD_LIBRARY_PATH=$(REFERENCE)/lib ./tests/resource-test-reference
	LD_LIBRARY_PATH=lib ./tests/encoding-resource-test
	LD_LIBRARY_PATH=$(REFERENCE)/lib ./tests/encoding-resource-test-reference
	/usr/bin/python3 tests/compare-errors.py --limits

test-errors: tests/error-test tests/error-test-reference tests/error-snapshot \
		tests/error-snapshot-reference
	LD_LIBRARY_PATH=lib ./tests/error-test
	LD_LIBRARY_PATH=$(REFERENCE)/lib ./tests/error-test-reference
	/usr/bin/python3 tests/compare-errors.py

test-oom: tests/oom-test
	@set -e; for operation in success malformed utf16 warning copy replacement tls dom-new-doc dom-new-node dom-new-text dom-new-comment dom-new-pi dom-merge dom-content-replace dom-content-child attr-new attr-detached attr-set-new attr-set ns-new ns-detached ns-prop-new ns-prop-set ns-qname-set ns-xml-qname serialization; do \
		index=0; \
		seen=0; \
		while [ $$index -lt 128 ]; do \
			if LD_LIBRARY_PATH=lib ./tests/oom-test $$operation $$index; then result=0; else result=$$?; fi; \
			if [ $$result -eq 2 ]; then \
				[ $$seen -eq 1 ] || { echo "$$operation never observed injected failure" >&2; exit 1; }; \
				echo "$$operation: walked $$index allocation sites"; break; \
			fi; \
			[ $$result -eq 0 ] || exit $$result; \
			seen=1; \
			index=$$((index + 1)); \
		done; \
		[ $$index -lt 128 ] || { echo "$$operation exceeded allocation cap" >&2; exit 1; }; \
	done
	LD_LIBRARY_PATH=lib ./tests/oom-test attr-delete 0
	LD_LIBRARY_PATH=lib ./tests/oom-test ns-noalloc 0

test-fuzz: tests/fuzz-test
	LD_LIBRARY_PATH=lib ./tests/fuzz-test

test-api: build tests/api-test tests/header-smoke.o tests/namespace-test tests/unicode-test
	LD_LIBRARY_PATH=lib ./tests/api-test
	LD_LIBRARY_PATH=lib ./tests/namespace-test
	LD_LIBRARY_PATH=lib ./tests/unicode-test

test-namespace: tests/namespace-test
	LD_LIBRARY_PATH=lib ./tests/namespace-test

test-namespace-edit: tests/namespace-edit-test tests/namespace-edit-test-reference
	LD_LIBRARY_PATH=lib ./tests/namespace-edit-test
	LD_LIBRARY_PATH=$(REFERENCE)/lib ./tests/namespace-edit-test-reference

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

check: build tests/header-smoke.o test-dom-core test-dom-bridge test-runtime test-dom-projection
	@for symbol in xmlInitParser xmlCleanupParser xmlReadMemory xmlParseMemory \
		xmlReadDoc xmlParseDoc xmlDocGetRootElement xmlFreeDoc xmlNodeGetContent \
		xmlNewDoc xmlDocDumpMemoryEnc xmlNewNode xmlNewText xmlNewComment xmlNewPI xmlDocSetRootElement xmlAddChild xmlUnlinkNode xmlFreeNode \
		xmlNodeAddContent \
	xmlNewProp xmlSetProp xmlUnsetProp xmlRemoveProp xmlFreeProp \
	xmlNewNs xmlSetNs xmlFreeNs xmlNewNsProp xmlSetNsProp xmlUnsetNsProp \
	xmlGetProp xmlHasProp xmlSearchNs xmlSearchNsByHref xmlHasNsProp \
	xmlGetNsProp xmlGetNoNsProp xmlFirstElementChild xmlNextElementSibling \
	xmlChildElementCount xmlStrcmp xmlStrEqual xmlStrlen xmlFree xml3ReadMemory \
	xmlGetLastError xmlResetLastError xmlResetError xmlCopyError; do \
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

tests/serialization-test-sanitize: tests/serialization-test.c $(PUBLIC_HEADERS) | build
	$(CC) $(CFLAGS) -Werror -DXML3_NO_OOM_TEST -fsanitize=address,undefined \
		$< -Llib -Wl,-rpath,'$$ORIGIN/../lib' -lxml3 -o $@

test-sanitize: build tests/namespace-test-sanitize tests/resource-test-sanitize \
		tests/encoding-test-sanitize tests/encoding-resource-test-sanitize \
		tests/error-test-sanitize tests/fuzz-test-sanitize tests/dom-test-sanitize \
		tests/namespace-edit-test-sanitize \
		tests/attribute-test-sanitize tests/runtime-test-sanitize \
		tests/serialization-test-sanitize tests/content-edit-test-sanitize
	$(CC) $(CFLAGS) -fsanitize=address,undefined tests/api-test.c -Llib -lxml3 -o tests/api-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/api-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/namespace-test-sanitize
	$(CC) $(CFLAGS) -fsanitize=address,undefined tests/unicode-test.c -Llib -lxml3 -o tests/unicode-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/unicode-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/encoding-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/encoding-resource-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/resource-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/error-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/fuzz-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/dom-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/attribute-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/namespace-edit-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/runtime-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/serialization-test-sanitize
	ASAN_OPTIONS=detect_leaks=1 LD_LIBRARY_PATH=lib ./tests/content-edit-test-sanitize

clean:
	rm -rf obj lib tests/api-test tests/header-smoke.o tests/differential-libxml3 \
		tests/differential-system tests/differential-reference tests/api-test-sanitize \
		tests/namespace-test tests/namespace-test-sanitize tests/unicode-test \
		tests/unicode-test-reference tests/unicode-test-sanitize tests/resource-test \
		tests/resource-test-reference tests/resource-test-sanitize tests/error-test \
		tests/error-test-reference tests/error-test-sanitize tests/error-snapshot \
		tests/error-snapshot-reference tests/oom-test \
		tests/encoding-snapshot tests/encoding-snapshot-reference \
		tests/encoding-test tests/encoding-test-reference tests/encoding-unit-test \
		tests/encoding-resource-test tests/encoding-resource-test-reference \
		tests/encoding-test-sanitize tests/encoding-resource-test-sanitize \
		tests/fuzz-test tests/fuzz-test-sanitize tests/dom-test \
		tests/dom-test-reference tests/dom-test-sanitize tests/dom-core-test \
		tests/dom-bridge-test tests/attribute-test \
		tests/attribute-test-reference tests/attribute-test-sanitize \
		tests/namespace-edit-test tests/namespace-edit-test-reference \
		tests/namespace-edit-test-sanitize \
		tests/serialization-test tests/serialization-test-reference \
		tests/serialization-test-development tests/serialization-test-sanitize \
		tests/content-edit-test tests/content-edit-test-reference \
		tests/content-edit-test-development tests/content-edit-test-sanitize \
		tests/runtime-test tests/runtime-test-sanitize tests/string-exception-test \
		tests/dom-projection-test tests/dom-lock-test \
		dom-lock-test runtime-test tests/*.out
