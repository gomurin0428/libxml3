# Assurance boundary

This project is an experimental, independent Ada/SPARK implementation, not a
release of GNOME libxml2. It is not yet a complete libxml2 replacement.

## URI path normalization

`xmlNormalizeURIPath` delegates to `XML3_Text.Buffers.Normalize_URI_Path`.
A bounded scan precedes any mutation; empty input is not written. SPARK tracks
input/output offsets and the number of removable ordinary segments, collapses
slashes, skips single-dot segments and rewinds output for parent segments.
It retains leading relative parents and anchors absolute paths at the root.
Unlike the reference, root detection is saved from the input's first byte,
not inferred from stale bytes at the current output position: `..//..` must
remain `../..`, not `../`, and `/../a` becomes `/a`.

The algorithm needs no heap allocation and only rewrites the existing span.
Success and NULL retain diagnostics; a scan-limit failure leaves the input
unchanged and reports diagnostic 115 through the adapter. This processes a
path, not a full URI or filesystem path: no percent/UTF-8 decoding, query or
fragment parsing, backslash conversion, symlink handling or sandbox guarantee.
Native readable/writable extents, stable input, byte values/effects, C ABI and
complete normalization semantics remain trusted, not formally proved.
GNATprove discharges 32 checks for `Normalize_URI_Path`, covering bounded
measurement, segment/output arithmetic, in-place copy preconditions, loop
termination and the status contract—not normalized byte equivalence or native
memory effects.
Tests cover reference behavior and explicit differences, idempotence, byte
values, guarded terminators, read-only empty input, URI decode/normalize/encode
reuse, no allocations and small scan limits before mutation.

## URI byte unescaping

`xmlURIUnescapeString` delegates to `XML3_Text.Buffers.Unescape_URI`.
SPARK bounds the input span, interprets hex through `URI_Hex`, chooses an owned
or caller-provided output and advances output by at most the consumed input.
Positive lengths include literal NUL bytes; nonpositive lengths use the bounded
terminator scan. Valid `%HH` becomes a raw byte, including `%00`; malformed
escapes and `+` remain literal. This is not URI/path, UTF-8 or XML validation.
The caller must validate decoded bytes as appropriate for their use.

Exact in-place decoding is allocation-free. Other nonempty provided targets
receive only the completed scratch result, preventing forward-overlap input
corruption and leaving targets unchanged on OOM. This intentionally allocates
where the reference need not; NULL targets return an independent `xmlFree`-owned
result, including for empty input. Input limits apply before allocation/writes;
NULL input does not touch the target or diagnostics. Success retains diagnostics.
Native bytes and effects, stable readable input extents, writable output extent
(decoded size plus one), copy/allocation/free and ABI are trusted. The public
interface has no target capacity parameter and cannot validate it. Contracts
cover status/result/target relationships, not full functional semantics.
GNATprove discharges 1 check for `URI_Hex` and 19 for `Unescape_URI`, covering
the helper's hex result range, bounded traversal, native-call preconditions
and status/result/target contracts—not decoded byte equivalence or native
memory effects.
Tests compare both hex cases and all byte values with the pinned reference,
include binary NULs, truncated spans, guarded extents, exact in-place and backward
overlap, safe forward overlap on libxml3 only, URI roundtrips, XML reuse,
small limits and OOM retry with unchanged targets.

## URI byte escaping

`xmlURIEscapeStr` dispatches directly to `XML3_Text.Buffers.Escape_URI`.
SPARK handles byte classification, lazy cached exception-list searches through
`Find_Byte`, bounded output measurement, exact allocation, percent images,
writing and failure cleanup. `URI_Image` contracts its width as 1 or 3;
`Escape_URI` contracts a non-NULL result only on success. The shared byte search
has an optional internal limit, leaving existing public searches unchanged.
GNATprove discharges 6 checks for `URI_Image`, 18 for `Escape_URI`, and 3 for
`Find_Byte`; these cover SPARK calculation, bounds and status/result
contracts, not native allocation or byte contents.
Small-limit tests exercise output expansion and incomplete exception searches;
the C tests compare all nonzero byte values with the fixed reference, cover
guard-page early stops, aliasing, independent ownership and XML reuse. Empty
and nonempty allocations have injected-failure/retry tests.

This is byte escaping, not URI, XML-character or UTF-8 validation. ASCII
alphanumerics and `-._~!*'()@` pass unchanged; exceptions can preserve any
nonzero byte. Others become uppercase `%HH`. NULL input returns NULL without
reading exceptions or changing diagnostics; empty input allocates an empty
string. Success does not clear existing diagnostics. Limits/OOM return NULL,
not a partial string, and do not modify or consume the input. The result is
freed with `xmlFree`. Callers must supply stable, readable native spans and
choose appropriate exceptions for their URI component. Native bytes,
allocation/free/write effects, pointer validity/extent, C ABI and full public
semantics are trusted, not proved. Full URI parsing/resolution are unsupported;
path-only normalization is provided separately.

## Intended proof claims

The four `valid.h` name-value predicates delegate directly from C to the
SPARK `XML3_Text.Buffers.Valid_Name_Value` / `Scan_Name` state machine, without a C-string copy.
It shares strict `Get_UTF8_Char` decoding and `XML3_Text.Name_Character` with
existing name validators. Single versus list modes and the pinned Nmtokens
leading-XML-blank/trailing-SPACE quirk are selected in SPARK; no DTD semantics
are claimed. NULL, empty, malformed input and scan-limit exhaustion return false
without allocation or diagnostics. The native source must remain readable through
the first rejected character or terminating NUL. Native byte effects and pointer
extents, C ABI, and complete lexical equivalence are not formally proved.

`xmlGetDocEntity` is a predefined-only query over the supported DTD-free document
subset. The C adapter supplies locking and diagnostics; SPARK
`XML3_DOM_Store.Queries.Get_Document_Entity` bypasses document lookup for NULL names,
otherwise checks `Registered_Document` before reading the name. The query uses
only input global state, does not allocate or mutate the DOM, and reuses the
bounded predefined lookup. Invalid documents return NULL with diagnostic 115;
successful and missing lookups preserve diagnostics. Returned static data does
not retain or depend on document ownership. Native name readability, record
layout/lifetime, C ABI, and full public semantics remain outside the proof.

`proof.gpr` includes complete specs/bodies of `XML3_Text`, `XML3_Text.Buffers`,
`XML3_Text.QNames`, `XML3_Parser`,
`XML3_Namespaces`, `XML3_Encoding`, `XML3_DOM`, `XML3_DOM_Bridge`,
`XML3_DOM_Constructors`, `XML3_DOM_Store`, its `Queries`, `Properties`, and
`Documents` and `Serialization` children, `XML3_Serialization`,
`XML3_DOM_Runtime`, `XML3_DOM.Import`, and
`XML3_DOM.Materialize`, plus
the trusted interfaces of `XML3_DOM_Allocation` and `XML3_Native_Memory`.
GNATprove must establish all generated flow and run-time checks and the written
contracts for those units.
The parser is iterative. Its statically bounded nesting stack holds at most
2,048 elements; the normal profile permits depth 256 and `XML_PARSE_HUGE` permits
2,048. There is no fixed whole-document byte cap or 2,048-node policy cap. Input
indices are bounded by `XML3_Text.Max_Bytes = Integer'Last - 16`, and node IDs by
half that representation bound. The parser/decoder core has no allocator, filesystem,
network, or callback access. The C adapter supplies bounded node/name arrays and
heap scratch buffers, grows the arena geometrically when the parser reports
`Arena_Exhausted`, and reparses; native allocation, pointer arithmetic, and
foreign-pointer validity remain trusted.

The recorded result is listed in [proof-report.md](proof-report.md). It covers
the parser/decoder, DOM, parser-arena materializer, and the Store/Runtime
operations used by public C APIs, including bounded content append, namespace
lookup through `Runtime.Search_Namespace` / `Store.Queries.Lookup_Namespace`,
namespace editing, `xmlTextMerge`, `xmlTextConcat`, `xmlNodeIsText`, and
`xmlIsBlankNode` through `Store.Queries.Test_Node`, previous/next sibling
insertion through `Runtime.Insert_Sibling` / `Store.Insert_Sibling`, inherited
`xml:lang` / `xml:space` lookup
through `Store.Queries.Get_Inherited_XML_Property` and mutation through
`Store.Properties.Set_Qualified_Property`, reverse element navigation through
`Store.Queries.Select_Element` (including `xmlGetLastChild`), detached
`xmlNewDocProp` construction through
`Runtime.New_Doc_Node` / `Store.Content.New_Doc_Node`, managed attribute
attachment through `Store.Add_Child` / `Store.Properties.Add_Property`, and
managed sibling insertion through `Runtime.Add_Sibling` / `Store.Add_Sibling`,
managed list release through `Runtime.Release_List` / `Store.Release_List`,
namespace-list traversal through
`Runtime.Get_Namespace_List` / `Store.Queries.Get_Namespace_List` /
`Collect_Namespaces`, namespace copying through `Runtime.Copy_Namespace` /
`Store.Copy_Namespace`, QName splitting through `XML3_Text.QNames.Locate_Prefix`
and `Split`, raw-string duplication and bounded native concatenation through
`XML3_Text.Buffers.Concatenate_Bytes` and `Copy_Byte_Prefix`,
fresh-allocation appending through `XML3_Text.Buffers.Append`,
QName building through `XML3_Text.QNames.Build`, raw substring search through
`XML3_Text.Buffers.Find_Substring`, raw slicing through
`XML3_Text.Buffers.Slice`, terminated byte comparisons through
`XML3_Text.Buffers.Compare_Terminated`, bounded special-character escaping
through `XML3_Text.Buffers.Escape_Special`, and explicit UTF-8, default-
encoding, and formatted memory serialization. Bounded `xmlGetNodePath`
traversal is analyzed through `Runtime.Get_Path` / `Store.Queries.Get_Path`;
it shares `XML3_Text.Buffers.Valid_Name` for strict UTF-8 XML-name validation.
The buffer helpers check bounded lengths, allocation sizing,
and call preconditions; native allocation and byte writes are trusted. The C
adapters, conversions, pointer validity and native ABI implementation are not
proved. The refreshed aggregate has 13,112 checks
(1,436 flow and 11,676 prover), no unproved or justified conditions, 0
`pragma Assume` statements, and 166 analyzer warnings. GNATprove failed to
generate representation information for the trusted `xml3_dom_allocation.ads`
package spec and continued with partial representation data; this caveat is
detailed in the proof report.
`xmlGetPredefinedEntity` is limited to exact names `lt`, `gt`, `amp`, `apos`, and `quot`.
It returns shared, read-only, borrowed entity records and name/content strings that remain
library-lifetime data; callers must not free, mutate, link, or pass them to managed-DOM editing
APIs. The lookup performs no allocation and does not implement DTD/general entities, external
entity loading, or editable entity nodes. The public enum and record declarations do not claim
support for those other entity kinds. The SPARK name/value mapping and bounded lookup logic are
covered separately, while native pointer readability, byte effects, layout, lifetime, C ABI, and
complete public C semantics remain trusted or unproved.
`xmlEncodeSpecialChars` routes through `Escape_Special_Bytes`, which directly
validates strict UTF-8/XML text, measures bounded expansion before allocation, and
emits the five supported replacements (<, >, &, double quote, and CR). It
retains apostrophe, LF, TAB, and valid Unicode; NULL is handled without a
diagnostic, empty input receives an allocated empty result, and invalid
UTF-8/XML is rejected rather than repaired or preserved. Tests cover exact
output, input preservation, output ownership, serialization round-trip,
invalid inputs, and OOM retry. GNATprove discharges 17 checks for
`Escape_Bytes_Pass` and 5 for `Escape_Special_Bytes`; the existing
String-based `Escape_Special` has 39 checks. `Escape_Bytes_Pass` is shared by
measurement and construction, stops at the first invalid unit, and bounds the write pass by the
measured allocation size. Failure frees any partial output. No C-string
materialization is used; `Special_Image`, `Character_Reference`, and `UTF8_Image`
remain shared primitives. The proof covers bounded arithmetic, native-call
preconditions and status/result contracts, not full C output semantics. Native
pointers/extents, byte effects, allocation/free, ABI/status
mapping, and complete libxml2 behavior remain trusted; the API is partial and
not-proved at the public C level, and does not implement DTD/entity expansion.
`xmlEncodeEntitiesReentrant` passes the native address through Store/Runtime.
Registered-document validation precedes all input reads; rejection does not
dereference the document or input. It then uses `Escape_Special_Bytes` with
`Non_ASCII => True, Quotes => False`, sharing bounded direct validation and
 construction with `xmlEncodeSpecialChars`, not C-string conversion. The Store
 query proves 3 checks and the Runtime wrapper 1. Less-than, greater-than and
