# SPARK proof evidence

## Result

`make prove` completed successfully for this source revision:
**11,256 checks, 978 by flow analysis and 10,278 by provers;
0 unproved, 0 justified**. The aggregate includes namespace editing through
Store/Runtime, retained namespace ownership, failure rollback, explicit UTF-8
memory serialization, `xmlNodeAddContent`, `xmlNodeAddContentLen`,
`xmlNodeSetContent`, `xmlTextMerge`, `xmlTextConcat`, `xmlNodeIsText`,
`xmlIsBlankNode`, `xmlNodeGetLang`, `xmlNodeGetSpacePreserve`,
`xmlNodeSetLang`, `xmlNodeSetSpacePreserve`,
`xmlNewChild`, `xmlNewTextChild`, `xmlNewDocText`, `xmlNewDocTextLen`,
`xmlNewDocComment`, `xmlNewDocPI`, `xmlNewDocNode`, `xmlNewDocRawNode`,
`xmlNewDocProp`, managed-attribute attachment through `xmlAddChild`, managed
attribute unlink through `xmlUnlinkNode`, managed sibling insertion through
`xmlAddSibling`, managed node/attribute list release through
`xmlFreeNodeList` / `xmlFreePropList` and `Runtime.Release_List` /
`Store.Release_List`, `xmlNewCDataBlock`, `xmlLastElementChild`,
`xmlPreviousElementSibling`, and `xmlGetLastChild` through the SPARK
Store/Runtime. The new `xmlNodeGetAttrValue` getter reuses the already-analyzed
`Runtime.Get_Property` / `Store.Queries.Find_Property` / `Get_Content` path;
its C status/output-pointer mapping is outside the proof. The public
`xmlValidateName`, `xmlValidateNCName`, `xmlValidateQName`, and
`xmlValidateNMToken` adapters call the analyzed pure `XML3_Text.Valid_Name`;
its character traversal, bounds, and termination are proved. C pointer
validity, string conversion, and return-code mapping remain outside the proof.
`xmlSplitQName2` and `xmlSplitQName3` use the analyzed
`XML3_Text.QNames.Prefix_Length` and `Split`: the proof covers first-colon
length bounds, output/status contracts, and split allocation/cleanup control
flow. Native allocation, copying/writes, C-string conversion, pointer
arithmetic, ABI mapping, and complete public semantics remain trusted or
outside proof. The Unicode comparison runs against the pinned reference and
libxml3; OOM injection is libxml3-only.
`xmlBuildQName` uses `XML3_Text.QNames.Build`, which proves the bounded output
size, buffer-selection branches, and result/status contract (15 checks).
Native allocation/writes, C-string conversion and pointer/ABI behavior remain
trusted; overlap safety is tested only for libxml3 and is not claimed as
reference equivalence.
Namespace searches through `xmlSearchNs` / `xmlSearchNsByHref` route through
`Runtime.Search_Namespace` / `Store.Queries.Lookup_Namespace`, which composes
the pure `Search_Namespace` query with lazy XML-binding creation for
documentless managed nodes. The pure query remains the qualified-property
rollback path. C adapters and libxml2 semantic equivalence, including
append-versus-prepend declaration ordering, remain outside the proof.
Namespace-list collection through `xmlGetNsList` / `xmlGetNsListSafe` routes
through `Runtime.Get_Namespace_List` / `Store.Queries.Get_Namespace_List` and
`Collect_Namespaces`. Its bounded two-pass Store traversal selects explicit
declarations from managed node ancestry, deduplicates prefixes nearest-first,
and excludes implicit bindings and namespace references that are not declared
in scope. It ignores `doc` and returns a caller-owned array of borrowed
namespace pointers. The SPARK proof includes traversal, capacity, status and
cleanup checks; native address allocation/writes, C array representation,
pointer validity, and complete public semantics remain outside the proof.
`xmlCopyNamespace` routes through `Runtime.Copy_Namespace` /
`Store.Copy_Namespace`: the Store resolves a live managed namespace facade,
copies stored href/prefix byte spans independently while preserving NULL versus
empty fields, then delegates detached reservation creation to the existing
constructor. Source `next`, `context`, and `_private` fields are omitted.
Proof covers Store identity, span selection, status/result contracts, and
constructor control flow; native reads/writes and allocation, C/native pointer
validity and layout, ABI details, and complete public semantics remain outside.
Reference comparison covers returned namespace values and links; the
node-pin-lifetime scenario and OOM injection are libxml3-only tests.
The QName proof includes 15 checks for `Build`, 10 for `Prefix_Length`, and 13
for `Split`. The entity
summaries report 0 flow errors, 136 warnings, and 0 `pragma Assume`
statements; warnings are not counted as discharged verification conditions.

