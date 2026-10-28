# SPARK proof evidence

## Result

`make prove` completed successfully for this source revision:
**10,980 checks, 914 by flow analysis and 10,066 by provers;
0 unproved, 0 justified**. The aggregate includes namespace editing through
Store/Runtime, retained namespace ownership, failure rollback, explicit UTF-8
memory serialization, `xmlNodeAddContent`, `xmlNodeAddContentLen`,
`xmlNodeSetContent`, `xmlTextMerge`, `xmlTextConcat`, `xmlNodeIsText`,
`xmlIsBlankNode`, `xmlNodeGetLang`, `xmlNodeGetSpacePreserve`,
`xmlNodeSetLang`, `xmlNodeSetSpacePreserve`,
`xmlNewChild`, `xmlNewTextChild`, `xmlNewDocText`, `xmlNewDocTextLen`,
`xmlNewDocComment`, `xmlNewDocPI`, `xmlNewDocNode`, `xmlNewDocRawNode`, and
`xmlNewCDataBlock`, `xmlLastElementChild`, and `xmlPreviousElementSibling`
through the SPARK Store/Runtime. The entity summaries report
0 flow errors, 131 warnings, and 0 `pragma Assume`
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
| Data dependencies | 252 |
| Initialization | 519 |
| Runtime checks | 4,942 |
| Assertions | 1,470 |
| Functional contracts | 3,602 |
| Termination | 195 |
| **Total** | **10,980** |

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

The project contains seventeen complete SPARK units: text, parser, namespaces,
encoding, DOM, bridge, constructors, Store, Store.Content, queries, properties,
documents, serialization, Runtime, import, materialize, and the serialization
core. Two trusted specs, native memory and DOM allocation, bring the analyzer's
unit count to nineteen. Their bodies are not
proved: four allocation bodies and fifteen native-memory bodies are explicitly
`SPARK_Mode => Off`. All seventeen SPARK units were fully analyzed. The C
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

`xmlNodeAddContent` and `xmlNodeAddContentLen` use the same
`Runtime.Add_Content` and `XML3_DOM_Store.Content.Append` path, whose Store
contract requires and restores `Ready (S)`. The length-bounded adapter performs
a trusted `C_String_Prefix`/`Scan_Length` conversion and passes `Has_Input` only
for positive-length non-NULL input. Store uses that flag to distinguish a
positive-length leading NUL, which materializes empty text/content when needed,
from a zero/nonpositive-length or NULL-input no-op. Raw bytes are not decoded;
bounded pointer scanning and foreign-pointer validity remain outside GNATprove.
Guard-page checks, empty-text allocation failure/retry, and UTF-8 split-append
repair are runtime evidence, not additional formal claims.
The private `Replace_Content` helper requires a non-pending projection and
explicitly postconditions a non-null, valid, editable Store with projection
complete and facades present. Its frame preserves node and namespace counts,
unrelated live node views, and all target-node fields other than content
address, length, and pin on success; a non-success status leaves the target
node unchanged.
`xmlNodeSetContent` routes through `Runtime.Set_Content` and
`XML3_DOM_Store.Content.Set`. Element/Attribute input is decoded before
mutation; the replacement text child is attached before old children are
retired. The `Retained_Ancestor` ghost lemma relates current live ancestry to
the original state for the iterative namespace-aware retirement frame.
`Retire_One_Element_Child` requires a live element and child, valid sibling
links, and `Child /= Keep`; its postcondition frames the element's child
endpoints and the retained child's sibling links while preserving counts,
capacity, Store validity, and facade/owner guarantees. The `Replace_Content`
frame preserves unrelated live nodes and, on success, changes only the target
content address, length, and pin. No element-wise namespace-entry frame is
claimed. Runtime tests cover append and replacement semantics, decoding,
aliasing, facade and detached namespace-owner lifetime, and allocation-failure
rollback/retry; those are test evidence, not formal claims.