ampersand use named references, CR becomes `&#13;`, and valid non-ASCII uses
uppercase hexadecimal references; quotes, TAB and LF remain literal. NULL
input bypasses document validation; otherwise only NULL or a registered
document is accepted. The shared helper provides strict UTF-8/XML validation
and bounded sizing. Output is independent, OOM returns NULL without DOM
mutation, and the source document encoding is not retained, so explicit UTF-8
documents can differ from reference output. Both scan and expansion caps map
to resource-limit diagnostic 114; invalid text/document maps to 115.
Public C NULL/diagnostic mapping, native pointer extents/stability and byte
effects, allocation/free, ABI, and complete libxml2 semantics
remain trusted; DTD/general-entity expansion and HTML behavior are unsupported.
The parser postcondition requires every output node's parent to precede it and
every name/value span to lie within the input, including well-defined empty spans.
UTF-8 text-decoder output never exceeds its input length. The UTF-16 decoder
measures its exact UTF-8 output length before allocation and checks bounded
conversion arithmetic and writes. Numeric reference arithmetic is checked
before multiplication. Termination of core `Parse`, text and UTF-16 decoding,
and namespace `Resolve` is proved with `Always_Terminates` and loop variants;
this does **not**
claim an end-to-end CPU-time or memory-use theorem.

The proof establishes SPARK run-time bounds, arithmetic safety, written
contracts, and termination for the selected core units. It does not prove
functional equivalence of UTF-8/UTF-16 behavior to libxml2, XML conformance, or
absence of vulnerabilities. Conversion-buffer allocation, pointer arithmetic,
and the FFI remain outside proof.

An accepted document contains one root element with balanced, matching tags.
That XML-language property is tested and reviewed, **not formally proved by the
present contracts**. UTF-8 and XML character correctness are likewise tested
functional properties; run-time safety is not a proof of XML conformance.
The namespace resolver's contracts bound local-name/prefix spans and binding IDs.
They do not formally establish that a binding is the correct in-scope namespace
or that all namespace well-formedness rules are satisfied.

Proof status and the exact invocation/toolchain must be recorded in the proof
report. Merely compiling SPARK code, passing tests, or having a proof target does
not constitute a completed proof. No `Assume`, suppressed run-time checks,
false-positive annotations, or excluded parser bodies may be used to make the
proof gate pass.

## SPARK-backed DOM and public C routing

`XML3_DOM` stores the actual logical node, namespace, and owner slots used by
its operations. Contracts cover bidirectional links, rank-based cycle prevention,
subtree document propagation, and owner reference counts equal to distinct live
node holds plus explicit reservations. Rejected attachments preserve graph data.
Unlinked nodes can pin a retired document's allocation; IDs are not reused before
release acknowledgement. Allocation failure handling and copying the backing
state are separated from the trusted state allocator. Atomic `Replace_Root`
preserves the old root's sibling position, propagates the incoming subtree's
document holds, and leaves the replaced root detached but live. Its fallible
checks run before topology changes; failure preserves the logical graph.
Public projection setters reject document changes inconsistent with the target's
parent or direct children/properties. The private pin-only setter is used during
the core's controlled subtree propagation, not exposed to callers.
`Merge_Text` validates a prepared content buffer's metadata and reserved owner,
rebinds the target's content hold, and retires the source atomically in the logical
graph. Failure leaves the graph unchanged. Actual concatenated bytes and their
allocation bounds are not modeled by this operation; the caller must prepare the
buffer and retain its reservation through the commit.
The source may be detached or attached under another parent in the same
document; this intentional move/append behavior does not require same-parent
adjacency.

`XML3_DOM_Bridge.Synchronize` consumes the core's projection/release protocol.
Its proved control flow projects nodes and namespaces before issuing a release,
then calls native free before acknowledging that release. This establishes the
protocol per owner ID, not an unconditional theorem about arbitrary C addresses.
The native integration test additionally checks real C fields, retained document
storage, preserved `_private`, and exactly-once frees for its tracked allocations.

`xmlNewDoc` passes its native version address through Runtime to
`Store.New_Document`. NULL uses the existing `1.0` String construction path;
non-NULL input is measured by SPARK `Measure` before Store allocation, then
copied directly into the shared node owner block. `Construct`/`Create_Node`
accept an optional native content source/length; its precondition forbids
simultaneous String content and requires `Has_Content`. Existing String callers
retain their default path. Checked sizing, terminator space, registration and
rollback are shared; no intermediate version String or extra allocation is
introduced. Empty and arbitrary raw version bytes remain supported; this does
not enable XML 1.1 parsing. Guard-page/reference tests cover independent version
storage and subsequent DOM/output/reparse use; OOM walks cover NULL, explicit
and empty versions plus retry. Native extents/stability, byte effects,
allocation/free, ABI and complete public semantics remain trusted.
GNATprove discharges 7 checks for `Store.New_Document`, 0 for the Runtime
wrapper, 9 for `Store.Construct`, 462 for `Create_Node`, and 22 for
`Allocate_Node_Buffer`; shared `Measure` proves 2 checks.

`XML3_DOM_Constructors.Create_Node` performs checked sizing, allocation,
including optional native-name spans for PI targets as well as native content.
The native-name case requires an empty String argument and records the measured
length in the existing projection contract. Buffer sizing and termination use
that effective length; existing String callers keep their previous path. The
PI entry point validates the document before measuring either target or content.
It does not add XML-name validation during creation. Guard-page/reference tests
protect shared target/content input, edit content without changing the target,
then serialize/free/reparse; empty-target OOM walks exercise retry and lifetime.
Native extents, source stability and byte-copy effects remain trusted. The
shared native-name path is covered by 12 checks for `New_Doc_Content_Bytes`,
462 for `Create_Node`, 22 for `Allocate_Node_Buffer`, and 2 for `Measure`.

`XML3_DOM_Constructors.Create_Node` shares
registration, implicit XML namespace setup, and synchronization. Before
registration, a failed native block may be freed directly; after registration,
rollback uses subtree retirement, reservation release, and the effect protocol.
The contract preserves all pre-existing live nodes on success and failure,
including when backing-state capacity grows. Raw string writes, offset addresses,
allocation freshness/non-overlap, and correspondence to native layout remain
trusted external-memory operations. Integration tests exercise successful
document/element/text construction, invalid namespace/kind rejection, native
malloc failure, and retained namespace/document storage after detachment.

`XML3_DOM_Store` owns a private limited backing state and composes those
operations with facade lookup and synchronization. Lookup checks the metadata
ID range, live state and exact facade equality; the native metadata read itself
still assumes a valid library pointer. The store reclaims its backing state only
after no logical owners remain. `Add_Child` attaches ordinary children or merges
adjacent text using a prepared NUL-terminated buffer whose owner reservation is
released before synchronization; a rejected merge buffer therefore follows the
existing release protocol. Tests cover allocation failure with unchanged views,
real facade/content updates, source-clear-before-free ordering, repeated-tail
no-op, and final Store reclamation. `XML3_DOM_Runtime` owns the one private
Store as SPARK abstract state. Public DOM wrappers serialize complete Runtime
calls with the trusted `XML3_DOM_Lock` guard; the C layer does not maintain a
parallel DOM graph. `xmlNewComment`, `xmlNewPI`, `xmlNewDocComment`,
`xmlNewDocPI`, `xmlNewDocText`, `xmlNewDocTextLen`, and `xmlNewCDataBlock`
share `Runtime.New_Doc_Content`, `Store.Content.New_Doc_Content_Bytes`, and the
existing `Store.Content.New_Doc_Content` ownership path, as do `xmlNewText` and
`xmlNewTextLen`. The C helper forwards the content address and bounded/terminated
mode, handles locking, status reporting and exceptions, and does not copy the
content. PI targets also use direct SPARK measurement/copy. The SPARK byte
entry point checks document registration before reading target/content, uses `Measure`
or `Measure_Byte_Prefix`, and passes the span into shared constructor storage.
NULL content skips all length checks/reads and retains a NULL content field;
non-NULL empty input gets independent NUL storage. Bounded negative/oversized
lengths are rejected before reads; zero length reads nothing. Missing unbounded
terminators and invalid arguments retain code115. The shared prefix scan is
also used by `Copy_Byte_Prefix` (`xmlCharStrndup`). Guard-page/reference tests
exercise all nine constructors, source protection before DOM/output/reparse,
and invalid document/content combinations; existing OOM walks retain retry and
document-first-release coverage. Foreign extents/stability, actual byte effects,
allocation/free, ABI and full API semantics remain trusted.
GNATprove discharges 12 checks for `New_Doc_Content_Bytes`, 1 for the Runtime
wrapper, 23 for shared `New_Doc_Content`, 14 for `Find_Registered_Node`, 6 for
`Measure_Byte_Prefix`, and 3 for `Copy_Byte_Prefix`; `Create_Node` and
`Allocate_Node_Buffer` prove 462 and 22 checks, respectively.

`xmlNewDocProp` adapter uses `Runtime.New_Doc_Node` and
`Store.Content.New_Doc_Node` with `Attribute_Mode`; it supports only detached,
unnamespaced attributes. A managed attribute can subsequently be attached to an
element by `xmlAddChild` under the same-document/documentless restriction.
Standalone attribute serialization is not supported. Its complete public C
semantics are not proved.
The `xmlNewDocProp` path uses the shared C `New_Container_Node` helper for
marshalling, locking, and status mapping; graph and owner decisions stay in SPARK.
The shared `Store.Content.New_Doc_Content` operation accepts text, CDATA,
comment, and PI nodes as well as empty element/attribute containers; it maintains
`Ready (S)`, relates the result address to `Created` status, and uses the
existing `Set_Node_Projection` invariant to set document affiliation and owner
pin. The core `Create_Node` postcondition specifically guarantees a null name
and zero name length for CDATA nodes. These contracts do not prove complete
public API semantics or rollback. Raw comment/PI/CDATA content is copied at
construction; lexical and UTF-8 validity and CDATA delimiter splitting are
checked by serialization rather than claimed by the constructor contract.
The CDATA bounded scan is in the trusted C boundary; guard-page tests are
runtime evidence for pointer handling, not a pointer-safety proof.

`xmlDocDumpMemory` delegates to `xmlDocDumpMemoryEnc` with NULL encoding; a NULL
encoding passed to `xmlDocDumpMemoryEnc` selects the same default mode. The two
format variants share the adapter and pass their scalar flag through Runtime
and Store into `XML3_Serialization.Render`. All four APIs reach the same
serializer. The unformatted APIs and `format=0` retain compact output; any
nonzero value, including a negative value, enables two-space indentation
capped at 60 spaces. Before descending, the SPARK traversal scans direct
children: Text or CDATA (including whitespace-only Text) suppresses inserted
whitespace for that entire element subtree, then formatting resumes for
following siblings. The DOM remains unchanged, although inserted output
whitespace reparses as Text.

Default mode omits the encoding declaration and emits non-ASCII scalar text,
attribute values, and namespace URIs as uppercase hexadecimal character
references. Names, comments, processing instructions, and CDATA retain raw
UTF-8. Explicit UTF-8 output remains supported, while an empty encoding name
is rejected. `Render` validates and measures immutable Store state before
allocation, then repeats the iterative traversal into an exact-size result.
GNATprove reports 1 check for Runtime `Dump_Memory_Encoding`, 7 for Store
`Serialization.Dump`, 3 each for `Read_UTF8_Name` and `Matches_UTF8_Byte`, 4
for `Is_UTF8`, and 9 for `Render`. Within `Render`, `Put_Character_Reference`
has 1 check, `Emit_Text` 17, and `Pass` 23. These checks do not prove native
pointer readability, complete C semantics, or libxml2 lexical equivalence.
Store validates the document by comparing registered
live facade addresses before inspecting encoding. `Read_UTF8_Name` reads at most
six native bytes, stopping at the first mismatch; its fixed five-character output
preserves the caller's case. It shares `Matches_UTF8_Byte` with the String-based
renderer check. NULL selects default encoding in SPARK; empty/unsupported names
fail without fallback. There is no C-string conversion on this path.
The C adapter passes pointers and scalar flags, initializes output slots, acquires the existing lock, maps
status/exceptions, and publishes the result. Native pointer extents/stability,
allocation, byte reads/writes, and mutex behavior remain
trusted. Source encoding and standalone metadata are not retained, so default
output does not restore the parsed source encoding. An empty document may
produce only the XML declaration. These units are included in the current
 successful 12,988-check aggregate proof; see [proof-report.md](proof-report.md)
