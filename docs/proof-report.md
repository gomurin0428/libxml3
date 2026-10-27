# SPARK proof evidence

## Result

`make prove` completed successfully on 2026-10-27 for this source revision:
**10,394 checks, 835 by flow analysis and 9,559 by provers;
0 unproved, 0 justified**. The aggregate includes namespace editing through
Store/Runtime, retained namespace ownership, failure rollback, and explicit
UTF-8 memory serialization through the SPARK serializer, Store, and Runtime.
The entity summaries report 0 flow errors, 125 warnings, and 0 `pragma Assume`
statements; warnings are not counted as discharged verification conditions.

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
| Data dependencies | 232 |
| Initialization | 460 |
| Runtime checks | 4,746 |
| Assertions | 1,419 |
| Functional contracts | 3,343 |
| Termination | 194 |
| **Total** | **10,394** |

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

The project contains sixteen complete SPARK units: text, parser, namespaces,
encoding, DOM, bridge, constructors, Store, queries, properties, documents,
serialization, Runtime, import, materialize, and the serialization core. Two
trusted specs, native memory and DOM allocation, bring the analyzer's unit
count to eighteen. Their bodies are not
proved: four allocation bodies and fifteen native-memory bodies are explicitly
`SPARK_Mode => Off`. All sixteen SPARK units were fully analyzed. The C
adapter, mutex/controlled guard, and error handling are not in
the proof project. Native layout/freshness, pointer validity, allocator and
thread-runtime correctness are assumptions, not consequences of ID equations.

## Verified implementation path

Public parsing follows `Runtime.Read → Documents.Read → Parse → Resolve →
Materialize.Build → Store.Adopt_Arena → Import.Adopt → Synchronize`.
`Discard_Arena` retires an unpublished source after failed adoption and then
releases its backing state. Failed adoption leaves that source valid and
caller-owned until cleanup. Errors remain distinct from memory exhaustion.

Explicit UTF-8 memory serialization follows the Runtime passthrough to
`XML3_DOM_Store.Serialization.Dump` and `XML3_Serialization.Render`. The
serializer reads immutable Store state, performs iterative validation and
measurement before allocating, then emits through the same traversal into an
exact-size native buffer. SPARK checks and written contracts for these units
are included in this aggregate; XML conformance and full libxml2 lexical
equivalence remain tested properties, not proof claims. The C adapter and
native allocator/byte operations remain outside proof.

Public construction, root replacement, attachment/text merging, unlinking,
release, namespace creation/assignment/free, namespace-qualified property
mutation and read-only queries use the same Store. Constructed namespaces
retain one owner reservation; parsed declarations use their document arena.
Subtree release detaches declarations before retiring their elements, while
borrower pins keep the native storage alive. Qualified `xmlSetProp` resolves
validated QNames in Store and rolls back implicit XML declarations on failure.
Property lookup/content retrieval and lookup/removal each execute as
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

The following sequential regression command passed against the final source
after the successful aggregate proof:

```sh
make -k test-dom-core test-dom-bridge test-namespace-edit test-development \
  test-oom test-attributes test-dom test-namespace test-api test-sanitize check
git diff --check
```

`test-namespace-edit` also passed against the pinned libxml2 2.15.4 reference.
Namespace regressions cover URI/local-name matching, attribute identity and
order, `_private`, NULL/empty values, malformed/unbound QNames, documentless
XML attributes, parsed/constructed borrower lifetimes, declaration release,
and allocation-failure rollback. Intentional safety differences are excluded
from the reference run rather than imitating unsafe lifetime behavior.

The previously recorded `make check-inventory` **failed** (not rerun for this
namespace change): four declarations in the frozen inventory
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
production pthread regression also passed twenty separate invocations during
the earlier tasking-runtime fix; that twenty-run probe was not repeated here.
Tests are evidence for the trusted boundary, not a
formal proof of it. ASan/UBSan instrumentation applies to the C test side;
the Ada library is not thereby fully sanitizer-instrumented.

An earlier local diagnostic probe (not repeated for this change) constructed
and attached a 12,000-node chain in
1.685536 s of construction plus 1.259977 s of attachment on this VM. The
probe checked each returned pointer and completed cleanup. This single
observation is not a benchmark guarantee or a general scalability claim;
whole-Store scans remain, and non-leaf operations may be much more expensive.
The repository's unchanged 12,000-depth regression is a separate test gate.

## Source identity (SHA-256)