`xmlNodeSetContentLen` adds no SPARK Store/Runtime code and makes no new proof
claim. Its exported wrapper uses the trusted `C_String_Prefix`/`Scan_Length`
conversion in `xml3_c.adb` before calling the existing `Runtime.Set_Content`;
foreign pointer validity and bounded scanning are outside GNATprove. Runtime
tests exercise non-terminated bounded input and a zero-length pointer at a
guard page. The pinned reference parser reads `content[0]` even when `len` is
zero, so the guard-page case is library-only; the safe empty-value behavior is
test evidence, not a formal pointer-safety claim.

`xmlNewChild` routes through `Runtime.New_Child` and
`XML3_DOM_Store.Content.New_Child`. The Store helper requires and restores
`Ready (S)` and postconditions that the result is non-null exactly on
`Created`. The implementation decodes content before constructing nodes,
constructs the element and optional text child, attaches the text before
attaching the element to its parent, and releases unpublished nodes on failure.
These helper contracts do not claim full API-level rollback or libxml2 semantic
equivalence; namespace inheritance, construction behavior, and failure
preservation are covered by tests.

`xmlNewTextChild` uses the same helper and contract through a raw-content mode.
The Store copies input into scratch before constructing nodes and does not
decode references or validate XML/UTF-8 in this mode. A text child is created
when content is non-NULL, including an empty string; NULL content creates no
text child. Its `Ready (S)` and result/status guarantees do not claim full
API-level semantic proof. Raw reference preservation, NULL/empty distinction,
namespace behavior, serialization rejection and repair of invalid content,
detached-parent lifetime, and allocation-failure retry are test evidence.

`xmlNewTextLen` selects `Text_Node` in the shared
`Runtime.New_Doc_Content` / `Store.Content.New_Doc_Content` path. Its C adapter
rejects negative lengths only when content is non-NULL, then uses a trusted
bounded `C_String_Prefix`/`Scan_Length` conversion for raw bytes. NULL content
remains NULL for any length; a non-NULL zero-length input creates empty content
without reading the pointer. Embedded NUL ends the retained prefix. Pointer
scanning and validity remain outside GNATprove; guard-page, NULL/empty,
serialization, detached-node, and allocation-failure cases are runtime
evidence for the API wrapper, not a pointer-safety proof claim.

`xmlNewDocText`, `xmlNewDocTextLen`, `xmlNewDocComment`, `xmlNewDocPI`, and
`xmlNewCDataBlock`
route through `Runtime.New_Doc_Content` and
`XML3_DOM_Store.Content.New_Doc_Content`. The Store operation accepts
text, CDATA, comment, PI, and empty element kinds, requires and restores `Ready (S)`, and relates a
non-NULL result to `Created` status. It validates a non-NULL document before
constructing the node, re-finds the document and new node after construction,
then uses the existing `Set_Node_Projection` contract to set `Document` and
`Doc_Pin` without attaching the node as a child. The projection contract
preserves owner reference invariants; failed affiliation releases the
unpublished node. The C constructors share one private `New_Content_Node`
helper for input conversion, locking, status reporting, and exception mapping;
this removes the duplicate document-text adapter but does not move graph or
ownership decisions into C. String conversion and bounded pointer scanning
remain outside GNATprove. These existing contracts do not establish complete
public API semantics or rollback; NULL/bounded input behavior, document
validation, unattached construction, serialization, document-first release,
and allocation-failure retry are runtime evidence. Registration callbacks and
native PI dictionary interning are unsupported.

`xmlNewDocNode` / `xmlNewDocRawNode` use `Runtime.New_Doc_Node` and
`Store.Content.New_Doc_Node`. This operation reuses `New_Doc_Content` for an
empty element with an explicit namespace, then constructs and attaches a text
child when required. `New_Child` delegates its construction phase here before
attaching the unpublished element to the parent; `xmlNewNode` delegates to the
same documentless path. Decoding/raw handling, affiliation, namespace pins and
failure cleanup remain in SPARK, with no parallel C ownership logic. The new
operation's contract restores `Ready` and relates result/status; full public
API behavior, reference semantics and C pointer validity remain outside the
formal claim. Runtime tests cover decoded/raw input, copied names and content,
NULL/empty distinctions, subtree document affiliation without attachment,
namespace retention after document-first release, and allocation-failure retry.