for the command, result, and source hashes.

`Adopt_Arena` initializes an empty Store or performs overflow-checked growth for
nodes, namespaces and one owner before calling `Import.Adopt` exactly once.
Success synchronizes the destination and returns the imported document facade.
Failure preserves the complete source state and caller ownership; newly
initialized empty backing state is reclaimed with `Reclaim_Empty`. The native
source arena is never directly freed by adoption. Tests cover empty-Store,
map-allocation and growth-allocation failures, successful import and C facade
traversal, preservation of an existing document across a second import, and
detached-root lifetime through final Store cleanup.

`XML3_DOM_Store.Queries` adds internal, read-only element selection, property
lookup, namespace search, and content retrieval. Traversal uses Store node and
namespace IDs through `Node_View` and `Namespace_View`; it does not follow
native DOM links. Namespace scope is limited to element nodes, including when
queries originate from attribute values, and resolution errors remain
distinguishable from a normal no-match. `Get_Content` walks descendants in tree
order and returns a fresh NUL-terminated allocation owned by the caller, not the
Store. Regression tests cover mixed-document selection/property/namespace
results, default-namespace shadowing, a detached namespaced attribute value,
content ordering after a text move, and allocation failure followed by retry.
The Store unlink operation supports detaching attributes and is exposed through
`xmlUnlinkNode`. It updates property links while retaining document affiliation,
namespace references, content children and owner pins. Runtime delegates directly
to Store validation, with no native topology traversal in the C adapter. Public
tests cover middle/head/tail/sole-property unlink, repeat unlink, editing and
reattachment, namespace/document-first release, and no native allocation. Native byte comparison,
copying, allocation/free and address correspondence remain trusted boundary
operations. Public C getters route through these queries.

`Get_Namespace_List` performs a bounded two-pass traversal of managed node and
namespace IDs. The first pass counts visible declarations; the second writes
their borrowed facades into an exactly sized, caller-owned, NULL-terminated
array. List traversal uses declaration-only prefix resolution, so it does not
fall back to a node's namespace reference or synthesize the implicit `xml`
binding. It includes NULL/empty href declarations, deduplicates prefixes in
nearest-first order, and ignores the document argument. Store selection,
capacity checks, status and cleanup decisions are SPARK code; native address
allocation, array writes, pointer validity and the C ABI remain trusted. The
namespace pointers are borrowed and remain valid only while their owning node
is alive. Fixed-reference tests cover order, shadowing, NULL/empty hrefs,
element/text/attribute ancestry, and detach/reattach. Allocation failure and
document-first release are tested separately against libxml3.
Complete `xmlGetNsList` / `xmlGetNsListSafe` semantic equivalence is not proved.

`xmlAddSibling` resolves its reference node and incoming node through Store IDs,
rejects self-insertion and mixed attribute/content lists, then delegates to
`Store.Add_Child` using the reference node's managed parent. Text coalescing,
property replacement, document affiliation, and failure preservation reuse the
existing paths. Runtime is a passthrough; the C adapter shares only locking,
status and exception mapping with `xmlAddChild`, and reads no native DOM links.
Parentless sibling chains and children of attributes remain unsupported. Tests
cover append/reorder/merge and serialize/reparse, namespaced attribute replacement,
invalid and cross-document cases, document-first lifetime, and OOM retry.

`xmlAddPrevSibling` and `xmlAddNextSibling` are separate Store/Runtime operations:
Store resolves managed references once, then SPARK `Insert_Sibling` delegates
attachment, cycle, document affiliation, and pin changes to `Attach_Child`.
After attachment, a direct-tail placement relinks the affected endpoint nodes
once and shifts the affected suffix's `Sibling_Order` values monotonically.
The placement mapping preserves facade identity, owner and namespace snapshots,
document affiliation, pins, counts, capacity, marks, and node identity while
maintaining strict `Sibling_Order`; it sets the dirty effect and performs no
allocation. Attribute siblings, parentless lists, cycles, extra document roots,
and cross-document moves are rejected without graph changes; adjacent text is
not coalesced. The C adapter only selects the operation and shares locking,
status, and exception handling. Public C behavior remains partial / not-proved:
native pointers/layout, synchronization, allocator, ABI mapping, and full API
semantics are outside SPARK proof.
The direct-placement preservation contracts are included in the successful
full proof: `XML3_DOM.Insert_Sibling` proves 80 checks, `Store.Insert_Sibling`
proves 10, and `Runtime.Insert_Sibling` proves 1. This covers the written SPARK
contracts, not native pointer validity, ABI mapping, synchronization, allocator
behavior, or complete public C semantics.

`XML3_DOM_Store.Properties` adds internal namespace-free property creation and
replacement. Creation appends attributes, including duplicates; replacement
updates the first matching no-namespace attribute or creates one when absent.
Values are copied literally, with null values distinct from present empty
values. The implementation uses Store allocation, attachment, retirement and
synchronization operations; it does not traverse or mutate native DOM links.
Connected native tests cover literal bytes, duplicate attributes, allocation
rollback, null-versus-empty value children, and clearing the old value links
before its exactly-once native free. Public property APIs route through these
operations; C ABI conversion and facade projection remain trusted boundaries.

`xmlNodeAddContent` の分岐、末尾Textの選択、owner reservation、content projection、
attach/cleanup は SPARK Store/Runtime が管理します。C adapter は guarded Runtime 呼出し、
アドレス/長さ/モードの転送、戻り値変換に限定されます。既存の末尾 Text facade を保った
scalar replacement は新 buffer を登録・投影してから旧 buffer を同期解放します。
element/attribute に text child がない場合は SPARK が text node を作成して core の
`Attach_Child` に渡します。XML 構文の妥当性検査と escaping は serialization が担当します。
入力中の文字参照は解釈・展開せず、raw の `&` は出力時に escaping します。
`Find_Registered_Node` で登録を照合してから `Measure` / `Measure_Byte_Prefix` で計測し、
native spanを `Replace_Content` または既存の `Create_Node` に渡します。中間Stringは作らず、
新bufferへの旧本文とsuffixのコピーが完了してからpinを更新するため、自己aliasでも旧領域は先に解放しません。
このコピーの実byte効果・foreign extent/stability・ABIは引き続き信頼境界です。
GNATprove は `Store.Content.Append` 36 checks、`Replace_Content` 67 checks、
`Runtime.Add_Content` 1 check、`Store.Content.Set` 34 checks、
`Runtime.Set_Content` 1 check を証明します。

`xmlNodeSetContent` も node-kind 分岐、XML reference decoder、subtree retirement、
owner/pin lifetime は SPARK Store/Runtime に置きます。predefined/numeric references は
element/attribute setter 入力でのみ decode し、literal whitespace は保持します。
malformed/unknown references と不正 UTF-8/XML scalar は element/attribute setter で mutation
前に拒否します。scalar Text/CDATA/comment/PI の入力は raw のまま保持し、その検証は
serialization 時に行われます。raw input reference は serializer で展開されず、XML syntax
validation/escaping は serialization 時に行われます。new child は完全に準備して attach
した後に旧 children を namespace-aware に retire し、失敗では旧 tree を保ちます。
DTD/entity node types と namespace repair は未対応です。
setterのC境界もアドレス/長さ転送・mutex・診断変換だけです。登録照合の後にSPARKで
入力を計測し、scalarは追記と共通のnative span版 `Replace_Content` に直接渡します。
要素・属性だけに入力/復号バッファを用意し、旧子ノードの本文が入力でも読み終えてから退役します。

`xmlNewChild` は同じ Content/Runtime 層で namespace 継承、reference decoding、
新しい element/text の構築、接続と失敗時の後始末を行います。入力用 scratch は native
node を作る前に確保し、旧 parent への接続は準備完了後の最後に行います。C adapter は
文字列変換、NULL name の検査、mutex、結果・例外変換のみを担当します。Store 層の契約は
`Ready` と結果/status の整合性を保証し、API 全体の libxml2 等価性や rollback の完全な
意味論まで形式証明したという主張ではありません。

`xmlNewTextChild` は同じ Store operation の raw-content mode を使います。C adapter は
API に対応する mode と content が NULL かどうかを渡すだけで、raw copy と empty text の
作成判断は SPARK 側です。reference decoding はせず、XML/UTF-8 検査と escaping は出力時に
行います。NULL/empty の違い、literal reference の往復、出力拒否後の内容修復を検査します。

`xmlNodeSetContentLen` は `Runtime.Set_Content` へ元のアドレスと長さを渡し、Storeが
`Measure` / `Measure_Byte_Prefix` で計測します。長さ0は本文を読まず、負の長さはNUL終端です。
NULL本文は長さによらずNULLとして扱い、それ以外の過大な長さは本文を読まず拒否します。
未登録nodeも本文を読まず拒否します。guard page、入力保護後の出力・再読み込み・編集、
scalar自己aliasと退役する子の本文を使った置換を実行検査します。native pointerの可読性・
extent/stability・実byte効果・allocator/ABI・完全な公開意味論は形式証明外です。

`xmlNodeSetLang` / `xmlNodeSetSpacePreserve` は `Store.Properties.Set_XML_Property`
で要素の登録・種類を確認します。languageだけを `Measure` で計測し、SPARK内の入力Stringに
コピーして既存の `Set_Qualified_Property` へ渡します。NULL languageは空値の設定で、
削除ではありません。space modeは入力文字列を扱わず0→default、非0→preserveです。
既存のqualified-propertyの `Ready`・namespace保持・失敗時の巻き戻し経路を再利用します。
入力保護後の継承取得・出力・再読み込み、旧属性本文を入力にした更新、kind/登録検査での
読み取り回避は実行テストで確認し、native pointer/byte効果と完全な公開意味論は信頼境界です。
GNATprove は `Store.Properties.Set_XML_Property` 16 checks、
`Runtime.Set_XML_Property` 1 check を証明します。

`xmlNodeAddContentLen` もSPARKのbounded計測を使います。Store が長さとNULL入力から
空の入力を無操作として扱うか、空の text として扱うかを決めます。
接続・文字列結合・失敗時の保持は既存の Append operation を再利用し、`Ready` 契約は
維持しています。guard page、空の text の確保失敗と再試行、UTF-8 の分割追記から出力への
回復は実行テストの根拠であり、C pointer の読み取り安全性の形式証明ではありません。

`xmlNewTextLen` は bounded C string 変換から既存の Runtime/Store constructor を呼びます。
長さ指定は C 境界だけの変更で、新しい所有権処理や証明範囲は追加しません。非終端入力・
長さ 0 の guard page、NULL/空文字列の違い、接続と出力、確保失敗後の再試行を実行検査します。

`xmlNewDocText` / `xmlNewDocTextLen` の document 検査・所属設定・失敗時の未公開 text の解放は
Store.Content が行います。Store operation の契約は `Ready (S)` の維持と `Created` status /
非 NULL `Result` の対応を保証します。`Set_Node_Projection` の既存契約を使って document と
Doc_Pin を設定し、owner reference invariant を維持します。これは API 全体の意味論や完全な
rollback の証明ではありません。C 境界では文字列変換と Runtime 呼び出しだけを行い、bounded
pointer scan は証明外です。document なし・NULL/長さの振る舞い、無接続 text、文書検査、
serialization、文書先行解放後の編集・最後の text 解放、確保失敗時の既存 tree の保持は公開
API の実行テストで検査します。

`xmlStringGetNodeList` / `xmlStringLenGetNodeList` は deprecated な公開 API の限定実装です。
C adapter はアドレス/長さの転送、lock、Runtime dispatch、status mapping のみを行い、
`Store.Content.Parse_Content_List` が登録済み live document を入力読み取り前に確認し、
SPARK の `XML3_Text.Decode` から既存の `New_Doc_Content` へ接続します。predefined/numeric reference
を展開し、literal CR/LF/TAB は保持します。返却 text は detached で、document がある場合は既存の
Doc owner pin が寿命を保持します。NULL/empty は NULL、unknown/general entity reference と malformed
reference/invalid UTF-8/XML は失敗時に tree を変更せず拒否します。長さ 0 は byte を読まず NULL を返し、
固定版の先頭 byte read と empty-node quirk は再現しません。entity-reference node は subset 外です。
NULL入力・長さ0は文書照合も省略します。それ以外の不正文書は入力が空でもcode115で拒否します。
`Measure` / `Measure_Byte_Prefix` で走査し、SPARK内の入力/復号バッファから既存constructorへ渡します。
GNATprove は `Store.Content.Parse_Content_List` 16 checks、Runtime wrapper 1 check を証明します。
Store/decoder の書かれた契約は proof 範囲ですが、native pointer/byte validity、
allocation/copy、ABI、diagnostic delivery と完全な public semantics は信頼境界です。通常、Unicode、
reference、bounded input、guard-page、document lifetime、rollback は
`tests/content-edit-test.c`、OOM retry は `tests/oom-test.c`、宣言は `tests/header-smoke.cpp` で検査します。
`tests/serialization-test.c` は入力保護後の接続・出力・再読み込み・編集と、不正文書での
読み取り回避、NULL入力・長さ0での診断保持、走査上限を検査します。