```text
c6b0328bff547ae52b27ebdd07dd1b595c538ef0d97623ea18f965d7b77a1c44  src/xml3_c.adb
774ef77903f80123248af6bed6db758db4ffa22743621081fb2ebbca39caa25d  src/xml3_c.ads
9b689c6c3cfa14bebfba10dab5867c00fa877d16cfba660974b3f820fe6ea104  src/xml3_dom-import.adb
64707d2b0c629bbc574ed89d97aa4aedc643bde9744d13bf7ffcb3ae7c3f5ddf  src/xml3_dom-import.ads
a9d3d0e407fd1c36cb33e262b9d131c3116a115fde8f323ecbd32c83b1dbf131  src/xml3_dom-materialize.adb
11b0272dbbf8cf7988fb7c96ef8f104f22db1a1390e2c3f5df0bd6d3f6ef60c1  src/xml3_dom-materialize.ads
88179f7d744b408c8fe2a73efdb6aa798c30ec2357f78c3c42997cb1332f5d0a  src/xml3_dom.adb
af8c8f446580a0cddb1f959f1739d9acd665ecdbc5ddddc7078f41efa36ce878  src/xml3_dom.ads
1b0b582fc5ab3c34e5d96d5fce20b536426df9f68fbe4b4e99423785eb978002  src/xml3_dom_allocation.adb
38c4ff80e2a8bafa63579a0cb03026926cb4ad4ee44d2324d86842e119ac1c05  src/xml3_dom_allocation.ads
c25f8e859f3b568737e637ba9e1c8eb0238fcb83aa8de34a09cea35ab1b345aa  src/xml3_dom_bridge.adb
a62a5e86be7f9e74c7618d38a3210b4e31842d1cba5304ad3cf4efd7d32987b8  src/xml3_dom_bridge.ads
1214e57d070cdd51553c020152d13404d01f4d29eba055933101b937608cf173  src/xml3_dom_constructors.adb
3fb1a6194a5f054c325f190a9853da2c188b93708ad95cd5fda2076873e12e11  src/xml3_dom_constructors.ads
46fd9519a39976fcfbd0c9d8602b8e4f969e16547203f1022eb19718a862a2f8  src/xml3_dom_lock.adb
3010f199780bd3bc276580641cd87e54520e4bbaa1893c40b3b079b8e0439535  src/xml3_dom_lock.ads
804f1a3371bc434ce35784d7605c6a8153f401b55da2fbb8a49145a71bc42e1b  src/xml3_dom_mutex.c
c2f4e142977120f9ae89aad17967f129addcde699006c269af5db4af3a33025e  src/xml3_dom_runtime.adb
147f290550aced26ac5dce4e436b1fd5ecd24f6cfb565e58b26fdc5d3ac6a980  src/xml3_dom_runtime.ads
7049538ece6d409cc138892870026f1216109b19baca4afe45a605160b9100e5  src/xml3_dom_store-documents.adb
6c52972b1a9bedcd5032918c0ae52efce069d7ab512555822beec7c833aae4c3  src/xml3_dom_store-documents.ads
1334154710f271040b55a309cd9b4ff93fb1d82988fbd85046dd7d05d3179944  src/xml3_dom_store-properties.adb
4d598d091c912dbb6f909efd12fcd8fe556b51ff2fc02754d8b314aa61666750  src/xml3_dom_store-properties.ads
0e31c3380f83e18a3dc7d456db4cb3e90249102a1fbeca4df4cd80aee5a6c228  src/xml3_dom_store-queries.adb
27a883898b75ecd1c7c275f256aaa1903eaf053b80ffd137a6cbf1abec82a82f  src/xml3_dom_store-queries.ads
e17b9d6cf6d33b099ab68275cfc282f572a46cad0edc21e3e0703ad3c1413eb1  src/xml3_dom_store-serialization.adb
fcfa348242acf0dc69540b20063081c3f56b18960c984cfa9e8d3d649dbf0dc9  src/xml3_dom_store-serialization.ads
b496ecf7c151ee842d8782fe13bead9a44937114a01565b02e424a1ec1c475a5  src/xml3_dom_store.adb
781edb70343c96ac3ee0c354bb1e514ec76c7c40450a8591d37904d57ada90c4  src/xml3_dom_store.ads
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
eb1437b6c5555203332a6f717d91acdd8381967a69845e7b50a3bf4c8c2ca10f  src/xml3_serialization.adb
4a3c84a0b7ee2b7b1a0129b63f37e36b1547c8e75152c7463e06d3f019d0f217  src/xml3_serialization.ads
07138e9a9c47e6ae18255e627b814b29f688e4e89b954913cdabf264d75b53c1  src/xml3_parser.ads
47f78aaebd907be02955b0d9b991eb47d7b2c344c3cae7b924a7ca575ba10c5b  src/xml3_text.adb
7e1c81bf4f77e1e6d433710179b63f28bf00057aeef6f5cf07708a113dd4d809  src/xml3_text.ads
087b0ba0054111ae75a9f293a9a7670956042efa3a93b2b3b7adc02b100276f2  proof.gpr
5ad0affe7e6bcd3fbef62dae8cc27dbc3936a9a4485e4a34bddb65a054fc7431  libxml3.gpr
ace30e9035f3173c4e55b94a335ce3dc352799b4f5267468c26cbecea6a34185  Makefile
c5269fafd0c1bab521ca0e18f279ed6c5dc7ef0b10151bb4c3618381984005b7  .github/workflows/manual.yml
```

A source or contract change invalidates this record until proof is rerun.
Solver percentages can vary without changing the obligations. The proof
assumes the compiler, translator, solvers and runtime model are sound;
resource exhaustion and foreign-memory behavior remain outside it.