**Analyzer caveat:** generation of representation information for the trusted
`xml3_dom_allocation.ads` spec failed (`cannot generate code for file ...
(package spec)`); GNATprove continued with partial representation data. This
warning is not resolved by the successful proof. Native representation/layout
is outside the claim. One additional benign warning reports that the
initialization of `Existing` in `Store.Properties.Add_Property` has no effect,
because `Find_Matching_Property` initializes that `out` parameter before use.
Trusted external-termination warnings also remain. The namespace-list,
namespace-copy, and QName paths include trusted termination diagnostics for
native reads, allocation, writes and frees; an unreachable/no-effect diagnostic also remains for the
portable pointer-array size guard on this 64-bit host.

The unedited analyzer summary is in [proof-summary.txt](proof-summary.txt).
This is a proof of the selected SPARK units and their written contracts, not
of the entire C ABI, native memory layout, synchronization implementation, or
full XML conformance. Public DOM APIs now delegate to the SPARK Store/Runtime;
the adapter and the native boundary remain trusted. See [assurance.md](assurance.md).

| Category | Checks |
| --- | ---: |
| Data dependencies | 268 |
| Initialization | 564 |
| Runtime checks | 5,047 |
| Assertions | 1,486 |
| Functional contracts | 3,690 |
| Termination | 201 |
| **Total** | **11,256** |

The analyzer's counts are verification conditions, not vulnerabilities, test
cases, or supported APIs. `Parse`, `Decode`, namespace `Resolve`, and
`Decode_UTF16` have explicit `Always_Terminates` aspects; the implicit
termination of `XML3_Text.Valid_Name` is also proved from its loop variants.
Termination is not a wall-clock or resource bound.

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

`xmlNewDocProp` uses `Runtime.New_Doc_Node` / `Store.Content.New_Doc_Node`
with the attribute mode to create a detached, unnamespaced property. The SPARK
path owns document affiliation, value-reference decoding, child construction,
and failure cleanup; the C adapter selects the mode, converts inputs, locks,
and maps statuses/errors without traversing DOM fields.
The tested NULL/empty behavior, document-first attribute lifetime, rejected
invalid references/names, and OOM preservation are runtime evidence. Managed
attributes can be attached to an element through `xmlAddChild`, subject to the
same-document/documentless restriction; the API's complete C semantics, native
pointer validity, and ABI are not formally proved.

`Store.Add_Child` dispatches managed attributes to
`Store.Properties.Add_Property`; `Store.Queries.Find_Matching_Property` compares
local-name bytes and namespace-href bytes. A null namespace is distinct from a
namespace object, and a non-null namespace with a null href is rejected.
Re-adding the parent's last attribute is a no-op even when an earlier duplicate
exists. Otherwise the matching attribute is released only after the incoming
attribute attaches successfully. Core attachment still rejects cross-document
moves, preserving both attributes. `xmlUnlinkNode` also supports detaching a
managed attribute while retaining its value, document affiliation, namespace,
and owner pin. Namespace reconciliation and detached-attribute serialization
remain unsupported. These Store checks do not establish full public C semantics
or native-boundary safety.

`xmlAddSibling` delegates from the shared C `Add_Node` adapter through
`Runtime.Add_Sibling` to `Store.Add_Sibling`. The Store resolves both managed
facades, rejects self-insertion and attribute/content kind mismatches, requires
a live managed parent, and delegates to `Store.Add_Child`. The aggregate
includes the Store/Runtime path, but does not prove full public C semantics,
native links or ABI, mutex behavior, or pointer validity. Pinned-reference
tests cover supported append/reorder, tail no-op, text coalescing, and
expanded-name attribute replacement; safety and lifetime extensions are
library-only runtime tests.

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