`xmlNodeListGetRawString` は thin C adapter から Runtime の read-only query を呼び、
`Store.Queries.Get_List_Content` が登録済み開始 facade と bounded sibling walk を扱います。
Query は text/CDATA の raw bytes を一時文字列に連結し、`inLine != 0` では検証せず複製、
`inLine == 0` では各 node の content を結合前に個別に UTF-8 検証し、連結後に
XML 文字を検証して escape します。
descendant traversal や DOM mutation はなく、`doc` は未使用です。NULL list は NULL、選択内容のない
non-NULL list は独立した空文字列を返します。foreign facade は native metadata を読む前に拒否され、
entity-reference node は subset 外です。SPARK の proof は query の bounded walk、サイズ算術、status/result
契約を対象とします。C pointer readability、native byte reads/writes、allocation/copy/free、ABI と全 C semantics
は信頼境界です。raw byte preservation、escaping/invalid split-UTF-8、sibling selection、empty result、
foreign facade、OOM retry は `tests/dom-test.c` / `tests/oom-test.c`、宣言は
`tests/header-smoke.cpp` で検査します。

`xmlNodeListGetString` は同じ bounded sibling query を使います。inline mode は raw bytes を複製し
`doc` を無視します。escaped mode は NULL または登録済み document のみを受け入れ、開始 node の親から
attribute context を決定して各 node の UTF-8 を検証します。XML special characters は escape し、
attribute の tab/LF と CR/全非 ASCII は数値参照、attribute の quote は `&quot;`、
text の tab/LF/quote は raw のままです。
Document encoding は model に保持されないため、明示 UTF-8 document でも default encoding の数値参照を使います。
NULL list は NULL、選択 text のない non-NULL list は独立した空文字列です。返却値は独立した
`xmlFree` 所有文字列です。HTML/entity expansion は未対応です。Proof は SPARK query /
escaping contracts に限られ、native pointer/byte access, allocation/copy/free, ABI は信頼境界に残ります。
Escaping mode, doc validation/ignore, attribute context, default-encoding divergence, output lifetime は
`tests/dom-test.c`、allocation failure/retry は `tests/oom-test.c`、宣言は `tests/header-smoke.cpp` で検査します。
OOM は NULL として返り、source list links は変更しません。

`xmlNodeIsText` / `xmlIsBlankNode` は `Runtime.Test_Node` / `Store.Queries.Test_Node`
で kind と XML 空白を判定します。Runtime の `Global` は managed state / native memory
とも `Input` で、Store も読み取り専用です。管理中の content 長を走査上限とし、
失敗時は False を返す契約です。C は mutex・結果・例外の変換だけを担当します。
ネイティブ byte 読み取りの正しさは信頼境界に残り、完全な C API 意味論の証明ではありません。

`xmlIsXHTML` は `XML3_Text.Buffers.Is_XHTML` と bounded `Matches_Literal` により、
固定版の XHTML 1.0 public ID
`-//W3C//DTD XHTML 1.0 Strict//EN`, `-//W3C//DTD XHTML 1.0 Frameset//EN`,
`-//W3C//DTD XHTML 1.0 Transitional//EN` を先に、system URI
`http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd`,
`http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd`,
`http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd` を次に case-sensitive な
NUL 終端 byte 列として照合します。両引数 NULL のみ -1、その他は一致 1 / 不一致 0 です。
public ID 一致時に system ID は読みません。URI 解決・DTD 読み込み・HTML parsing・UTF-8 検証をせず、
allocation・diagnostic・lock・DOM access もありません。SPARK の byte-scan 契約と runtime
tests は native pointer validity、byte readability、C ABI、完全な upstream semantics を証明しません。

The eight deprecated `chvalid.h` function symbols use pure SPARK scalar
classifiers. `xmlIsChar` and `xmlIsBlank` retain the XML 1.0 Char ranges and
the exact XML blank set documented above. The historical `xmlIsDigit` set is
U+0030–0039, 0660–0669, 06F0–06F9, 0966–096F, 09E6–09EF, 0A66–0A6F,
0AE6–0AEF, 0B66–0B6F, 0BE7–0BEF, 0C66–0C6F, 0CE6–0CEF, 0D66–0D6F,
0E50–0E59, 0ED0–0ED9, 0F20–0F29; in particular U+0BE6 is excluded.
`xmlIsExtender` accepts only U+00B7, 02D0–02D1, 0387, 0640, 0E46, 0EC6,
3005, 3031–3035, 309D–309E, and 30FC–30FE.
`xmlIsIdeographic` accepts U+3007, 3021–3029, and 4E00–9FA5.
`xmlIsPubidChar` accepts SPACE, LF, CR, ASCII alphanumeric, and
`-'()+,./:=?;!*#@$_%`, but not TAB. These are fixed historical sets, not
locale or modern Unicode categories; all other values return 0, including
high unsigned values before narrowing when they exceed `Natural'Last`.
`xmlIsBaseChar` reproduces the pinned reference's 197 short ranges plus five
sub-U+0100 ranges, and excludes U+4E00; `xmlIsCombining` reproduces its 95
short ranges and excludes U+0346. These sets come from the pinned
`chvalid.h` / `codegen/ranges.inc`; they are not current NCName rules.
The legacy name classes do not affect current NCName validation (which
continues to accept U+037F, `a` followed by U+0346, U+0BE6, and U+9FA6).
The scalar classifier APIs perform no pointer or native range-table access,
allocation, locking, DOM access, or diagnostics. `xmlCharInRange` separately
reads only the selected caller-supplied short or long table, using the full
unsigned domain for long ranges and an overflow-safe lower-middle binary
search over inclusive endpoints. It returns 0 without a diagnostic for a NULL
group, nonpositive selected count, NULL selected table, or a count whose byte
span is not representable as `ptrdiff_t`; it does not read the unused table.
Tables must be caller-owned, readable, aligned, sorted, disjoint, and stable
during the call; full-table validation is not performed. Tests exercise the
generic oracle through U+110002 and unsigned boundaries, including guarded
single-entry arrays and inaccessible unused halves; they do not allocate a
physically enormous table. Global `xmlIs*Group` tables, header macros, and the
DTD subsystem remain unsupported. Foreign layout/pointer/extents/byte reads,
the C ABI, and complete upstream semantics remain trusted or outside proof.

`xmlReplaceNode` は Store の managed graph 操作として、同一文書内の node を old の位置へ
移し、old を切り離します。root replacement には既存の `Replace_Root` 契約を、通常の sibling
replacement には `Insert_Sibling` と `Unlink` の rollback/ownership 制約を再利用します。
このため別 parent に接続中または detached の同一文書 node、descendant-root promotion、
`cur == NULL`、隣接 text の非結合を扱えますが、
両方が attribute の置換、cross-document move、cycle、extra root は安全に拒否します。C 境界は
lock、Store/Runtime dispatch、status と native pointer の変換だけで、pointer validity、native
link projection、ABI、allocator/free、facade synchronization と complete public semantics は
trusted boundary に残り、public API の proof status は partial / not-proved です。

`xmlNodeGetLang` / `xmlNodeGetSpacePreserve` use the read-only
`Store.Queries.Get_Inherited_XML_Property` parent walk. Language returns a
caller-owned copy; space frees each temporary content copy and matches only
the exact `default` / `preserve` values. Kind checks, namespace filtering and
ancestor fallback are in SPARK. Setters route through the existing
`Store.Properties.Set_Qualified_Property` path for QName resolution and
rollback. The C adapter handles string conversion, locking, and status mapping.
Lookup/setter semantics, reparenting, serialization, copied-value lifetime,
and OOM rollback have runtime coverage; this does not prove the complete C
ABI, native pointer validity, or all public semantics.

`xmlTextConcat` の scalar kind 制限は `Store.Content.Append` で行い、空入力の
no-op 判定より先に検査します。内容の準備・pin 更新・確保失敗時の保持は既存の
`Replace_Content` 契約を再利用します。C はアドレス/長さ/モード転送・mutex・戻り値変換を共用し、
node をたどりません。新しい入口の全意味論を証明したという主張ではなく、kind・長さ・
NULL/空・alias・guard page・文書先行解放・出力・確保失敗後の再試行を C テストで検査します。

`xmlTextMerge` は `Runtime.Merge_Text` / `Store.Merge_Text` を通り、`Add_Child` の
text 結合と共通です。C は引数の受け渡し・mutex・エラー変換のみで、kind・文書所属・
容量・結合・解放判断は Store にあります。新しい content を準備してから既存の
`XML3_DOM.Merge_Text` で pin 更新と source の退役を行い、Bridge が公開構造体を同期します。
第二引数の content が NULL の場合は通常の `Release` を使い、target content は変えません。
Store の事後条件は `Ready`、成功時の返却 pointer と失敗時の NULL を規定します。完全な公開APIの
原子性・文字列意味論・C pointer validity を証明したという主張ではなく、確保失敗時の
内容・リンク保持、NULL/空の違い、属性内 text、文書先行解放は実行テストで検査します。

`xmlLastElementChild` / `xmlPreviousElementSibling` の kind 検査・後方リンク走査は
`Store.Queries.Select_Element` が実行します。既存の root/first/next 選択と C adapter を
共通化し、C は Runtime 呼び出し・mutex・status/exception 変換のみです。
走査は node 数で有界で、native field を C でたどりません。非 element のスキップ、
編集後の順序、無接続 tree の文書先行解放後の走査は実行テストで検査します。
「最も近い element を返す」完全な選択意味論までを契約で証明したという主張ではありません。

`xmlGetLastChild` は同じ Store/Runtime 選択処理の `Last_Child_Node` mode を使い、
kind で絞り込まず管理中の末尾 child facade を返します。文書と属性の値も対象です。
C adapter は共通の入口を呼ぶだけで、native `last` field は読みません。切り離し・再接続・
内容置換後の結果、文書先行解放後の利用、native allocation 不要を実行テストで検査します。
戻り値の完全な公開意味論や native pointer validity を証明したという主張ではありません。

`xmlFreeNodeList` / `xmlFreePropList` は `Runtime.Release_List` / `Store.Release_List`
を通り、管理中の `Next` を保存して既存の `Free_Subtree_With_Namespaces` を反復します。
反復は node 数で有界で、各段階の `Valid`・`Can_Edit`・`Facades_Present` を維持します。
最後に一度 `Synchronize` / `Reclaim_Empty` を実行します。C は単体解放と共通の
mutex・Runtime 呼び出し・status/exception 変換のみで、native の `next` は読みません。
接続済み suffix の安全な切り離し、再編集・出力・再読み込み、文書先行解放、名前空間の
残存利用者、native allocation 不要を実行テストで検査します。完全な一覧解放の意味論・
全原子性・native pointer validity を証明したという主張ではありません。

XML名の4つの公開validatorは、SPARKの `Text.Buffers.Validate_Name` / `Scan_Name` が
入力ポインタを直接走査し、XML空白・コロン・QNameのprefix/local・先頭文字を処理します。
`valid.h` の4つの字句検査と走査を共用し、非ASCIIの復号は `Get_UTF8_Char`、
文字分類は `Name_Character` に委ねます。C文字列のAdaコピーは行いません。
GlobalはForeign_MemoryのInputだけで、DOM・所有権・診断を変更しません。
NULLと判定不能な走査上限は-1、名前の不正は1、正常は0です。範囲・停止性・契約は
証明対象ですが、完全なXML名の意味論は記述しておらず、固定版比較・保護ページ・
小さい上限・QNameのコピー後の文書解放と再読み込みで検査します。
native pointer readability/extent、byte effects、C ABI、status写像は証明外です。