`xmlNewCDataBlock` selects `CData_Node` in the same C/Runtime/Store path. The
core `Create_Node` postcondition explicitly guarantees a null `Name` address
and zero `Name_Length` for CDATA; this is a specific proved projection
guarantee, not a full API semantics claim. The C wrapper rejects a negative
length before reading non-NULL content, then performs a trusted bounded-prefix
scan. NULL content is accepted at any length, and zero length does not read the
pointer. Pointer validity and scanning remain outside GNATprove. Copying,
NULL/empty distinction, CDATA delimiter splitting and serialization/reparse,
invalid UTF-8 rejection and repair, document-first release, and OOM retry are
runtime evidence for behavior rather than complete semantic proof.

`xmlNodeIsText` / `xmlIsBlankNode` use `Runtime.Test_Node` / `Store.Queries.Test_Node`.
Runtime declares both managed state and foreign memory as `Input`; the Store
query does not mutate the graph or allocate content. Its failure postcondition
requires a false result. Kind checks and XML-whitespace scanning occur in SPARK,
bounded by managed content length. Native byte access remains trusted.
Tests cover text versus CDATA, NULL/empty/XML-only whitespace,
non-XML whitespace, other node kinds, mutation-driven classification changes,
document-first release and rejection of unmanaged facades. These are runtime
semantic checks, not a claim of complete C API proof. Common cases also run against
the pinned reference; document-first release and unmanaged facades are
library-specific checks.

`xmlNodeGetLang` / `xmlNodeGetSpacePreserve` use
`Runtime.Get_Inherited_XML_Property` / `Store.Queries.Get_Inherited_XML_Property`;
setters reuse `Runtime.Set_XML_Property` and `Store.Properties.Set_Qualified_Property`.
The Store owns the bounded parent walk, node-kind and exact XML-namespace checks,
space-value comparison and temporary-buffer cleanup. The C adapters only
convert inputs/outputs, lock and map status. Focused inherited-value, setter,
reparenting, serialization, copy-lifetime and OOM rollback tests are runtime
evidence, not complete semantic proof of the public APIs or native boundary.

`xmlTextConcat` reuses `Runtime.Add_Content` / `Store.Content.Append` with a
scalar-only policy checked before the empty-input no-op. Existing
`Replace_Content` contracts preserve unrelated nodes and the target on failure,
and restrict successful target changes to content, length and content pin.
The C adapter shares bounded/unbounded conversion, locking and result mapping;
it performs no DOM traversal. Scalar kinds, NULL/empty input, bounded and negative
lengths, aliasing, guard pages, retained document lifetime, serialization/reparse
and native OOM retry are runtime evidence, not a complete public semantic proof.

`xmlTextMerge` uses `Runtime.Merge_Text` / `Store.Merge_Text`, also shared by
`Add_Child` coalescing. The Store contract restores `Ready` and relates a successful result to the
first non-NULL operand and returns NULL on failure. For non-NULL content the
existing core `XML3_DOM.Merge_Text` contract guarantees target content/pin,
target parent preservation, source tombstoning and valid state. Source NULL
content instead uses the normal release path without replacing target bytes.
Native buffer allocation precedes graph mutation. This is not a complete
public semantic/atomicity proof: nonadjacent and attribute text, NULL/empty
distinctions, retained document lifetime, allocation-failure state preservation
and retry are covered by C regression tests. Cross-document source affiliation
and no-escape text variants remain unsupported; the native boundary is trusted.

`xmlLastElementChild` and `xmlPreviousElementSibling` extend the existing
`Store.Queries.Select_Element` with reverse traversal over `Last_Child` and
`Previous`. Node-kind filtering and bounded scanning execute in SPARK; the
C selector is shared with root/first/next queries and performs no native-link
traversal. The existing contract relates failed status to NULL result/zero
count; nearest-element selection semantics are runtime-tested, not claimed as
fully proved. Tests include mixed non-element siblings, detach/reinsert,
document and attribute inputs, and retained subtree navigation after document
release. No ownership mutation or result allocation is introduced.

