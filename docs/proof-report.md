# SPARK proof evidence

## Result

`make prove` completed successfully for this source revision: **7,081 checks,
641 by flow analysis and 6,440 by provers; 0 unproved, 0 justified**.
The unchanged `Attach` parent-preservation postcondition is discharged with
two additional checked frame assertions around document propagation.

**Analyzer caveat:** generation of representation information for the trusted
`xml3_dom_allocation.ads` spec failed (`cannot generate code for file ...
(package spec)`); GNATprove continued with partial representation data. This
warning is not resolved by the successful proof. Native representation/layout
is outside the claim. Trusted external-termination warnings also remain.

The unedited analyzer summary is in [proof-summary.txt](proof-summary.txt).
This is a proof of the selected SPARK units and their written contracts, not
of the entire C ABI, native memory layout, synchronization implementation, or
full XML conformance. Public DOM APIs now delegate to the SPARK Store/Runtime;
the adapter and the native boundary remain trusted. See [assurance.md](assurance.md).

| Category | Checks |
| --- | ---: |
| Data dependencies | 179 |
| Initialization | 344 |
| Runtime checks | 3,408 |
| Assertions | 929 |
| Functional contracts | 2,059 |
| Termination | 162 |
| **Total** | **7,081** |

The analyzer's counts are verification conditions, not vulnerabilities, test
cases, or supported APIs. `Parse`, `Decode`, namespace `Resolve`, and
`Decode_UTF16` have explicit `Always_Terminates` aspects. Termination is not a
wall-clock or resource bound.

## Reproduction

Verified on Ubuntu 22.04.5 x86_64 (glibc 2.35), with Alire packages
`gnat_native=14.2.1`, `gprbuild=26.0.1`, and `gnatprove=14.1.1`.
The compiler banner is 14.2.0; the analyzer reports `0.0w`, while 14.1.1
identifies its pinned package. Bundled Why3 is 1.6.0+git, cvc5 is 1.1.2,
and Z3 is 4.13.0. With that toolchain on PATH:

```sh
make prove
# gnatprove -P proof.gpr --mode=all --prover=cvc5,z3 --timeout=10 -j4
```

`proof.gpr` sets `--level=2 --report=all --checks-as-errors=on` and enables
assertions independently of the production profile. Unproved checks must
fail the command. No assumptions, proof exemptions, weakened contracts, or
new SPARK-off DOM logic were introduced. The aggregate uses the existing
proof session; it is not a cold-cache performance claim. The output is
`obj/proof/gnatprove/gnatprove.out`.

The project contains fourteen complete SPARK units: text, parser, namespaces,
encoding, DOM, bridge, constructors, Store, queries, properties, documents,
Runtime, import, and materialize. Two trusted specs, native memory and DOM
allocation, bring the analyzer's unit count to sixteen. Their bodies are not
proved. The C adapter, mutex/controlled guard, and error handling are not in
the proof project. Native layout/freshness, pointer validity, allocator and
thread-runtime correctness are assumptions, not consequences of ID equations.

## Verified implementation path

Public parsing follows `Runtime.Read → Documents.Read → Parse → Resolve →
Materialize.Build → Store.Adopt_Arena → Import.Adopt → Synchronize`.
`Discard_Arena` retires an unpublished source after failed adoption and then
releases its backing state. Failed adoption leaves that source valid and
caller-owned until cleanup. Errors remain distinct from memory exhaustion.

Public construction, root replacement, attachment/text merging, unlinking,
release, namespace-free property mutation and read-only queries use the same
Store. Property lookup/content retrieval and lookup/removal each execute as
one Runtime operation. A trusted pthread mutex serializes these operations;
there is no legacy fallback. `GNAT.Threads` forces the tasking runtime so
foreign pthreads have separate secondary stacks and exception state.

The DOM invariants cover bidirectional links, ranks/cycle prevention, document
propagation, reference counts versus actual holders, namespace ownership,
rollback and release ordering. The Store validates live IDs and facade
identity. Those checks do not make arbitrary foreign pointers safe to read.

The bridge projects native fields before emitting a release, calls native
free, then acknowledges. IDs cannot be reused before acknowledgement. Releasing
namespace fields are cleared first. Native projection avoids storing unchanged
fields; this avoids unrelated writes into an independently used document.
Caller synchronization is still required for borrowed pointers to the same
mutable document and for concurrent release.

`Ancestor_Descent` separates the recursive ghost calculation from its wrapper
contract. `Prepare_Subtree` uses the existing `Leaf_Ancestor_Lemma` to mark
only the root when it has neither children nor properties; non-leaf behavior
is unchanged. The same graph/rank/mark contracts remain. This removes repeated
ancestor walks during incremental leaf construction without weakening proof.