`xmlSplitQName2` / `xmlSplitQName3` は validation や namespace 解決ではなく、SPARK
`XML3_Text.QNames.Locate_Prefix` が入力を直接走査し、最初のcolonの次の1byteだけを
確認します。QName3はそのborrowed local suffixを返し、Cは成功時だけlengthを更新します。
QName2の `Split` は共通検索後に `Buffers.Measure` の開始offsetを指定し、元入力からの
上限を変えずlocalを計測します。既存の `Copy_Span` を共用してprefix/localをコピーし、
2つ目の確保失敗ではprefixを解放し両出力をNULLに保ちます。C文字列の中間コピーはなく、
走査上限はNULLと診断115、確保失敗はmemory診断へ写像します。通常は診断変更なしで、
分割不能とQName3の成功時は確保不要です。後続colon、空白、不正UTF-8はraw bytesのままです。
範囲・停止性・status契約は証明対象で、native pointer readability/extents、byte effects、
allocator/copy、pointer arithmetic、C ABI、完全な分割意味論はtrusted/unprovedです。
保護ページで先頭colon・NUL・最初のlocal byteで停止すること、借用先をコピーしてから
元入力を解放しDOMへ再利用する流れを固定版と比較します。OOM検査はlibxml3のみです。

`xmlBuildQName` は SPARK `XML3_Text.QNames.Build` で size bound、buffer selection、
result/status 契約を扱います（`Build` 18 checks、`Overlaps` 2 checks）。NULL prefix は borrowed original pointer、empty prefix は colon
を含む新しい値です。計測と構築は直接SPARKで行い、C文字列の中間コピーは不要です。
十分なcaller bufferが入力byteと重なる場合だけ一時領域へ構築して転送し、失敗ではbufferを
保持します。重ならなければ確保不要です。重複判定の差分演算もSPARK側に置き、nativeな
address-to-integer conversion、pointer validity/extents、allocation/free/byte effects、C ABI、
完全な公開意味論はtrusted/unprovedです。固定版とのoverlap equivalenceは主張しません。
`xmlStrQEqual` は SPARK `XML3_Text.QNames.Compare` で prefix/name/value の raw-byte
比較を行います。NULL prefix は `xmlStrEqual` 相当の NULL/NULL・同一 pointer equality を
保ち、非NULL prefix は prefix、colon、name を NUL まで比較します。空 prefix は name/value
を読まず常に Different です。これは pinned reference の空-prefix do/while が空 value の
terminator 後を読む unsafe path を意図的に除外した安全性差分であり、NUL-then-`:name` tail
の解釈も再現しません。guard-page と tail のケースは libxml3-only です。SPARK は status
初期化、null/pointer identity 契約、scalar loop の範囲を検査します。早い mismatch/identity
は返り、`Max_Bytes` scan cap を越える追加読取りが必要な equality は
`Comparison_Limit_Exceeded` として C 側で diagnostic plus 0 に写像されます。
scan cap は長い入力の一律拒否ではありません。Native
byte reads、foreign pointer validity/bounds、actual contents、address arithmetic、C mapping、
full public equivalence remain trusted. XML-name/UTF-8 validation is not performed.
The comparison itself allocates nothing and performs no writes.

`xmlNodeGetAttrValue` は既存 `Runtime.Get_Property` / `Store.Queries.Find_Property` /
`Get_Content` を再利用します。C の共通入口は文字列変換・mutex・status 変換のみで、
従来の `xmlGetProp` / `xmlGetNsProp` / `xmlGetNoNsProp` も同じ入口を通ります。
属性検索・内容のコピーはSPARK側のままで、新たな所有権モデルは追加していません。
戻り値と出力 pointer の C ABI 契約そのものは証明外で、固定版比較と確保失敗テストで検査します。

公開 namespace 検索は `Store.Queries.Lookup_Namespace` を通ります。native overloadは
nodeの登録確認後に `Measure` / `Read_String` でSPARK内の検索Stringを作り、C側の
変換を不要にします。NULL検索と空文字列は区別し、未登録nodeでは検索値を読みません。
guard page、shadowing、検索結果を使った出力・再読み込み・編集とimplicit XML宣言の
再利用は実行テストの根拠で、native可読性・extent/stability・byte効果・ABIは証明外です。
既存のString経路ではまず純粋な
`Search_Namespace` で検索し、必要な場合だけ最も近い文書なし element へ
`Store.Create_Namespace` で組み込み `xml` 宣言を追加します。未登録nodeは診断115を返し、
計測上限超過も従来どおり115です。通常の未検出は診断を変更しません。
属性更新内部では純粋な検索を維持し、更新失敗時の宣言の巻き戻し処理は変えていません。
固定版比較・作成失敗後の再試行・既存宣言の保持・再検索の確保不要を実行検査します。
GNATprove は native `Lookup_Namespace` overload で11 checks（1 warning）、
既存 String overload で13 checks、`Runtime.Search_Namespace` で1 checkを証明します。

`xmlNewDocNode` / `xmlNewDocRawNode` は `Runtime.New_Doc_Node` と
`Store.Content.New_Doc_Node` を通り、既存 `New_Child` も同じ未接続要素の作成処理を使います。
文書・namespace の保持は `New_Doc_Content`、text 子の接続は既存の `Attach`、
途中失敗での非公開ノードの解放は既存の `Release` が担当します。C 側は API 種別の
選択・アドレス転送・mutex・status/exception 変換だけを行い、`xmlNewNode` も共通経路です。
文書・親・namespace は登録表で照合してから名前・本文を計測します。
`Find_Registered_Namespace` はforeign memoryを読まず、`Construct` でも同じ照合を使います。
名前とraw本文は既存のnative span対応constructorへ渡し、参照展開時だけSPARK内で入力を
`Read_String` して既存の `Decode` を使います。`Construct_Container` が未接続containerと
text childの作成・接続・失敗時解放を共用します。native属性名でもcolon拒否を保ちます。
新しい Store operation の契約は `Ready` の保持と result/status の対応です。
GNATprove は `Find_Registered_Namespace` 14、`Store.Construct` 9、`New_Doc_Content` 23、
`Store.Content.New_Doc_Node` 18、`New_Child` 19、`Construct_Container` 14 checks を証明し、
Runtime の `New_Doc_Node` / `New_Child` wrappers は各1 checkです。
全公開API意味論や C pointer の有効性を証明したという主張ではありません。

`xmlNewDocProp` は同じ `Runtime.New_Doc_Node` / `Store.Content.New_Doc_Node` を
`Attribute_Mode` で使い、未接続・無namespaceの属性を作ります。文書所属と owner pin、
値の参照展開、text child の作成、失敗時の解放は SPARK 側にあります。NULL doc と
管理中の live document を受け入れ、文書先行解放後も属性は `xmlFreeProp` まで保持します。
NULL/空値は text child なしです。`xmlAddChild` では、文書未所属の属性、または接続先と
同じ文書に所属する属性を要素へ接続できます。既存属性とは local name と namespace href の expanded name で照合し、
接続成功後に一致属性を解放します。既に最後の属性なら重複があっても no-op です。
`xmlUnlinkNode` で属性を切り離した後も文書・namespace を保持し、編集・再接続・解放ができます。
namespace reconciliation と detached attribute の単独シリアライズは未対応です。
API 全体の意味論や C pointer validity を証明した主張ではありません。

`xmlNewCDataBlock` も共通の C `New_Content_Node` と SPARK
`New_Doc_Content_Bytes` から共有の `New_Doc_Content` を使います。SPARK側で non-NULL
content の負の長さを走査前に拒否し、bounded prefix を計測して直接コピーします。
NULL content は長さを問わず受け入れ、長さ 0 は pointer を読みません。
core `Create_Node` の postcondition は CDATA の `Name` が NULL、`Name_Length` が 0 であることを
保証します。これは限定された構造保証であり、API 全体の意味論証明ではありません。内容コピー、
CDATA delimiter の出力分割、serialize/reparse、無効 UTF-8 の拒否と修復、document 先行解放後の
編集・解放は実行テストで検査し、C pointer の validity は証明外です。

Namespace editing extends the same Store/Runtime path. Constructed declarations
own one explicit reservation; node namespace pins are accounted separately.
Cross-owner attachment requires that retained reservation, and core invariants
require a live owner with a positive reservation and at most one retaining
namespace per owner. Namespace-aware lookup uses URI plus local name. QName
parsing and UTF-8 NCName validation for `xmlSetProp` occur in SPARK, and
documentless XML namespace creation is rolled back if the attribute operation
fails. Namespace-aware subtree release detaches declaration links before
retiring element nodes and releases constructed declaration reservations while
preserving namespace owners still borrowed by live nodes. The C adapter remains
limited to guarded ABI/string/status conversion and does not decide ownership
or release. Namespace-edit core/bridge and public C regressions cover retention,
cross-owner borrowing, rollback, attribute identity, and allocation failure.

The ghost `Count_Holders` helper retains the recursive holder-count definition
with a bounded-result postcondition and decreasing variant. `Holder_Count`
delegates to it while stating the same recurrence through the helper, avoiding
a recursively evaluated wrapper postcondition. `Valid` and `Pin_Equation` are
unchanged.

`XML3_DOM.Import.Adopt` consumes a single-owner source state after installing its
arena into a destination with capacity already reserved. Sorted maps reuse
unused slots and translate links/pins while preserving existing live entries.
The native arena is not copied or freed; only the source Ada state and temporary
integer maps are deallocated. Failed preflight or map allocation preserves both
graphs. Direct `Import.Adopt` requires worst-case append capacity without credit
for reusable holes; `Store.Adopt_Arena` performs checked initialization/growth
around that requirement. Synchronizing the destination updates native metadata
before the imported facades are exposed.
The bridge clears namespace pointer fields when the core's
`Namespace_Release_Required` reports a releasing owner, in addition to clearing
retired nodes. Native tests cover capacity/allocation rollback, slot reuse,
remapped IDs, detached lifetime and clearing before exactly-once release.

`XML3_DOM.Materialize.Build` converts successful internal `Parse` and `Resolve`
output into a fresh candidate arena. It assigns IDs and constructs
ownership/topology in SPARK, uses checked string budgeting, and validates the
candidate with executable shared graph predicates. The proved `Check_Arena`
postcondition establishes `Valid`, editability, facade presence, arena
ownership, and projection requirement; parser/resolver range facts alone are
not treated as proof of arbitrary graph structure. A successful source is then
adopted once and synchronized through the destination bridge. The integration
test exercises this full internal sequence on the mixed parser sample, checks
12 nodes and 4 namespaces through C facade traversal, validates destination
preservation and remapped metadata, injects failure at all three allocation
stages, and checks invalid-binding rejection with exactly-once cleanup. It also
checks detached lifetime and final arena release.

The materializer distinguishes absent PI data from present-but-empty data
using the parsed target and value positions. The shared SPARK predicate
controls both arena budgeting and content construction: no-data PI content
remains NULL without reserving a terminator byte, while separator-only PI data
gets an owned empty string. No C-adapter or serializer special case is needed.

The materializer performs direct non-ghost construction and O(1) tail appends,
so its assembly work is linear in emitted nodes and namespaces. Assertion-enabled
ghost checks may be superlinear; no performance benchmark is claimed. Native
allocation/free, offsets, facade initialization, and byte/string writes remain
trusted primitives. The native layout/address correspondence is tested but not
proved. Ownership, graph topology, validation, release decisions, and policy
remain in SPARK.

`XML3_C` is an ABI adapter over `XML3_DOM_Runtime`. Parsing calls
`Documents.Read` with bounded C-allocated workspaces; constructors, queries,
mutation and release call typed Runtime operations. The adapter still performs
foreign pointer/string conversion and error translation and is not itself
formally proved. The Runtime delegates to proved Store operations; the public
API as a whole is not thereby claimed to be formally verified.

The adapter depends on `GNAT.Threads` to load GNAT's tasking runtime even
though the library creates no Ada tasks. On the supported Linux runtime,
foreign pthreads are registered automatically, giving each thread its own
secondary stack and exception state. A DOM mutex alone does not protect Ada
string conversions outside the locked Store operation. Foreign-thread
registration and runtime thread-local storage are trusted runtime services.

Native bodies remain trusted for pointer conversion, layout, allocation/free,
byte operations, metadata IDs and field writes. The caller of the foundation must
register addresses backed by the right live allocation, with unique owners and
non-overlapping facades, and ensure strings/ranges remain readable/writable.
These allocation/projection correspondence and address-uniqueness assumptions
are not established by the ID/reference-count equations. Native effect specs do
not model every C field or byte, so the bridge proof does not prove the native
body implements its projection command correctly. The C integration tests
exercise this correspondence without proving it for every layout or execution.

## Build profiles and executable contracts

The production library (`make build`, `lib/libxml3.so`) does not enable
`-gnata`: proof assertions, pre/postconditions, loop invariants, and ghost
computations are not dynamically evaluated. Explicit input/status checks and
Ada range checks remain enabled, with `-gnato` for integer overflow checks;
`-gnatp` is not used. Production uses `-O2`.

The development library (`make build-development`,
`lib/development/libxml3.so`) retains `-gnata` and `-gnato`. Its objects and
library are separate from production, so switching profiles cannot reuse
objects compiled under a different assertion policy. `make test-development`
runs focused public API regressions against this library. Global ghost
invariants can be extremely expensive; this profile is not a performance build.

