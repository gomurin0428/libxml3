# Assurance boundary

This project is an experimental, independent Ada/SPARK implementation, not a
release of GNOME libxml2. It is not yet a complete libxml2 replacement.

## Intended proof claims

`proof.gpr` includes exactly `XML3_Text`, `XML3_Parser`, and `XML3_Namespaces`.
GNATprove must establish all generated flow and run-time checks and the written
contracts for those units.
The parser is iterative. Its statically bounded nesting stack holds at most
2,048 elements; the normal profile permits depth 256 and `XML_PARSE_HUGE` permits
2,048. There is no fixed whole-document byte cap or 2,048-node policy cap. Input
indices are bounded by `XML3_Text.Max_Bytes = Integer'Last - 16`, and node IDs by
half that representation bound. The SPARK core has no allocator, filesystem,
network, or callback access. The C adapter supplies bounded node/name arrays and
heap scratch buffers, grows the arena geometrically when the parser reports
`Arena_Exhausted`, and reparses; adapter allocation, pointer arithmetic, and
ownership remain outside the proof scope.

The recorded result is [877 checks discharged, none unproved](proof-report.md)
across the three core units, including `XML3_Namespaces`, but not the C adapter.
The parser postcondition requires every output node's parent to precede it and
every name/value span to lie within the input, including well-defined empty spans.
The decoder's output never exceeds its input length. Numeric reference arithmetic
is checked before multiplication. Termination of the core `Parse` and `Decode`
procedures and namespace `Resolve` is proved with `Always_Terminates` and loop
variants; this does **not**
claim an end-to-end CPU-time or memory-use theorem.

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

## Trusted / unproved boundary

* The Ada C-ABI adapter, C-compatible DOM objects, allocations, deallocations,
  reference ownership, and foreign pointer conversions are outside SPARK.
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
document are supported. Unsupported parser options fail, not silently degrade.

The current profile supports XML 1.0 UTF-8 content, Unicode NCNames and qualified
element/attribute names, namespace declarations and read-only namespace lookup,
attributes, text, the five predefined entities, numeric references, comments,
CDATA and processing instructions. Normal resource ceilings are 50,000 bytes
per QName component/PI target, 10,000,000 decoded bytes per value, and depth
256. `XML_PARSE_HUGE` raises these to 10,000,000 bytes, 1,000,000,000 bytes, and
depth 2,048 respectively; it does not enable DTD, recovery, or other unsupported
features. These per-component/per-value thresholds are distinct from whole-input
and representation bounds. XML declarations accept version 1.0,
encoding `UTF-8`/`utf-8`, and standalone yes/no, in XML order. CR/CRLF line endings
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