`xmlGetLastChild` uses the same `Select_Element` Store/Runtime path with
`Last_Child_Node` mode. Store resolves the facade and returns its live managed
last child without filtering node kind; the C adapter uses the shared selector
and reads no native `last` field. Document children and attribute-value text
are included. Runtime tests cover node kinds, empty and unsupported inputs,
unlink/reappend and replacement, detached-tree lifetime, and zero native
allocations. The aggregate includes the SPARK selection unit and its written
contracts, not complete public API semantics or native pointer validity.

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
6e242f1a2746d9181c3791a81c6fc56ec85123c513501f9c0426fc8bad5b2b16  src/xml3_c.adb
078aefe74f2234842c10110266228cb427bf4ea88dd88014d067870f5233cf6d  src/xml3_c.ads
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
95fef55f9dfb947de58bdb884f5ea880de310ccc2bdfb3c6984faf8ed1a9993f  src/xml3_dom_runtime.adb
1ac683b979febbff4ca21a5ca25cb07905d2c2a1a31f75fc775cd90a64a5715c  src/xml3_dom_runtime.ads
f9c7438289d0717f90f1d6071f749634fce8e044f8459acf7ddf4bcce6cb8877  src/xml3_dom_store-content.adb
a16b8f43764756e90a3574516189f58b863538d01519931cdc016a7387447fd6  src/xml3_dom_store-content.ads
7049538ece6d409cc138892870026f1216109b19baca4afe45a605160b9100e5  src/xml3_dom_store-documents.adb
6c52972b1a9bedcd5032918c0ae52efce069d7ab512555822beec7c833aae4c3  src/xml3_dom_store-documents.ads
2c5f2910bde31cda9af6496a4760dfbfeb3db5b7b50f606340bc915a569b92f6  src/xml3_dom_store-properties.adb
75b21d6feaa1e9f26f08ece87e33f4b46f7f9b4c9311d60a130d03701a91aabb  src/xml3_dom_store-properties.ads
0f46d1fe25d0fd4d853d49cea43cc5cf0a783eb1e6244f1b057dbc6e12a98ef1  src/xml3_dom_store-queries.adb
62a887d71e298c5597b018f85ee46ac7d359e0b4a11954667292312121d04589  src/xml3_dom_store-queries.ads
e17b9d6cf6d33b099ab68275cfc282f572a46cad0edc21e3e0703ad3c1413eb1  src/xml3_dom_store-serialization.adb
fcfa348242acf0dc69540b20063081c3f56b18960c984cfa9e8d3d649dbf0dc9  src/xml3_dom_store-serialization.ads
7b4b499f4e7cef3a6300d18a664fda6c2d9a2d9592a8bcdfbaf6cbdcc0311fc9  src/xml3_dom_store.adb
5159e676a13e788d010e8bc314b436c3973fb506ebe966fd89e1851c679ca6a2  src/xml3_dom_store.ads
7a7d9e2c073d9619dfe9e2945e8454ba957e9e8fd7da915d91cf724a9d2542af  src/xml3_encoding.adb
095e4c527eced72f9fe7d7cf91f4fe637358beb094a53b9bde84bf3c2f6a904d  src/xml3_encoding.ads
53fed6a5a3374aa4f67ff6865a0d703274f89bfd44f036285a2166a31d843cfe  src/xml3_error_tls.c
ea5fb0d9851f8262d8ced6e2b2d4319125ed28dbc93c1deedf308823214b6d01  src/xml3_errors.adb
bc9416be82db99c3e992e91890de4024179f16fec29b3685b905212913d0a2c3  src/xml3_errors.ads
09734ebf88516572b7fbd7dc1b023316755d8ab156d7fcce58e2c785c0ec219f  src/xml3_namespaces.adb
055155bfd5a5e8b1c55cba12d27739810c9e70c6e3bb979f2aee07d4e9372831  src/xml3_namespaces.ads
802bbc0d3a2ad887e38814c149d3e63d5f0ace9952c0a54821399164143e2fcb  src/xml3_native_memory.adb
4aa72f5756913f1f58af134cf221972157f672054e1df4c3f64dd6e4432b3a56  src/xml3_native_memory.ads
2e31dde2f0ae750a8af15781b4d22bac59e14b388344c49a9a087021d7883f92  src/xml3_parser.adb
b9336459d96b186963ec8decf600e7d016677c777c27b610b304fa923434c649  src/xml3_serialization.adb
4a3c84a0b7ee2b7b1a0129b63f37e36b1547c8e75152c7463e06d3f019d0f217  src/xml3_serialization.ads
07138e9a9c47e6ae18255e627b814b29f688e4e89b954913cdabf264d75b53c1  src/xml3_parser.ads
0540786136c12dbfd2829c2f46a43a0f6a8f6be7ed117f54116c91c8cf6aa631  src/xml3_text.adb
fc4315bcae6aad4d1e078c869bf84d625661ad100e4ec33100b59a18c1f763ad  src/xml3_text.ads
e4c98a402db869f045241cec3ef3ef05ffa7390624acb7c1123b382e29b8c12a  src/xml3_text-qnames.adb
7c0b1f7e4ca6a68ac438599b328d39543964baba74bc2d97a54832cbc1694a0e  src/xml3_text-qnames.ads
f34d351a12e61e5addb9f17b70da9d4230de23d2e10ca1f31e5dcdcb0e822a2d  include/libxml/tree.h
cb57263fefe70df4f5af98a8ea2055acd85c1b1cd727d8a00014214f1291552b  proof.gpr
5ad0affe7e6bcd3fbef62dae8cc27dbc3936a9a4485e4a34bddb65a054fc7431  libxml3.gpr
89af87374354f8f1c6b6b4a1890cd1b982a1b22befae7c794cf1ce918da228a2  Makefile
c5269fafd0c1bab521ca0e18f279ed6c5dc7ef0b10151bb4c3618381984005b7  .github/workflows/manual.yml
```

A source or contract change invalidates this record until proof is rerun.
Solver percentages can vary without changing the obligations. The proof
assumes the compiler, translator, solvers and runtime model are sound;
resource exhaustion and foreign-memory behavior remain outside it.