`proof.gpr` and the Ada core/bridge test projects remain assertion-enabled and
independent of the library profile. No proof condition is removed or justified
by the production profile. A production test pass does not replace GNATprove
or development-profile testing, and neither profile proves the trusted boundary.

## Trusted / unproved boundary

* The Ada C-ABI adapter, C-compatible DOM object layout, allocations,
  deallocations, and foreign pointer/string conversions are outside SPARK.
  DOM topology, logical ownership, rollback and release decisions for exported
  wrappers are performed by proved Store/Runtime operations, not by the adapter.
  Callers must use these APIs rather than directly changing public tree links,
  and must not use a document handle after `xmlFreeDoc`.
* The pthread mutex and controlled Guard are trusted synchronization adapters;
  mutex correctness is not formally proved. Runtime calls are serialized, but
  asynchronous pthread cancellation and allocator callbacks that reenter the
  Runtime are unsupported. The libc allocator may itself use OS locks; no
  wait-free or deadline guarantee is made. Callers must synchronize concurrent
  access or release of borrowed facade pointers.
* `XML3_Native_Memory` and `XML3_DOM_Allocation` specs are analyzed, but their
  bodies are explicitly outside SPARK. The former performs no DOM traversal,
  ownership decision, or release scheduling; the latter only allocates/frees
  the Ada backing state and integer import maps. Their body correctness and foreign-memory assumptions
  are trusted, not discharged by the recorded proof result.
* `XML3_Errors` is also outside SPARK. Ada owns and copies error records and
  strings; the C shim provides only pthread TLS key access and thread-exit
  destructor dispatch. Allocator-failure tests exercise this boundary but do
  not prove it free of memory errors or exceptions.
* The C caller must supply readable input buffers of the declared length, valid
  NUL-terminated strings where required, and live handles created by this library.
  Use-after-free, forged pointers, double frees, and caller mutation of exposed
  structures are **not** made safe by the core proof.
* Compiler, Ada runtime, libc allocator, operating system, GNATprove/Why3 and SMT
  solvers are trusted. SPARK does not establish absence of `Storage_Error`.
* Side channels, application-level authorization, all possible denial-of-service
  attacks, thread races involving shared DOMs, and arbitrary environmental faults
  are not proved absent.

The defensive XML profile rejects DTDs and all declared/external entities. There
is no external resource resolver. This removes the external-entity and recursive
entity-expansion paths by design; it is not proof of security of an application
that subsequently interprets parsed text as a path, URL, command, or markup.

## Compatibility policy

