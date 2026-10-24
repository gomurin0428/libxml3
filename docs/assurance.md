# Assurance boundary

This project is an experimental, independent Ada/SPARK implementation, not a
release of GNOME libxml2. It is not yet a complete libxml2 replacement.

## Intended proof claims

`proof.gpr` includes complete specs/bodies of `XML3_Text`, `XML3_Parser`,
`XML3_Namespaces`, `XML3_Encoding`, `XML3_DOM`, and `XML3_DOM_Bridge`, plus
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
`Arena_Exhausted`, and reparses; adapter allocation, pointer arithmetic, and
ownership remain outside the proof scope.

The recorded result is listed in [proof-report.md](proof-report.md). It covers
the new DOM foundation as well as the parser/decoder, but not the C adapter.
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

## DOM foundation: not yet the public C implementation

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

**`XML3_C` has not been connected to this foundation.** Its parser materialization,
DOM editing/ownership, root replacement and text merging remain the old unproved
implementation. The new kernel and integration test are not a substitute for
migrating those exported entry points. No public C API is newly classified as
proved by this change.

Native bodies remain trusted for pointer conversion, layout, allocation/free,
byte operations, metadata IDs and field writes. The caller of the foundation must
register addresses backed by the right live allocation, with unique owners and
non-overlapping facades, and ensure strings/ranges remain readable/writable.
These allocation/projection correspondence and address-uniqueness assumptions
are not established by the ID/reference-count equations. Native effect specs do
not model every C field or byte, so the bridge proof does not prove the native
body implements its projection command correctly. The C integration tests
exercise this correspondence without proving it for every layout or execution.

## Trusted / unproved boundary

* The Ada C-ABI adapter, C-compatible DOM objects, allocations, deallocations,
  reference ownership, and foreign pointer conversions are outside SPARK.
  This includes the DOM constructors, child and attribute mutation/free operations;
  their ownership and structural behavior is tested in C but is not formally proved.
  Callers must use these APIs rather than directly changing public tree links,
  and must not use a document handle after `xmlFreeDoc`.
* `XML3_Native_Memory` and `XML3_DOM_Allocation` specs are analyzed, but their
  bodies are explicitly outside SPARK. The former performs no DOM traversal,
  ownership decision, or release scheduling; the latter only allocates/frees
  the Ada backing state. Their body correctness and foreign-memory assumptions
  are trusted, not discharged by the 3,790-check result.
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
`xmlNewNode`, `xmlNewText`, `xmlDocSetRootElement`, `xmlAddChild`,
`xmlUnlinkNode`, `xmlFreeNode`, and the namespace-free attribute APIs
`xmlNewProp`, `xmlSetProp`, `xmlUnsetProp`, `xmlRemoveProp`, and `xmlFreeProp`.
Namespace creation, attribute/namespace copying, namespace-qualified attribute
editing, cross-document moves, and serialization are deferred. Unsupported
operations fail without silently creating invalid links. Unsupported parser
options fail, not silently degrade.

The current profile supports XML 1.0 UTF-8 and UTF-16LE/BE input, Unicode NCNames and qualified
element/attribute names, namespace declarations and read-only namespace lookup,
attributes, text, the five predefined entities, numeric references, comments,
CDATA and processing instructions. Normal resource ceilings are 50,000 bytes
per QName component/PI target, 10,000,000 decoded bytes per value, and depth
256. `XML_PARSE_HUGE` raises these to 10,000,000 bytes, 1,000,000,000 bytes, and
depth 2,048 respectively; it does not enable DTD, recovery, or other unsupported
features. The DOM is always UTF-8. UTF-16 input uses the length-taking
`xmlReadMemory`; `xmlReadDoc`/`xmlParseDoc` use `strlen` and are not binary UTF-16
entry points. Names `UTF-8`/`UTF8`, `UTF-16`/`UTF16`, `UTF-16LE`, and
`UTF-16BE` are case-insensitive; generic UTF-16 selects little-endian. Explicit
encoding overrides the declaration while declaration grammar is still checked.
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