Public construction, root replacement, attachment/text merging, unlinking,
release, namespace creation/assignment/free, namespace-qualified property
mutation and read-only queries use the same Store. `xmlNewComment` and
`xmlNewPI` use the same `New_Doc_Content` Store/Runtime operation as their
document-affiliated counterparts.
Constructed namespaces retain one owner reservation; parsed declarations use
their document arena.
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

The focused comment/PI construction tests passed:

```sh
make tests/serialization-test tests/serialization-test-reference
LD_LIBRARY_PATH=lib ./tests/serialization-test --misc
LD_LIBRARY_PATH=build/reference/lib ./tests/serialization-test-reference
```

They cover constructed top-level and child comments/PIs, raw input copying,
NULL and empty content, Unicode, reparsing, invalid comment/PI text and
reserved PI targets, output failure followed by removal/retry, and detached
node lifetime after freeing the document. The pinned libxml2 2.15.4 reference
build runs the shared exact-output cases, including constructed comments/PIs.

`make test-content-edit` passed for both the library and pinned libxml2 2.15.4
reference builds. The `dom-new-child` and `dom-new-text-child` OOM walks each
injected failures at both allocation sites and passed the successful retry.
The development content-edit build and test also passed.

```sh
make -k test-development test-oom test-dom test-api test-serialization \
  test-sanitize check check-inventory
```