The user-selected target is **C source/API compatibility with recompilation**,
not binary ABI compatibility or a replacement `libxml2.so.2`. The library uses its
own name, `libxml3`, and must not be loaded alongside libxml2 into the same symbol
namespace. Only APIs and structure fields explicitly listed in the compatibility
document are supported. The minimal DOM editor API includes `xmlNewDoc`,
`xmlNewNode`, `xmlNewText`, `xmlNewTextLen`, `xmlDocSetRootElement`,
`xmlAddChild`,
`xmlUnlinkNode`, `xmlFreeNode`, namespace APIs `xmlNewNs`, `xmlSetNs`,
`xmlFreeNs`, `xmlCopyNamespace`, `xmlNewNsProp`, `xmlSetNsProp`, `xmlUnsetNsProp`, and attribute
APIs `xmlNewProp`, `xmlSetProp`, `xmlUnsetProp`, `xmlRemoveProp`, and
`xmlFreeProp`. Attribute copying and cross-document moves remain deferred.
`xmlStrdup` and `xmlStrndup` copy raw bytes into `xmlFree`-owned,
NUL-terminated results; `xmlStrndup` copies exactly the requested length,
including embedded NUL bytes, and length zero does not read its input.
`xmlCharStrdup` delegates to the existing `xmlStrdup` adapter. `xmlCharStrndup`
uses SPARK `Copy_Byte_Prefix` and the shared `Copy_Span` allocator/copier:
it stops at NUL within `len`, while raw `xmlStrndup` copies the exact span.
`Copy_Byte_Prefix` proves 8 checks.
The other duplication adapters use `Concatenate_Bytes` directly. No C-string
conversion is needed in these APIs. Length zero performs no input read;
NULL/negative and over-`Max_Bytes` inputs
are rejected. Input bytes, including high-bit bytes, are copied without
transcoding or UTF-8 validation. The pinned reference allocates `len + 1`
even after an early NUL and leaves the tail unspecified; libxml3 allocates
only the copied prefix plus terminator. Tests compare defined contents only;
spare capacity and allocation-size equivalence are not promised. Native pointer
validity/extents, allocation/byte effects, ABI, and complete semantics remain
trusted.
`xmlStrchr` calls the SPARK `XML3_Text.Buffers.Find_Byte` search. It returns a
borrowed input pointer to the first matching non-NUL byte; NULL input and a
zero search value return no match without reading, and NUL terminates the scan
but is not itself searchable. The scan checks payload offsets below
`Max_Bytes` and allows a NUL at the boundary offset; if there is no match or
terminator by that boundary, the adapter records an error and returns NULL.
An early match in a longer string succeeds, so this is a no-match scan cap,
not rejection of every longer input. SPARK proves the bounded status/position
contract. `Native.Byte_At`, foreign pointer validity, readable bounds, actual
bytes, native address arithmetic, C diagnostic mapping, and complete public
semantics remain trusted. The operation allocates nothing and does not modify
or transcode the input.
`xmlStrstr` and `xmlStrcasestr` use `XML3_Text.Buffers.Find_Substring` and
return the first matching borrowed haystack pointer. NULL arguments return no
match; a non-NULL haystack with an empty needle returns position zero without
reading the haystack. NUL terminates both raw-byte inputs, so overlapping
haystack/pattern pointers, UTF-8 fragments, and invalid bytes are not converted
or validated. The case-insensitive operation uses the pinned byte map,
including the `[` to `{` quirk, not Unicode case folding. The scan permits
payload offsets below `Max_Bytes` and a boundary NUL; a match ending at that
boundary succeeds, while required non-NUL data beyond the cap maps to
`Search_Limit_Exceeded` and then diagnostic plus NULL. Early matches and empty
needles return without scanning the whole source, so the cap is not blanket
rejection of long strings. SPARK proves the status/position postcondition and
loop bounds. The borrowed pointer lifetime, native reads, foreign pointer
validity/bounds, actual bytes, address arithmetic, C mapping, and full public
semantics remain trusted. The operation allocates nothing and performs no
writes.
Shared substring vectors and guard-page cases run against both the pinned
reference and libxml3; OOM/no-allocation checks are libxml3-only.
`xmlStrsub` uses `XML3_Text.Buffers.Slice` to validate the start and copy an
exact raw-byte span into an independent `xmlFree`-owned allocation. NULL input
or negative indices return NULL without a diagnostic. The scan rejects a NUL at any position from
zero through `start`, including for zero-length slices; a valid zero-length
slice still allocates an empty string. It does not clamp the requested length
at a later NUL, so callers must provide a readable span of `len` bytes.
`start < Max_Bytes` and `len <= Max_Bytes - start` are checked before reading;
limit violations map to diagnostic plus NULL. SPARK proves the scalar
status/result contract, checked bounds and native-call preconditions. Pointer
validity, readable bounds and actual bytes, fresh allocation and writes,
address arithmetic, C mapping, and complete public semantics remain trusted.
No XML-name or UTF-8 validation or transcoding occurs. Shared slice vectors
and guard-page cases run against both the pinned reference and libxml3;
upper-cap and OOM checks are libxml3-only.
`xmlStrncmp` and `xmlStrncasecmp` use `XML3_Text.Buffers.Compare_Bounded` for
bounded byte-by-byte comparisons, early exit, and a result in -255 .. 255.
The scan accepts the full nonnegative C `int` bound without a `Max_Input`
cutoff, and may stop on an early mismatch or NUL.
`xmlStrncasecmp` retains the pinned byte map (`A`–`Z` plus `[` to `{`), a
reference quirk rather than Unicode case folding. The comparison allocates
nothing and performs no C-string conversion; actual native byte reads,
pointer validity, available memory bounds, and complete API semantics remain
trusted.
`xmlStrcmp`, `xmlStrEqual`, and `xmlStrcasecmp` share
`XML3_Text.Buffers.Compare_Terminated` / `Compare_Scan`. Identical-pointer
and NULL decisions occur without native reads; otherwise the scan checks
offsets 0 through `Max_Bytes`, stopping at the first mismatch or NUL. A
mismatch or NUL at the boundary completes the comparison. Equal non-NUL bytes
through the cap produce a diagnostic and `Limit_Exceeded`, with -1 returned
for `xmlStrcmp` / `xmlStrcasecmp`; that is not a trustworthy ordering result.
`xmlStrEqual` maps the diagnostic result to 0. The case map retains the
pinned `A`–`Z` and `[` to `{` behavior, not Unicode folding. SPARK proves
loop bounds, native-call preconditions, result range, and the cap-failure
contract; actual native reads, foreign-pointer validity/bounds/bytes, C
diagnostic mapping, and full API semantics remain trusted. The small-cap
boundary test passes a small `Last` to the Ada helper; no public C string near
the cap is dynamically constructed. Shared byte-pair and guard-page cases run
against libxml3 and the pinned reference; OOM/no-allocation checks are
libxml3-only.
`xmlStrlen` delegates to `XML3_Text.Buffers.Measure`, which handles NULL as
successful zero and otherwise uses the shared `Read_Length` scan through
`0..Last` inclusive. A NUL at the boundary is accepted; an unresolved scan
returns a failed status and zero length, which the C adapter maps to DOM error
115 and -1. Unexpected C-side exceptions map to DOM error 1 and -1 rather
than a silent zero. The `Max_Bytes` bound (`Integer'Last - 16`) is a
deliberate safe subset: unlike
the pinned reference's zero for lengths above `INT_MAX`, an over-cap scan is
diagnosed and must not be treated as an empty string. Tests exercise the
helper with reduced `Last` values instead of constructing an enormous public
C string. SPARK proves `Read_Length` (4 checks) and `Measure` (2 checks),
including scan bounds, result/status contracts, and the native read
precondition; actual bytes, foreign pointer validity/readable bounds,
C-side mapping/exception behavior, and full semantics remain trusted. No
allocation, mutation, transcoding, or UTF-8/XML validation occurs. Shared
raw-byte, UTF-8-byte-count, and guard-page vectors run against both
implementations; the no-allocation OOM-shim check is libxml3-only.
`xmlCheckUTF8` streams at most one UTF-8 scalar at a time using a four-byte
stack buffer and calls `XML3_Text.Validate_UTF8` with `XML_Only => False`.
It accepts ASCII control bytes and Unicode noncharacters as well-formed UTF-8,
while rejecting overlong encodings, surrogates, out-of-range scalars, malformed
and truncated sequences. This checks UTF-8 encoding, not XML character validity.
Existing XML parsing and name/content validation retain their XML-character
checks.
Unlike the pinned reference's permissive acceptance of noncanonical encodings,
the strict rejection is intentional. NULL returns 0, an empty string returns 1,
malformed input returns 0 without a diagnostic, and a scan unresolved through
`Max_Bytes` records error 115 and returns 0; unexpected exceptions map to
error 1 and 0. A NUL at the inclusive boundary is accepted. The operation
allocates nothing, mutates nothing, and does not transcode. Reduced-cap Ada
tests cover the scan limit; no enormous public C string is constructed.
GNATprove covers loop/index bounds and native-call preconditions, not actual
foreign bytes, pointer validity/readable bounds, C diagnostic mapping, or full
Unicode API semantics. Shared normal/malformed and guard-page tests compare
with the reference; expected noncanonical-input results differ deliberately,
and the no-allocation OOM test is libxml3-only.
`xmlUTF8Strndup` delegates through the C `UTF8_Str_Sub_Copy` adapter to
`XML3_Text.Buffers.Copy_UTF8_Slice` at scalar start zero, which finds the
position and delegates the selected prefix to `Copy_UTF8_Prefix` before
`Copy_Span` makes an independent NUL-terminated owned copy. NULL input or a
negative count returns NULL without reading, allocating, or recording a
diagnostic; a non-NULL zero count allocates an empty copy without reading input.
Positive counts stop at the requested scalar count or first NUL, leaving the
suffix unvalidated. A malformed, truncated, or noncanonical visited prefix
returns NULL before allocation with no partial copy or diagnostic. The result
is caller-owned and freed with `xmlFree`; input is neither mutated nor freed.
Unresolved scanning through `Max_Bytes` maps to error 115 and NULL, allocation
failure uses standard memory error 2, and unexpected exceptions map to error 1.
ASCII controls and Unicode noncharacters are valid UTF-8, not XML-character
validation; strict malformed-prefix rejection is an intentional difference
from unspecified/permissive invalid-reference behavior.
`xmlUTF8Strsub` uses `Copy_UTF8_Slice` to validate skipped scalars with
`Find_UTF8_Position`, then validate/copy only the selected prefix through
`Copy_UTF8_Prefix` and `Copy_Span`. NULL input and negative arguments return
NULL before input reads or allocation; an out-of-range start returns NULL.
Count zero still validates a positive skipped prefix but does not read the
target. Start zero/count zero performs no input read and returns a fresh empty
copy; starting at the scalar length returns an empty copy even for positive
count. The scan uses one global `Last` cap by passing the remaining cap after
the skipped prefix; it is not reset at the slice start. Malformed skipped or
selected input fails before allocation, while the unvisited tail is not
validated. Returned memory is an independent caller-owned copy; the input is
not modified or freed. The pinned reference can skip without checking
non-NUL continuation values, so strict checking of that prefix is an
intentional safety difference. Both UTF-8 adapters share C `Slice_Result`
status/diagnostic mapping; native bytes, readable/stable extents, pointer and
offset validity, allocator behavior, C ABI/mapping, and complete Unicode API
semantics remain trusted. `Copy_Span` and existing `Slice` prove 6 checks each,
`Copy_UTF8_Prefix` and `Copy_UTF8_Slice` prove 2 each, and
`Find_UTF8_Position` proves 1, in addition to the shared scan and measurement
checks. Reduced-`Last` Ada tests cover the global cap; no huge public C string
is constructed. Shared malformed/reference and guard-page vectors run against
both implementations, and OOM/no-allocation checks are libxml3-only.
`xmlGetUTF8Char` decodes one leading scalar with
`XML3_Text.Buffers.Get_UTF8_Char`, reading no more than the caller-provided
`*len` bytes. NULL input, NULL length pointer, or available length below one
returns -1; when writable, `len` is zeroed on failure. NUL decodes as code
point 0 with width 1, and ASCII controls and Unicode noncharacters are valid
UTF-8 scalars. Invalid, truncated, overlong, surrogate, out-of-range, and
unsupported lead bytes return -1 with width zero and no diagnostic. The C
adapter maps unexpected exceptions to DOM error 1, zero length, and -1.
Allocation, input mutation, transcoding, and XML character validation are absent.
The implementation deliberately rejects the pinned reference's F8..FF
lead-byte masking (for example, F8 90 80 80 and FC 80 80 80) and avoids its
read of `utf[0]` before checking `*len < 1`. GNATprove proves 12 checks for
`Get_UTF8_Char`, covering control/index/overflow safety, output width bounds,
and native-call preconditions, not complete Unicode-decoding semantics.
Pointer validity, readable extent, actual bytes, and C-side status/exception
mapping remain trusted. Shared vectors, permissive reference cases with
differing expectations, and exact-span guard-page tests run on both
implementations; zero-length unreadable-pointer and OOM/no-allocation tests
are libxml3-only.
`xmlUTF8Strlen` uses `XML3_Text.Buffers.Count_UTF8` to count Unicode scalar
values in a NUL-terminated UTF-8 string. It returns 0 for empty input, stops at
the first NUL, and returns -1 without a diagnostic for NULL or malformed,
truncated, overlong, surrogate, out-of-range, or otherwise noncanonical UTF-8.
ASCII controls and Unicode noncharacters are accepted as UTF-8, not validated
as XML characters. This counts scalars, not bytes or grapheme clusters, and
does not normalize text. The strict behavior deliberately differs from the
pinned reference's permissive treatment of some overlong, surrogate,
out-of-range encodings and of two consecutive continuation bytes as a scalar.
An unresolved scan through
`Max_Bytes` records error 115 and returns -1; unexpected exceptions map to
error 1 and -1. It performs no allocation, input mutation, or transcoding.
`Scan_UTF8` implements the shared bounded streaming scan.
`Count_UTF8` delegates to it, and `Check_UTF8` delegates to `Count_UTF8`,
preserving whole-string validity and cap behavior. `Measure_UTF8_Prefix` uses the same `Scan_UTF8` loop and
stops at the requested scalar count or first NUL. GNATprove proves 26 checks
for `Scan_UTF8`, 1 each for `Count_UTF8`, `Check_UTF8`, and
`Measure_UTF8_Prefix`, and 21 for `Validate_UTF8`. These cover scalar
counter/loop/index and byte-offset bounds, status/result contracts, and
native-call preconditions, not full Unicode semantics or actual foreign bytes.
Reduced-`Last` Ada tests exercise the cap; no huge public C string is
constructed. Pointer validity/readable extent, C mapping, and complete API
behavior remain trusted. Shared Unicode/reference and guard-page vectors run
against both implementations; no-allocation/OOM checks are libxml3-only.
`xmlUTF8Strpos` uses `XML3_Text.Buffers.Find_UTF8_Position` and the shared
`Scan_UTF8` helper to return a borrowed pointer to a zero-based Unicode scalar
position. It validates only the traversed prefix; position zero returns the
input without reading, and a target scalar or suffix is not read or validated.
At the exact scalar length it returns the NUL address without reading that
byte. NULL input, negative positions, positions beyond the end, or malformed
visited prefixes return NULL without a diagnostic. ASCII controls and Unicode
noncharacters are valid UTF-8, not XML-character validation. The strict prefix
scanner deliberately rejects overlongs, surrogates, out-of-range scalars, and
five-byte sequences accepted by the pinned reference. An unresolved prefix
through `Max_Bytes` records error 115; unexpected exceptions map to error 1.
There is no allocation, input mutation, or normalization, and returned pointers
must not be freed and are valid only while the input lives. Reduced-`Last` Ada
tests cover the cap; no huge public C string is constructed. GNATprove covers
scan control, scalar/offset bounds, status/result contracts, and native-call
preconditions, not full Unicode semantics, actual bytes, readable extent,
pointer validity, or C mapping. Shared reference-permissive and guard-page
vectors run against both implementations with differing expectations;
OOM/no-allocation checks are libxml3-only.
`xmlUTF8Strsize` returns the raw byte size of up to the requested number of
Unicode scalars, excluding the terminating NUL. NULL input or a nonpositive
count returns 0 without reading. A shorter string returns the bytes before
NUL; when the requested scalar count is reached, the scan stops before
inspecting the following scalar or suffix. A malformed, truncated, or
noncanonical strict UTF-8 prefix returns -1 without a partial size or
diagnostic. Reference behavior for invalid UTF-8 is not guaranteed; this
implementation explicitly rejects malformed visited prefixes. ASCII controls
and Unicode noncharacters are valid UTF-8, not XML-character validation.
Unresolved scanning through inclusive `Max_Bytes` maps to DOM error 115 and -1;
unexpected exceptions map to error 1 and -1. No allocation, input mutation, or
normalization occurs. Reduced-`Last` Ada tests cover the cap; no huge public C
string is constructed. GNATprove covers scan control, byte-offset bounds,
status/result contracts, and native-call preconditions, not full Unicode
semantics or actual foreign bytes. Pointer validity/readable extent, actual
bytes, and C mapping remain trusted. Shared malformed/reference and
guard-page vectors run against both implementations; OOM/no-allocation checks
are libxml3-only.
`xmlUTF8Size` is a lead-byte width classifier, not UTF-8 or XML validation.
For non-NULL input it reads only byte zero and does not inspect continuations,
truncation, scalar validity, or a NUL terminator; a single readable non-NUL-
terminated byte is sufficient. It returns 1 for `0x00..0x7f` (including NUL),
2 for `0xc2..0xdf`, 3 for `0xe0..0xef`, 4 for `0xf0..0xf4`, and -1 otherwise;
NULL returns -1 without a read. Thus isolated `0xe2` and the lead of
`0xed 0xa0 0x80` both return 3 without validating the sequence. Normal results
do not allocate, mutate input, or record diagnostics; unexpected exceptions
map to DOM error 1 and -1. The pinned reference also reads only the lead byte
but reports widths for invalid leads `0xc0..0xc1`, `0xf5..0xf7`, `0xf8..0xfb`,
`0xfc..0xfd`, and `0xfe`; this implementation intentionally rejects them.
Callers needing validation or decoding use `xmlCheckUTF8` or `xmlGetUTF8Char`.
`UTF8_Lead_Size` proves 2 checks for its result contract and native-call precondition, including
the result range and NULL case; proof does not establish the actual foreign
byte, readable extent, pointer validity, C mapping/ABI, or complete API
semantics. The guard-page loop places each of the 256 byte values at the final
readable byte before `PROT_NONE`; standalone non-terminated one-byte inputs and
no-allocation behavior are also tested.
`xmlCopyCharMultiByte` and `xmlCopyChar` are the only deprecated writer
declarations provided from `parserInternals.h`; the rest of that subsystem is
unsupported. They encode Unicode scalar values as 1–4 UTF-8 bytes, without an
extra NUL terminator (`U+0000` writes one literal NUL byte). `xmlCopyChar`
deliberately ignores `len`; it is not an output-capacity parameter, so callers
must provide enough writable, suitably aligned, stable output space. XML-
forbidden controls and noncharacters are encoded because these functions do
UTF-8 encoding, not XML character validation. Negative and out-of-range
values, surrogates, and NULL output return 0 without writes; surrogate
rejection is an intentional strict-UTF-8 safety difference. Ordinary success
and rejected-input paths allocate nothing, emit no diagnostic, and preserve a
sticky error. GNATprove proves `UTF8_Width` (1 check), `UTF8_Image` (25
checks), and `Write_UTF8_Char` (10 checks), covering scalar calculations,
loop/index bounds, and written contracts. These checks do not prove native
byte contents, destination validity/extent/stability, C ABI, or complete
upstream semantics. `Write_UTF8_Char` uses the existing trusted
`XML3_Native_Memory.Write_Byte`; exhaustive scalar round trips, sentinel and
guard-page cases, ignored-`len` values, and no-allocation/sticky-error behavior
are tested. Existing XML character and parser/name validation is unchanged.