## Execution profiles and regression evidence

Production uses `-O2 -gnato` without `-gnata`; explicit validation, range and
integer-overflow checks remain. Development keeps `-gnata -gnato -g` and a
separate object/library directory. `proof.gpr` and core/bridge unit tests
remain assertion-enabled. No `-gnatp` or assertion-policy suppression is used
to discharge proof obligations.

The following commands passed (the final ghost-only frame additions were
followed by core/bridge/development tests and the aggregate proof):

```sh
make test-api test-namespace test-attributes test-unicode test-encoding \
     test-errors test-oom test-resources test-fuzz compare
make test-dom
make test-sanitize
make check
make test-dom-core test-dom-bridge test-development
git diff --check
```

`make check-inventory` **failed**: four declarations in the frozen inventory
contain absolute header paths from `/home/ubuntu/repos/libxml3`, whereas this
checkout is `/home/ubuntu/repos/libxml3-spark-dom`. The generated difference
is limited to those paths, not API declaration changes. The inventory and
generator were left unchanged. GitHub Actions is manual-only and was not run.

Regression coverage includes connected parse/edit/query/release and Store
reuse, two-document preservation, detached subtree lifetime after source
document release, literal/duplicate/null/empty property values, merge rollback,
native fields and document links, and invalid-input diagnostics. The stronger
detached-lifetime assertion is intentionally excluded from libxml2 reference
runs rather than reproducing unsafe reference behavior.

Native bridge tests wrap allocation/free to check exactly-once cleanup and
projection-before-release. The Documents regression fails Store allocation
after successful materialization, checks that every unpublished allocation
was freed once, and successfully reuses the Store. Public OOM walks exercise
allocation failures and state preservation. Lock tests cover exceptions and
injected lock/unlock errors. A 1 MiB string-allocation failure checks that the
exported wrapper catches the exception. Read-only mmap pages check that
identical node/document/namespace projection performs no writes.

Independent pthread tests inspect native fields and query/mutate separate
documents; they do not intentionally race read/free on the same facade. The
production pthread regression also passed twenty separate invocations after
the tasking-runtime fix. Tests are evidence for the trusted boundary, not a
formal proof of it. ASan/UBSan instrumentation applies to the C test side;
the Ada library is not thereby fully sanitizer-instrumented.

A local diagnostic probe constructed and attached a 12,000-node chain in
1.685536 s of construction plus 1.259977 s of attachment on this VM. The
probe checked each returned pointer and completed cleanup. This single
observation is not a benchmark guarantee or a general scalability claim;
whole-Store scans remain, and non-leaf operations may be much more expensive.
The repository's unchanged 12,000-depth regression is a separate test gate.

## Source identity (SHA-256)