The full command passed. It includes development and sanitizer content-edit
tests; serializer tests passed in both library and reference builds. The
inventory check's Python suite reported five passing tests, and `make inventory`
regenerated API coverage successfully. Clang printed its existing deprecation
warnings for `SAX.h`, `nanoftp.h`, and `xmlunicode.h`.

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
8f9d2ad52443ef8b72c86a33d387dcb798ddf8373dc4dc7a2c3bec32eab373fb  src/xml3_c.adb
a9f60b0a59a242ea043aea5a968fec4e450fdb8c374b6d3043ab4f7f44d1a9dd  src/xml3_c.ads
9b689c6c3cfa14bebfba10dab5867c00fa877d16cfba660974b3f820fe6ea104  src/xml3_dom-import.adb
64707d2b0c629bbc574ed89d97aa4aedc643bde9744d13bf7ffcb3ae7c3f5ddf  src/xml3_dom-import.ads
a9d3d0e407fd1c36cb33e262b9d131c3116a115fde8f323ecbd32c83b1dbf131  src/xml3_dom-materialize.adb
11b0272dbbf8cf7988fb7c96ef8f104f22db1a1390e2c3f5df0bd6d3f6ef60c1  src/xml3_dom-materialize.ads
ebd48b22f0251b30c6a8b1ddad1183c058ca54643ab796704f73ef939a68c2bc  src/xml3_dom.adb
42ac3bf19150b83f89cfb6acf21cae98f45ee82b1daef26140dd935d55f843b2  src/xml3_dom.ads
1b0b582fc5ab3c34e5d96d5fce20b536426df9f68fbe4b4e99423785eb978002  src/xml3_dom_allocation.adb
38c4ff80e2a8bafa63579a0cb03026926cb4ad4ee44d2324d86842e119ac1c05  src/xml3_dom_allocation.ads
c25f8e859f3b568737e637ba9e1c8eb0238fcb83aa8de34a09cea35ab1b345aa  src/xml3_dom_bridge.adb
a62a5e86be7f9e74c7618d38a3210b4e31842d1cba5304ad3cf4efd7d32987b8  src/xml3_dom_bridge.ads
3333213c3cb868108c9294168e54ab081326649ea80447c569a52fd464b9f881  src/xml3_dom_constructors.adb
09ff151486509a88bccfa03febd237bbd90f228ca6b4219db4c2eb210c4f2fca  src/xml3_dom_constructors.ads
46fd9519a39976fcfbd0c9d8602b8e4f969e16547203f1022eb19718a862a2f8  src/xml3_dom_lock.adb
3010f199780bd3bc276580641cd87e54520e4bbaa1893c40b3b079b8e0439535  src/xml3_dom_lock.ads
804f1a3371bc434ce35784d7605c6a8153f401b55da2fbb8a49145a71bc42e1b  src/xml3_dom_mutex.c
a65b6deea3e577c01a5403a70a870610ecd9e015ffd58036f821d38247f42f8c  src/xml3_dom_runtime.adb
f39a2a0e922e9786eec316e0d6f8b0a97e021f698784308b0882dc6ff2aa601f  src/xml3_dom_runtime.ads
06b75e8e84b3e13640cc32e59bffe08729aa1393d8e05a40f4fbb8c39c4c66cf  src/xml3_dom_store-content.adb
012c7564561193975cc905af6a823dc52245d9506cf4cf388fae0606c556872a  src/xml3_dom_store-content.ads
7049538ece6d409cc138892870026f1216109b19baca4afe45a605160b9100e5  src/xml3_dom_store-documents.adb
6c52972b1a9bedcd5032918c0ae52efce069d7ab512555822beec7c833aae4c3  src/xml3_dom_store-documents.ads
bc71cab53c16e4f4b9bcc59ab5e2a83a0c33b1c4f8c44adbf768024acc3ebb2d  src/xml3_dom_store-properties.adb
4d598d091c912dbb6f909efd12fcd8fe556b51ff2fc02754d8b314aa61666750  src/xml3_dom_store-properties.ads
72b207939cdd77285e860704a65e4200b7d8050a7c22794d72b49f28cc0c1f5b  src/xml3_dom_store-queries.adb
ec83b494219adf3df84b4bcc01a4cbe10a295d5abc87dad2af0a4390eb254efd  src/xml3_dom_store-queries.ads
e17b9d6cf6d33b099ab68275cfc282f572a46cad0edc21e3e0703ad3c1413eb1  src/xml3_dom_store-serialization.adb
fcfa348242acf0dc69540b20063081c3f56b18960c984cfa9e8d3d649dbf0dc9  src/xml3_dom_store-serialization.ads
ea64a3ca261c74cb4c0472d38d0994846e64c76ffee67f0b887b9eb47d8e9974  src/xml3_dom_store.adb
d9b827c14c465ff57025dd6b2ef07326287abcb093ce0fde1f498ecfa136816b  src/xml3_dom_store.ads
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
b9336459d96b186963ec8decf600e7d016677c777c27b610b304fa923434c649  src/xml3_serialization.adb
4a3c84a0b7ee2b7b1a0129b63f37e36b1547c8e75152c7463e06d3f019d0f217  src/xml3_serialization.ads
07138e9a9c47e6ae18255e627b814b29f688e4e89b954913cdabf264d75b53c1  src/xml3_parser.ads
03db400b94fee27550077f76b8c113c2a3f61f9fdc6a484b59c165a759070c17  src/xml3_text.adb
0986b7098937b56d133aef1863ade9227314c7bd637730b39c6ef608c3969ac6  src/xml3_text.ads
5d6c4fd8bc49b3370b65d3f3d4bb212501772f52c29514adf02fcd41e65bd265  include/libxml/tree.h
d6755c4f335d6337fc4df01ead1260434f8eb2af2c8a15254d2a9cd90c635241  proof.gpr
5ad0affe7e6bcd3fbef62dae8cc27dbc3936a9a4485e4a34bddb65a054fc7431  libxml3.gpr
a79f548c6b0243cfca519ba992e6f35b5ff9187a31b82cb3f069250ed4804578  Makefile
c5269fafd0c1bab521ca0e18f279ed6c5dc7ef0b10151bb4c3618381984005b7  .github/workflows/manual.yml
```

A source or contract change invalidates this record until proof is rerun.
Solver percentages can vary without changing the obligations. The proof
assumes the compiler, translator, solvers and runtime model are sound;
resource exhaustion and foreign-memory behavior remain outside it.