`xmlUTF8Charcmp` uses `XML3_Text.Buffers.Compare_UTF8_Character`. Both NULL
pointers return 0; a NULL left or right pointer returns -1 or 1 respectively
without reading the non-NULL pointer. Otherwise the helper classifies only the
left lead byte, rejects an invalid lead before reading the right, then compares
at most that lead's width (1..4, with NUL width 1) as unsigned bytes. The first
nonzero byte difference returns immediately without decoding or validating
either complete sequence; for example, `E2 x` versus `E3 y` returns -1 and
`a` versus `0xff` returns -158 without a diagnostic. Only byte equality invokes
`Get_UTF8_Char` to validate the left first scalar before returning 0, including
same-pointer comparisons. Equal malformed, truncated, overlong, surrogate, or
out-of-range prefixes therefore report invalid and return -1, deliberately
differing from the pinned reference's 0. Valid first characters retain the
reference byte difference; suffixes are ignored. There is no case folding,
normalization, grapheme matching, or XML-character validation; controls and
noncharacters are valid UTF-8. The C adapter maps invalid input through
`Report_Dom_Error(9)` (`XML_FROM_TREE` / `XML_ERR_INVALID_CHAR`) and converts
the result; diagnostic-allocation failure may instead report standard OOM
error 2, while unexpected exceptions map to error 1 and -1. Comparisons
normally allocate nothing and do not mutate either input; invalid diagnostics
may allocate. Successful comparisons do not clear an earlier last error, so callers should reset and
inspect it when distinguishing a diagnosed -1 from a legitimate byte result.
There is no scan cap beyond the left character's maximum four bytes. Caller
memory must remain readable and stable through bytes accessed; an equal prefix
may require reading the complete first scalar or NUL even when pointers alias.
GNATprove proves 1 check for the helper's -255..255 result range and
`Invalid => -1` postcondition; it does not establish byte-order or complete
Unicode equivalence, actual foreign bytes, pointer validity/readable extent/
stability, or C ABI/error mapping. Tests cover the 169-pair valid-character matrix, first-scalar-only
behavior, early differences without diagnostics, malformed equal prefixes
against the reference, alias/distinct pointers, guard-page spans, and
diagnostic-allocation failure/retry.
`xmlUTF8Strloc` is implemented by `XML3_Text.Buffers.Find_UTF8_Character`.
It measures and copies at most the first pattern scalar into a local buffer,
then uses the shared `Scan_UTF8` loop, which validates each source scalar before
comparing it and returns the first match before advancing. Existing scanner
callers use the empty default pattern and retain their validation/counting
behavior. The C adapter maps status, scalar index, and diagnostics only. GNATprove
proves 6 checks for `Find_UTF8_Character` and 26 for the shared `Scan_UTF8`. The
result is a zero-based Unicode scalar index for the first occurrence of the
pattern's first scalar; later pattern bytes and source bytes after the match
are ignored. The first pattern scalar and each visited source scalar through
the match are strictly validated. NULL pointers return -1 without reading the
other pointer, and a malformed pattern is rejected before source access. The
empty-pattern compatibility quirk returns 0 for a nonempty source after
reading only byte zero, without validating that source; an empty source
returns -1. Ordinary outcomes allocate nothing, mutate no input, and record no
diagnostic. Inclusive `Max_Bytes` exhaustion maps to error 115 and -1;
unexpected exceptions map to error 1 and -1. Inputs must remain readable and
stable through the first pattern scalar and through the matched source scalar
or NUL; a matched scalar may end at a guard page without a terminator. Proof
covers scan control, scalar-index bounds, status/result contracts, and
native-call preconditions, not foreign bytes, pointer validity/readable
extent/stability, C ABI/mapping, or complete UTF-8/API semantics. Tests cover
malformed-reference differences, empty-pattern behavior, DOM lifetime,
exact-span guard cases, and no allocation.
`xmlStrncatNew` uses `XML3_Text.Buffers.Concatenate_Bytes` for direct bounded
measurement and copying without C-string conversion. It obtains the right
length first and measures the left under the remaining budget, rejecting a
too-large positive span before any reads. `Copy_Pair` is shared with
`Build_Append`, while input consumption remains exclusively in `Append`.
`Concatenate`/`Fits` remain for Ada `Duplicate`. Native pointer validity/extents,
allocation, byte effects, ABI and complete public semantics remain outside
proof; the SPARK contracts cover scalar bounds, native-call preconditions and
status/result relationships.
`xmlStrcat` and `xmlStrncat` use `XML3_Text.Buffers.Append`. `Read_Length`
checks the NUL-terminated right side; `Build_Append` applies the bounded right
length and current-prefix length, allocates a separate result, copies raw bytes,
and appends NUL; `Append` consumes and frees `cur` unless the status is
`Unchanged`. NULL `add` and `xmlStrncat` length zero are no-ops before negative
length handling. A negative bounded length with non-NULL `add` returns NULL
without a diagnostic and consumes `cur`. Positive bounded lengths copy exactly
the requested span, including embedded NUL. Cap failures return diagnostic
NULL and consume `cur` with DOM error 115; allocation failure uses the existing
OOM diagnostic and also consumes `cur`. A non-NULL empty `xmlStrcat` source is
a no-op for non-NULL `cur`, while NULL `cur` produces an owned empty buffer.
Callers must pass NULL or the base of a caller-owned `xmlFree`-compatible
allocation; literals and borrowed DOM pointers are invalid, and old `cur` must
not be used after a consuming call.
The fresh-allocation path avoids reallocating `cur` before reading an `add`
pointer that aliases it, including a raw suffix after an embedded NUL. This is
an intentional safety difference from the reference's realloc path; always
copying can increase peak memory and copy work. SPARK proves bounded length and
size arithmetic, native-call preconditions, and the status/result contract
(`Read_Length`: 4 checks, `Build_Append`: 6, `Concatenate_Bytes`: 6,
`Copy_Pair`: 9, `Append`: 1). Native allocation
freshness, actual reads/writes/free, pointer validity, correct caller
ownership, C diagnostics/mapping, and complete API semantics remain trusted.
Shared ordinary/null/empty/raw-span/negative/parse and guard-page cases run
against both the pinned reference and libxml3. Alias/self/raw-tail cases,
public cap rejection, and OOM/free-count checks are libxml3-only.
UTF-8 validity and complete API
equivalence are not proved; native pointers, allocation, byte writes, and C
conversion remain trusted boundaries.
`xmlNewNs` now forwards native href/prefix addresses into the analyzed
`Store.Create_Namespace` overload. It checks non-NULL element registration/kind
before measuring either input, copies measured spans into SPARK Strings and
reuses existing namespace allocation, duplicate-prefix, attachment and rollback
logic. NULL and empty fields remain distinct, including detached construction.
Guarded input, source protection, source-namespace release, serialization/reparse,
invalid-node read avoidance and OOM tests are execution evidence; native pointer
validity/extents/stability, byte effects, allocator/ABI and full API semantics
are not proved.
GNATprove proves 14 checks for the native Store overload and 0 for the
`Runtime.Create_Namespace` passthrough (the existing String overload proves 30).

`xmlCopyNamespace` resolves only managed live namespace facades, copies the
stored href/prefix spans independently while preserving NULL versus empty
fields, and omits source `next`, `context`, and `_private` links. Reservation
release and node pins are handled by the Store; foreign/stale pointers and
native representation/ABI remain trusted boundaries. `xmlDocDumpMemoryEnc`
supports explicit UTF-8 or NULL/default encoding, and `xmlDocDumpMemory`
selects the same default path; those two entrypoints use compact, unformatted
output. `xmlDocDumpFormatMemory` and `xmlDocDumpFormatMemoryEnc` provide the
bounded formatting behavior described above. DTD and file APIs are
unsupported. Unsupported
operations fail without silently creating invalid links. Unsupported parser
options fail, not silently degrade.

`xmlGetNodePath` resolves the incoming facade by scanning registered live Store
facades before reading its metadata; foreign, namespace, and unregistered
pointers are rejected without dereferencing them. Bounded Store traversal
validates node/namespace liveness and path-relevant parent, sibling, child, and
property links, validates local names/prefixes/PI targets with the shared
strict UTF-8 XML-name helper, and counts sibling occurrences by the selected
structural categories. It deliberately preserves the pinned reference's
default-namespace `*` wildcard and its equal-prefix/different-URI matching
quirk. Invalid names fail closed rather than copying malformed bytes.

Output is measured first, allocated as exactly the measured length plus NUL,
and emitted in a second bounded pass without an ancestor array or recursion.
An unsuccessful emission frees its partial buffer; the terminator is written
only after the emitted length equals the measured length. The returned path is
an independent native allocation suitable for `xmlFree`, and the DOM is not
mutated. SPARK can establish traversal bounds, checked size arithmetic,
occurrence/output control flow, and status/result contracts. GNATprove
discharges 8 checks for `Get_Path`, 17 for `Occurrence`, 7 for `Measure`,
14 for `Emit`, and 27 for `Write_Component`. It does not prove
native facade validity/readable extents, native allocation, byte copy/write or
free behavior, pointer arithmetic, C ABI/status/diagnostic mapping, or full
public libxml2 semantics. Consequently the API remains partial/not-proved at
the public C level.

`xmlGetLineNo` resolves a registered facade before reading its Store record.
The parser advances a monotone source cursor and records a capped line while
scanning bytes once; only LF advances the line, so standalone CR and the CR in
CRLF do not. This matches the fixed reference's harmless standalone-CR quirk,
while a decoded character-reference newline does not advance the source line.
Element lines are finalized after the opening tag. Parsed element/text/comment/PI
nodes retain their stored source positions through edits and moves, except that
a saturated 65535 result may use the bounded neighbor fallback.
`Source_Line` is internal only: no public struct field or direct-write API is
added. Constructed element/text/comment/PI nodes and synthetic attribute-value
text use line 0. Attribute and CDATA nodes use eligible previous-sibling or
element-parent fallback and can return -1 detached or inherit a different line
after a move. NULL, document, and unregistered facades return -1. The
five-node fallback is bounded and the 65535 cap remains in force;
`XML_PARSE_BIG_LINES` is not supported. GNATprove analyzes the parser scan and
Store query, but not C pointer arithmetic, native ABI, or complete public
semantics.

`xmlNodeSetName` resolves a registered facade before reading the proposed name,
rejects unsupported kinds before touching the caller buffer, and validates bounded
UTF-8/XML-name input in SPARK. Element and attribute names require NCNames;
processing-instruction targets permit XMLName syntax but reject case-insensitive
`xml`; unnamespaced `xmlns` and duplicate expanded attribute names are rejected.
The old name, value, links, namespace, and facade identity remain unchanged on
failure. A successful rename allocates and copies a distinct name owner, so later
content replacement cannot release the name; the existing owner-delta and bridge
synchronization machinery releases the old owner atomically. Attribute conflicts
fail closed rather than deleting an existing property. NULL and unsupported node
kinds are harmless no-ops, entity references are outside the managed subset, and
the complete public C behavior is not claimed. C remains a thin lock/status/ABI
adapter; pointer validity, readable extents, allocation, byte copying, and ABI
mapping remain trusted boundaries.

The current profile supports XML 1.0 UTF-8 and UTF-16LE/BE input, Unicode NCNames and qualified
element/attribute names, namespace declarations and read-only namespace lookup,
attributes, text, the five predefined entities, numeric references, comments,
CDATA and processing instructions. Normal resource ceilings are 50,000 bytes
per QName component/PI target, 10,000,000 decoded bytes per value, and depth
256. `XML_PARSE_HUGE` raises these to 10,000,000 bytes, 1,000,000,000 bytes, and
depth 2,048 respectively; it does not enable DTD, recovery, or other unsupported
features. The DOM is always UTF-8. UTF-16 input uses the length-taking
`xmlReadMemory`; `xmlReadDoc`/`xmlParseDoc` use the existing SPARK `Measure`
to find the first NUL, with inclusive bound `Max_Bytes`, and are not binary
UTF-16 entry points. Missing terminators within that bound return NULL before
parsing, without returning a partial length. The C adapter retains NULL-input
priority and ABI/error mapping; empty strings still reach the empty-document
diagnostic. The measurement allocates and copies nothing. Guard-page tests
compare first-NUL behavior and input-protection/DOM/output/reparse lifetimes
with the pinned reference; small-bound `Measure` tests exercise its limit.
Native input extents/stability, byte reads, ABI and complete parser behavior
remain outside proof. Names `UTF-8`/`UTF8`, `UTF-16`/`UTF16`, `UTF-16LE`, and
`UTF-16BE` are case-insensitive; generic UTF-16 selects little-endian. Explicit
encoding overrides the declaration while declaration grammar is still checked.
`Classify_Bytes` now classifies the explicit native encoding name directly,
sharing the six-name table with String `Classify`. It reads at most nine bytes,
stops when no candidate remains, and distinguishes NULL/Unspecified from
empty/unsupported input. C retains initial buffer/size validation and diagnostic
mapping, but no encoding-name scan or String conversion. Unsupported names
still report code 32 before XML input is read. Guard pages and reference-backed
alias/input-lifetime round trips exercise this path; native readability/stability,
byte effects, ABI, and full parser semantics remain outside the proof.
GNATprove reports 3 checks for `Classify_Bytes`; shared `Classify`,
`Equal_Name`, and `Upper` have 1, 5, and 1 checks. These checks do not establish
native pointer readability or byte effects.
Unknown explicit names fail rather than falling back. Auto-detected declaration
mismatches produce warning 113 on success. Malformed UTF-16 is rejected before
the parser at IO/code 81 and 1:1; later parser positions use decoded UTF-8
character columns. These are tested behaviors, not a proof of functional
encoding equivalence. These per-component/per-value thresholds are distinct from whole-input
and representation bounds. XML declarations accept version 1.0, the supported
UTF-8/UTF-16 encoding aliases, and standalone yes/no, in XML order. CR/CRLF line endings
are normalized, and literal attribute whitespace is normalized to spaces while
character references retain their referenced characters. Names follow the XML 1.0
fifth-edition ranges, without Unicode normalization. Invalid or unbound namespace
declarations fail closed, including cases where libxml2 may return a tree alongside
namespace errors. DTD, XInclude, XPath, schemas, HTML parsing, other encodings, and recovery mode
are not implemented. Rejection is an intentional compatibility gap, not a claim
those features are universally unsafe. Namespace acceptance semantics are tested
and reviewed, not fully established by the proof contracts.

Full libxml2 API and XML conformance remain development goals. Follow-on work must
extend the compatibility inventory and assurance boundary together, rather than
label unverified new features as already proved.

Compatibility tests do not authorize copying unsafe upstream defects. The
implementation follows harmless documented/observed quirks such as preserving
the last error after success, while refusing to emulate memory corruption,
invalid accesses, unsafe/unbounded resource use, or exploitable bugs for
differential equality. Any accepted difference is explicit; the pinned
reference's attribute/CDATA/PI near-limit lookahead behavior is measured, not
turned into an unexplained libxml3 safety limit.