```text
a1766e788b21147a21b80b2e0293f168eab795cf5aa0c39f0bdd8707d320b0da  src/xml3_c.adb
a7edc243e63b29278fa8939c69ca9b8a73efa452c50ac24161383baf6a5b63e7  src/xml3_c.ads
d96c80620eb295816de0e000a976500fca97c1365d33dd96c57d31a726c2d5eb  src/xml3_dom-import.adb
64707d2b0c629bbc574ed89d97aa4aedc643bde9744d13bf7ffcb3ae7c3f5ddf  src/xml3_dom-import.ads
16edecdcbf79a79f0568afe025877c9b9113afaab08bf983d5b7dd053b757392  src/xml3_dom-materialize.adb
11b0272dbbf8cf7988fb7c96ef8f104f22db1a1390e2c3f5df0bd6d3f6ef60c1  src/xml3_dom-materialize.ads
24a9a06c64ffa87ab5dfddec34928bcf6e0201813c96a42aaa563e729ec1861f  src/xml3_dom.adb
a457b890dbb44ee9698ca38ad9af029f18511bb431660e3142228febf4a98d9c  src/xml3_dom.ads
1b0b582fc5ab3c34e5d96d5fce20b536426df9f68fbe4b4e99423785eb978002  src/xml3_dom_allocation.adb
38c4ff80e2a8bafa63579a0cb03026926cb4ad4ee44d2324d86842e119ac1c05  src/xml3_dom_allocation.ads
dd29f41eca701df16260920c23075459c3eedc99175d2d9302ee7225d1d945a8  src/xml3_dom_bridge.adb
a62a5e86be7f9e74c7618d38a3210b4e31842d1cba5304ad3cf4efd7d32987b8  src/xml3_dom_bridge.ads
e98d478d78ae0a0dae9496f7c44188e78aa3f90800b9ac18260963e65b59353f  src/xml3_dom_constructors.adb
5a434888dd9904ff0bebfd1ef6aa3711047cf97375d3e0d538f0dc4dbb8d9839  src/xml3_dom_constructors.ads
46fd9519a39976fcfbd0c9d8602b8e4f969e16547203f1022eb19718a862a2f8  src/xml3_dom_lock.adb
3010f199780bd3bc276580641cd87e54520e4bbaa1893c40b3b079b8e0439535  src/xml3_dom_lock.ads
804f1a3371bc434ce35784d7605c6a8153f401b55da2fbb8a49145a71bc42e1b  src/xml3_dom_mutex.c
92c4c578deee9b50a6fe1c06d3fc449ddbe7e3adbd0ca17beabf0e81a596016b  src/xml3_dom_runtime.adb
138bf7cab8c882cbaee69006d5659c9e5040f63d23b2978f46e3bbd93d3d140b  src/xml3_dom_runtime.ads
64e32f05baeddeae5b60c7561d05807fda30dcb8e95aa284069a8ae212f54507  src/xml3_dom_store-documents.adb
6c52972b1a9bedcd5032918c0ae52efce069d7ab512555822beec7c833aae4c3  src/xml3_dom_store-documents.ads
33775ab9750d2809467a4af2ce999420beabaff8e432f0f0b5b06d7d26422f45  src/xml3_dom_store-properties.adb
c6fe29c6cf56fab4d01d2462aa9b85326c278683f1f3a1a091ea5f02c55f305b  src/xml3_dom_store-properties.ads
9d690abff34db64a9a26322732de554fe399f8f23b13fe96fd614f2c37a85043  src/xml3_dom_store-queries.adb
27a883898b75ecd1c7c275f256aaa1903eaf053b80ffd137a6cbf1abec82a82f  src/xml3_dom_store-queries.ads
b877a44f52544745817c13555e17e0b017d54e66e77f74d48b2a914e85847f08  src/xml3_dom_store.adb
da1c297a1ccd35ff522c73073361314c03f13fbff99db633acc9e893dc932c94  src/xml3_dom_store.ads
7a7d9e2c073d9619dfe9e2945e8454ba957e9e8fd7da915d91cf724a9d2542af  src/xml3_encoding.adb
095e4c527eced72f9fe7d7cf91f4fe637358beb094a53b9bde84bf3c2f6a904d  src/xml3_encoding.ads
53fed6a5a3374aa4f67ff6865a0d703274f89bfd44f036285a2166a31d843cfe  src/xml3_error_tls.c
ea5fb0d9851f8262d8ced6e2b2d4319125ed28dbc93c1deedf308823214b6d01  src/xml3_errors.adb
bc9416be82db99c3e992e91890de4024179f16fec29b3685b905212913d0a2c3  src/xml3_errors.ads
09734ebf88516572b7fbd7dc1b023316755d8ab156d7fcce58e2c785c0ec219f  src/xml3_namespaces.adb
055155bfd5a5e8b1c55cba12d27739810c9e70c6e3bb979f2aee07d4e9372831  src/xml3_namespaces.ads
be25d8c69fe23913458e9a332740d1e2b500b4a86fb6efa58d374eac6d2652dc  src/xml3_native_memory.adb
cd9bcad78d7dfd418e27a8237dd47b7e0c2aef4d9826324206b5fdcd93d8ba9e  src/xml3_native_memory.ads
2e31dde2f0ae750a8af15781b4d22bac59e14b388344c49a9a087021d7883f92  src/xml3_parser.adb
07138e9a9c47e6ae18255e627b814b29f688e4e89b954913cdabf264d75b53c1  src/xml3_parser.ads
47f78aaebd907be02955b0d9b991eb47d7b2c344c3cae7b924a7ca575ba10c5b  src/xml3_text.adb
7e1c81bf4f77e1e6d433710179b63f28bf00057aeef6f5cf07708a113dd4d809  src/xml3_text.ads
6b2e8fbf97a6aa87e35ec48c018704429dfb2c9728c08a180ae6b667945ab433  proof.gpr
5ad0affe7e6bcd3fbef62dae8cc27dbc3936a9a4485e4a34bddb65a054fc7431  libxml3.gpr
6eb859bd105b53ba57783061f7489aeca23266a56e1aa1e1662f370d07fea518  Makefile
fa40c1cbfa480eb59687cd4e079e3f8b82a35ed0be7524a50957ac2e59ae3770  .github/workflows/manual.yml
```

A source or contract change invalidates this record until proof is rerun.
Solver percentages can vary without changing the obligations. The proof
assumes the compiler, translator, solvers and runtime model are sound;
resource exhaustion and foreign-memory behavior remain outside it.
