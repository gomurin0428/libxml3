# SPARK proof evidence

## Result

The full proof command for this source revision was:

```sh
/home/ubuntu/.local/share/ada/candidate-14/bin/gnatprove -P proof.gpr --mode=all --prover=cvc5,z3 --timeout=120 --memlimit=4096 -j4
```

It completed successfully: **12,972 checks, 1,391 by flow analysis and 11,581
by provers; 0 unproved, 0 justified**. The aggregate includes namespace editing through
Store/Runtime, retained namespace ownership, failure rollback, explicit UTF-8,
default-encoding, and formatted memory serialization, `xmlNodeAddContent`, `xmlNodeAddContentLen`,
`xmlNodeSetContent`, `xmlTextMerge`, `xmlTextConcat`, `xmlNodeIsText`,
`xmlIsBlankNode`, `xmlNodeGetLang`, `xmlNodeGetSpacePreserve`,
`xmlNodeSetLang`, `xmlNodeSetSpacePreserve`,
`xmlNewChild`, `xmlNewTextChild`, `xmlNewDocText`, `xmlNewDocTextLen`,
`xmlNewDocComment`, `xmlNewDocPI`, `xmlNewDocNode`, `xmlNewDocRawNode`,
`xmlNewDocProp`, managed-attribute attachment through `xmlAddChild`, managed
attribute unlink through `xmlUnlinkNode`, managed sibling insertion through
`xmlAddSibling`, previous/next sibling insertion through
`xmlAddPrevSibling` / `xmlAddNextSibling`, managed node/attribute list release through
`xmlFreeNodeList` / `xmlFreePropList` and `Runtime.Release_List` /
`Store.Release_List`, `xmlNewCDataBlock`, `xmlGetNodePath` through
`Runtime.Get_Path` / `Store.Queries.Get_Path`, `xmlLastElementChild`,
`xmlPreviousElementSibling`, and `xmlGetLastChild` through the SPARK
Store/Runtime. The internal `Store.Replace_Node` and `Runtime.Replace_Node`
operations for `xmlReplaceNode` are analyzed (41 and 1 checks, respectively),
including their written status/result contracts and use of existing graph
operations. This does not prove the C adapter, native facade synchronization,
ABI, or complete public semantics. `xmlStringGetNodeList` and
`xmlStringLenGetNodeList` route
through `Runtime.Parse_Content_List` / `Store.Content.Parse_Content_List`,
the analyzed strict text decoder, and the existing document-owned text
constructor. `xmlNodeListGetRawString` routes through `Runtime.Get_List_Content`
and `Store.Queries.Get_List_Content`. `xmlNodeListGetString` shares that bounded
query and uses the analyzed `XML3_Text.Buffers.Escape_Special` and
`Character_Reference` helpers. The new `xmlNodeGetAttrValue` getter reuses the already-analyzed
`Runtime.Get_Property` / `Store.Queries.Find_Property` / `Get_Content` path;
its C status/output-pointer mapping is outside the proof. The public
`xmlValidateName`, `xmlValidateNCName`, `xmlValidateQName`, and
`xmlValidateNMToken` adapters now pass pointers directly to the analyzed
`XML3_Text.Buffers.Validate_Name` / `Scan_Name`, without a C-string copy.
They share the bounded state machine with the four `valid.h` value predicates.
Their bounds, termination, and written result contracts are proved, not complete
lexical equivalence, native pointer readability/extents, byte effects, C ABI,
or C return-code mapping.
The four `valid.h` value validators delegate to
`XML3_Text.Buffers.Valid_Name_Value` / `Scan_Name`. The scanner reuses
`Name_Character` (0 checks), also used by `Name_Width` (19),
`XML3_Text.Valid_Name` (23, via `Name_Width`), and
`XML3_Text.Buffers.Valid_Name` (4). `Scan_Name` proves 9 checks,
`Validate_Name` 2, and `Valid_Name_Value` 2. These checks cover the bounded
scan's control flow, termination, and written result contracts, not native
pointer readability/extents, byte effects, C ABI, or complete lexical
equivalence.
No DTD or ID/IDREF semantics are proved or implemented by these APIs.
`xmlSplitQName2` and `xmlSplitQName3` share `XML3_Text.QNames.Locate_Prefix`.
QName2's `Split` measures the local tail with the original absolute scan cap
via `Buffers.Measure`'s start offset, then reuses `Copy_Span` twice. Failure
of the second allocation frees the prefix and leaves both outputs NULL.
No intermediate C-string copy is made. QName3 returns
the borrowed local address after checking only its first byte, without a
C-string copy or a scan through the local tail. The proof covers first-colon
length bounds, output/status contracts, and allocation/cleanup control flow
for copying splits. Native pointer readability/extents, byte effects,
allocation/copy/free, pointer arithmetic, C ABI/status mapping, and complete
public semantics remain trusted or outside proof. Reference/guard-page tests
cover early stops and copying the borrowed suffix before freeing its owner;
small-cap Ada tests cover unresolved lookup/copy limits without resetting the
budget at the local suffix. OOM injection is libxml3-only. The pure
`Prefix_Length` helper remains analyzed but is not on these C API paths.
`xmlCharInRange` selects the short table below 65536 and the long table for the
rest of the unsigned domain, then searches inclusive endpoints using the
overflow-safe lower-middle calculation. GNATprove discharges 16 checks for
`XML3_Text.Buffers.Character_In_Range`, including selected-count/stride bounds,
search indices, and loop termination. The scalar group/entry loads in
`XML3_Native_Memory` are explicitly `SPARK_Mode => Off`; they are not proved.
Caller-provided ranges must be readable, aligned, sorted, disjoint, and stable
during the call. Tests compare valid tables with the pinned reference and
exercise unsigned boundaries, guard pages, ignored inaccessible table halves,
malformed selected metadata on libxml3 only, and the no-allocation path. Native
pointer validity/extents/layout/actual reads, C ABI, and complete semantics
remain trusted or outside proof; this is a generic range lookup, not a
Unicode/XML validator.
`xmlURIEscapeStr` uses `XML3_Text.Buffers.Escape_URI` for bounded,
byte-wise percent encoding with lazy cached exception-list searches. The
optional `Find_Byte` limit defaults to `Max_Bytes`, preserving existing
search behavior; `URI_Image` proves 6 checks, `Escape_URI` 18, and `Find_Byte`
3. These checks cover the image width, bounded measurement/search and written
status/result contracts, not native allocation, bytes, reads or writes,
pointer validity/extent/stability, C ABI, or complete URI semantics. Tests
compare all nonzero byte values with the fixed reference and cover arbitrary
non-UTF-8 bytes, aliasing, guarded early stops, limits and OOM retry.
`xmlNormalizeURIPath` delegates to `XML3_Text.Buffers.Normalize_URI_Path`.
The helper proves 32 checks for bounded measurement before mutation, segment
and output-position arithmetic, in-place copy preconditions, loop termination,
and the status contract. These checks do not prove normalized byte values,
native byte effects, pointer validity or writable extents, C ABI, or complete
path semantics. Tests cover reference behavior, deliberate upstream
root-detection differences, idempotence, byte values, guarded termini,
read-only empty input, and the allocation-free path.
`xmlURIUnescapeString` delegates to `XML3_Text.Buffers.Unescape_URI`.
`URI_Hex` proves 1 check and `Unescape_URI` 19, covering the hex-result range,
bounded input-span traversal, native-call preconditions and status/result/
target contracts. They do not prove decoded byte values, target capacity,
native reads/writes, scratch allocation/copy/free, pointer validity or full
public semantics. Tests cover positive and terminator-based lengths, embedded
NULs, malformed escapes, exact in-place and overlapping buffers, limits and
allocation-failure preservation.
`xmlGetPredefinedEntity` reuses the pure `Entity_Name` mapping (1 check),
`Entity_Value` (0 checks), and exact `Find_Entity` matching (2 checks) in the
shared decoder. Its bounded native-name lookup proves 1 check for
`Get_Predefined_Entity` and reuses `Matches_Literal` (5 checks). The static
`XML3_Native_Memory.Predefined_Entity` record/string table is in
`SPARK_Mode => Off`; its native layout, pointers, lifetimes, byte contents and
address effects are not formally proved. The public API remains partial and
not-proved: C-string conversion, native pointer readability, C ABI, and
complete entity semantics remain trusted boundaries.
`xmlGetDocEntity` delegates to the analyzed
`Runtime.Get_Document_Entity` (1 check) and
`Store.Queries.Get_Document_Entity` (3 checks); its registration guard
`Registered_Document` discharges 8 checks. A NULL name returns before document
registration or name access; otherwise the Store query validates NULL or
registered document facades before calling the already-bounded predefined
lookup. This covers the SPARK query and its status/result contract, not C
diagnostic mapping, C ABI, native name readability, static record layout or
lifetime, byte contents, or complete public semantics.
`xmlBuildQName` uses `XML3_Text.QNames.Build` for direct bounded measurement
and byte construction without C-string conversion. Its budget first reserves
colon/NUL, measures the name, and measures the prefix within the remainder.
`Overlaps` compares nonempty spans by subtracting the smaller address value
from the larger, rather than forming potentially overflowing end addresses.
A sufficient overlapping caller buffer uses a temporary allocation, copied
back only after successful construction; failure preserves the caller buffer.
Sufficient non-overlapping buffers need no allocation. The written result/status
contract and scalar bounds are checked, not native address-to-integer mapping,
pointer validity/extents, allocation/free/byte effects, C ABI, or full public
semantics. GNATprove discharges 18 checks for `Build` and 2 for `Overlaps`.
Overlap safety is tested only for libxml3, not reference equivalence.
`xmlEncodeSpecialChars` exports from `libxml/entities.h` and uses
`XML3_Text.Buffers.Escape_Special_Bytes` without C-string materialization.
`Escape_Bytes_Pass` performs bounded direct UTF-8/XML validation, measurement
and construction, stopping at NUL or the first invalid unit. It shares
`Get_UTF8_Char`, `Special_Image`, `Character_Reference`, and `UTF8_Image`.
Allocation follows successful measurement; the write pass uses that measured
size as its cap and failures free partial output. The written proof covers
scalar bounds, loop/index/overflow checks, native-call preconditions and the
status/result relationship, not complete output semantics. GNATprove discharges
17 checks for `Escape_Bytes_Pass` and 5 for `Escape_Special_Bytes`; the
String-based `Escape_Special` has 39 checks. Tests cover the fixed
replacements, NULL/empty behavior, Unicode, input immutability, ownership,
round-trip serialization, invalid-input rejection, and OOM retry. The API is
partial and not-proved at the public C level: pointer validity/readable extents,
ABI/status mapping, native allocation/free and actual byte effects,
and complete libxml2 semantics remain trusted. The document argument is
unused as in pinned libxml2 2.15.4; malformed UTF-8/XML is rejected rather than
silently repaired or preserved, and no DTD/entity expansion is provided. The
String-based `Escape_Special` remains for internal DOM callers and emits one
analyzer warning because `Validate_UTF8`'s `Error` output is unused.
`xmlEncodeEntitiesReentrant` passes its input address directly through
Runtime/Store `Encode_Entities`. `Registered_Document` runs before any input
read; invalid documents return NULL without dereferencing document or input.
`Escape_Special_Bytes` is shared with `xmlEncodeSpecialChars`, using
`Non_ASCII => True, Quotes => False`, and `Encoding_Status` maps its result.
The Store `Encode_Entities` query proves 3 checks and its Runtime wrapper 1.
It escapes `<`, `>`, and `&`
with named references, CR as `&#13;`, and valid non-ASCII as uppercase
hexadecimal references; quotes, TAB, and LF remain literal. NULL input is
returned before document validation, while non-NULL input permits only NULL
or a registered document. The proof covers the shared bounded validation,
escaping, and status/result contracts. No C-string conversion remains on this
path; native pointer extents/stability, byte effects, allocation/free, C
NULL/diagnostic mapping, ABI, and complete C semantics remain trusted. Its
behavior intentionally rejects invalid UTF-8/XML rather than repairing or
preserving it; document encoding is not retained, so explicit UTF-8 documents
can differ from reference output. General-entity expansion and HTML behavior
are unsupported. Scan/expansion caps map to resource-limit diagnostic 114,
instead of the former C-string scan-cap diagnostic 115; invalid text/document
still maps to 115. Guard pages cover rejection before input reads and early
invalid-unit stopping. Public C integration and OOM retry are exercised by
`tests/unicode-test.c` and `tests/oom-test.c`.
`xmlStrQEqual` uses `XML3_Text.QNames.Compare` for raw-byte prefix/name/value
comparison. The proof covers status initialization, NULL-prefix pointer
identity, scalar loop bounds, and the status postcondition relating equality
to NULL/pointer-identity inputs. NULL prefix
delegates the string-equality behavior, while non-NULL prefix comparison
requires non-NULL name/value and a literal prefix, colon, and name through
NUL. Empty prefix returns Different without reading name/value, deliberately
not reproducing the pinned reference's unsafe post-terminator read or its
NUL-then-`:name` tail quirk. Guard-page and tail cases are libxml3-only.
Early mismatches return immediately; equality requiring reads beyond the
`Max_Bytes` scan cap maps to limit error plus zero rather than silent equality.
Native reads, foreign
pointer validity/bounds, actual bytes, address arithmetic, C mapping, and full
equivalence remain trusted. XML-name and UTF-8 validation are not performed.
`xmlStrdup`, `xmlStrndup` and `xmlCharStrdup` delegate to the direct SPARK
`Concatenate_Bytes` path. `xmlCharStrndup` uses `Copy_Byte_Prefix` to scan at
most the requested byte count, stopping at NUL without reading beyond that
count, then calls the shared `Copy_Span` allocator/copier. NULL/negative and
over-limit requests return before any input reads; non-NULL zero-length input
gets an owned empty allocation. No C-string materialization is needed.
`Copy_Byte_Prefix` proves 8 checks.
The SPARK proof checks scalar bounds, written status/result contracts and native
preconditions, not native pointer validity/extents, allocation freshness,
actual bytes/effects, ABI or full public semantics. Raw-byte, guard-page and
free-input→parse-output cases run against the pinned reference; small-cap and
OOM/retry tests are libxml3-only. The reference may allocate `len + 1` even
after an early NUL, whereas libxml3 allocates only the copied prefix and
terminator. Tests compare defined contents, not unspecified spare capacity or
allocation-size equivalence. `Duplicate` remains for internal Ada strings.
`xmlStrchr` uses `XML3_Text.Buffers.Find_Byte` to perform a bounded raw-byte
search and return the first matching non-NUL position. The written
status/position contract and loop bounds are proved; NULL input and search
value zero produce no match without reading. The scan permits a terminator at
the `Max_Bytes` boundary and reports a limit only when no match or terminator
is found within the cap; early matches in longer strings return immediately.
The C adapter maps that position to a borrowed pointer and maps limit or
unexpected failures to error plus NULL. Native byte reads, pointer validity,
readable memory bounds, actual contents, address arithmetic, C diagnostics,
and full public semantics remain trusted. Tests cover byte values, NUL
termination, borrowed-pointer behavior, guard-page boundaries, and no native
allocations.
`xmlStrstr` and `xmlStrcasestr` use `XML3_Text.Buffers.Find_Substring` and the
shared C `Search_Result` mapping. The SPARK contract proves that a match has
non-NULL inputs and a position below `Max_Bytes`, while non-matches leave the
position at zero; loop/read preconditions are discharged. NULL arguments return
no match, and an empty needle returns the non-NULL haystack pointer without
reading the haystack. The scan handles raw bytes through the first NUL,
overlapping aliases, and UTF-8 fragments without validation or transcoding.
The case-insensitive path retains the pinned `[` to `{` byte-map quirk rather
than Unicode case folding. A boundary NUL is accepted, matches ending there
can succeed, and required non-NUL data beyond the cap maps to diagnostic plus
NULL. Early matches avoid a full scan. Native reads, foreign pointer validity
and bounds, actual contents, address arithmetic, C error mapping, borrowed
lifetime, and complete API equivalence remain trusted.
Shared substring vectors, byte-pair comparisons, and guard-page cases run
against both the pinned reference and libxml3; the OOM/no-allocation test is
libxml3-only.
`xmlStrsub` uses `XML3_Text.Buffers.Slice`. SPARK proves its scalar
status/result contract, checked arithmetic/ranges, and native-call
preconditions (12 checks). NULL input and negative indices return no slice
without a diagnostic. Otherwise the helper checks for NUL from offset zero through `start`, even
when `len` is zero; a valid zero-length slice allocates an owned empty result.
It copies exactly `len` bytes after the validated start, including embedded
NUL and following raw bytes, then appends a terminator. This is a readable-span
contract, not clamping at the source string's NUL. The supported subset checks
`start < Max_Bytes` and `len <= Max_Bytes - start` before native reads and
reports a limit error plus NULL when those bounds are exceeded. Native pointer
validity, readable bounds and actual bytes, allocation freshness and writes,
address arithmetic, C status mapping, and full public semantics remain
trusted. Shared slice vectors and guard-page cases run against both the pinned
reference and libxml3; cap and OOM checks are libxml3-only. No XML-name or
UTF-8 validation or transcoding is performed.
`xmlStrncmp` and `xmlStrncasecmp` use `XML3_Text.Buffers.Compare_Bounded`.
SPARK proves bounded loop control and the -255 .. 255 result contract; the
scan accepts the full nonnegative C `int` bound without a `Max_Input` cutoff,
and may stop on an early mismatch or NUL. The case-insensitive byte map
preserves the pinned `A`–`Z` mapping and its
additional `[` to `{` quirk, not general Unicode folding. These routines do
not allocate or convert C strings. `Native.Byte_At`, actual foreign-memory
contents/bounds, pointer validity, and full public semantics remain trusted.
Tests compare all byte pairs and exercise protected-page early exits.
`xmlStrcmp`, `xmlStrEqual`, and the new `xmlStrcasecmp` share
`XML3_Text.Buffers.Compare_Terminated`, which uses the same byte scan. The
terminated comparison accepts identical pointers and NULL ordering before any
native read, then scans offsets 0 through `Max_Bytes` inclusive, stopping at
the first mismatch or NUL. If equal non-NUL bytes remain through the boundary,
the helper reports a limit result and returns -1; the C adapter diagnoses it.
That sentinel is not a reliable ordering result. The ordering APIs return it,
while `xmlStrEqual` maps the error to 0. Unexpected C-side exceptions are also
diagnosed and yield -1 for the ordering APIs and 0 for equality. The
case-insensitive routine preserves the pinned `[` to `{` map quirk without
Unicode case folding, validation, or transcoding. SPARK proves loop bounds,
native-call preconditions, result range, and the cap-failure contract; actual
foreign pointer validity, readable bounds/bytes, C error mapping, and full
semantics remain trusted. Shared byte-pair and guard-page cases run against
both libxml3 and the pinned reference; OOM/no-allocation checks are
libxml3-only. The cap-specific test invokes the Ada helper with a small `Last`;
no public C string near the cap is dynamically constructed.
`xmlStrlen` delegates to `XML3_Text.Buffers.Measure`, using `Read_Length` to
scan through the inclusive bound and accept a NUL at `Last`. NULL succeeds
with length zero. An unresolved scan returns failure with length zero; the C
adapter records DOM error 115 and returns -1, not a reliable empty-string
result. Unexpected C-side exceptions map to DOM error 1 and -1. This bounded
subset uses `Max_Bytes` (`Integer'Last - 16`) and intentionally differs from the pinned reference's zero for lengths
above `INT_MAX`. A reduced `Last` tests this path without constructing a huge
public C string. SPARK proves `Read_Length` (4 checks) and `Measure` (2
checks), including scan bounds, result/status contracts, and native-call
preconditions. Actual native reads/bytes, pointer validity and readable
bounds, C diagnostics/mapping, exception behavior, and complete semantics
remain trusted. Shared raw-byte, Unicode-byte-count, and guard-page tests run
against both implementations; the no-allocation test is libxml3-only.
`xmlCheckUTF8` uses `XML3_Text.Buffers.Check_UTF8` to stream NUL-terminated
input through a four-byte stack buffer, validating each scalar with
`XML3_Text.Validate_UTF8 (XML_Only => False)`. This rejects malformed,
truncated, overlong, surrogate, and out-of-range encodings, while accepting
ASCII controls and Unicode noncharacters; XML character validity is separate.
Existing XML parsing and name/content validation retain their XML-character
checks.
The stricter result intentionally differs from the pinned reference's
permissive acceptance of noncanonical encodings. NULL/malformed input returns
0 without a diagnostic, empty input returns 1, and a boundary NUL is accepted.
If no NUL is found within `Max_Bytes`, DOM error 115 is recorded and 0 returned;
unexpected exceptions map to error 1 and 0. No allocation, mutation, or
transcoding occurs. `Scan_UTF8` implements the shared bounded streaming scan.
`Count_UTF8` delegates to it, and `Check_UTF8` delegates to `Count_UTF8`,
preserving whole-string validity and cap behavior. `Measure_UTF8_Prefix` uses the shared `Scan_UTF8`
loop and stops at the requested scalar count or first NUL. `Scan_UTF8` is
proved for 26 checks, `Count_UTF8`, `Check_UTF8`, and `Measure_UTF8_Prefix` for
1 each, and `Validate_UTF8` for 21. These cover scan/counter control, scalar
and byte-offset bounds, status/result contracts, and native-call preconditions,
not actual foreign bytes, readable bounds, pointer validity, C diagnostics, or
complete API semantics. Reduced-cap Ada tests avoid constructing a huge
public C string. Shared ordinary/malformed and guard-page vectors run against
the pinned reference and libxml3, with invalid-input expectations compared
only for the tested vectors; the no-allocation test is libxml3-only.
`xmlUTF8Strlen` returns the number of Unicode scalar values before the first
NUL, not bytes or grapheme clusters; combining sequences are counted scalar by
scalar and no normalization occurs. Empty input returns 0. NULL, malformed,
truncated, overlong, surrogate, out-of-range, or unsupported UTF-8 returns -1
without a diagnostic, while ASCII controls and Unicode noncharacters count as
valid UTF-8 but are not thereby validated as XML characters. The strict
scanner deliberately rejects malformed forms permissively counted by the
pinned reference, including overlongs, surrogates, out-of-range scalars, and
two-continuation-byte sequences. Failure to find NUL through `Max_Bytes` records
error 115 and returns -1; unexpected exceptions map to error 1 and -1. It
allocates nothing, mutates no input, and does not transcode. Reduced-`Last`
Ada tests cover the cap; no huge public C string is constructed. `Scan_UTF8`
is proved for 26 checks and `Count_UTF8` for 1; these cover counter/loop/index
bounds, status/result contracts, and native-call preconditions, not complete
Unicode API semantics or actual foreign bytes.
Native pointer validity/readable extent and C-side diagnostic/exception
mapping remain trusted. Shared reference/malformed and guard-page tests run
against both implementations with expected permissive-vector results
separated; OOM/no-allocation tests are libxml3-only.
`xmlUTF8Strpos` delegates to `XML3_Text.Buffers.Find_UTF8_Position` and the
shared `Scan_UTF8` scanner. It returns a borrowed pointer at a zero-based
Unicode scalar offset, validating only the preceding prefix. Position zero
returns the input pointer without reading; after a matched prefix, neither the
target scalar nor its suffix is read or validated. At the exact scalar length,
it returns the NUL address without reading that byte. NULL input, negative or
out-of-range positions, and malformed visited prefixes return NULL without a
diagnostic. ASCII controls and Unicode noncharacters are valid UTF-8 but are
not thereby XML-character validated. The strict scanner deliberately rejects
overlongs, surrogates, out-of-range scalars, and five-byte sequences accepted
by the pinned reference. An unresolved scan through `Max_Bytes` records error
115; unexpected exceptions map to error 1. No allocation, input mutation, or
normalization occurs; the returned pointer is borrowed and must not be freed.
Reduced-`Last` Ada tests cover the cap; no huge public C string is constructed.
`Scan_UTF8` is proved for 26 checks and `Find_UTF8_Position` for 1; GNATprove
covers scan control, position/counter bounds, status/result contracts, and
native-call preconditions, not complete Unicode semantics or actual foreign
bytes. Pointer validity/readable extent and C mapping remain trusted.
Shared reference-permissive and guard-page tests run against both
implementations with differing expectations; OOM/no-allocation checks are
libxml3-only.
`xmlUTF8Strsize` uses `XML3_Text.Buffers.Measure_UTF8_Prefix` to return the
raw byte size of up to the requested number of Unicode scalars, excluding the
terminating NUL. NULL input or a nonpositive count returns 0 without reading.
A shorter string returns the bytes before NUL; after reaching the requested
scalar count, the following scalar and suffix are not inspected. A malformed,
truncated, or noncanonical strict UTF-8 prefix returns -1 without a partial
size or diagnostic. Reference behavior for invalid UTF-8 is not guaranteed;
this implementation rejects malformed visited prefixes. ASCII controls and
Unicode noncharacters are valid UTF-8, not XML-character validation. An
unresolved scan through inclusive `Max_Bytes` records error 115 and returns -1;
unexpected exceptions map to error 1 and -1. No allocation, input mutation, or
normalization occurs. Reduced-`Last` Ada tests cover the cap; no huge public C
string is constructed. `Measure_UTF8_Prefix` is proved for 1 check; GNATprove
covers scan control, byte-offset bounds,
status/result contracts, and native-call preconditions, not full Unicode
semantics or actual foreign bytes. Pointer validity/readable extent, actual
bytes, and C mapping remain trusted. Shared malformed/reference and
guard-page vectors run against both implementations; OOM/no-allocation checks
are libxml3-only.
`xmlUTF8Size` delegates lead-byte classification to
`XML3_Text.Buffers.UTF8_Lead_Size`. NULL returns -1 without a read; otherwise
exactly byte zero is read, with no follow-up read or required NUL terminator.
It returns 1 for `0x00..0x7f` (including NUL), 2 for `0xc2..0xdf`, 3 for
`0xe0..0xef`, 4 for `0xf0..0xf4`, and -1 for all other leads. This is not
UTF-8/XML validation: a lone `0xe2` or surrogate-leading `0xed` returns 3
without checking truncation, continuations, or scalar validity. One readable
non-terminated byte is sufficient. Normal results allocate nothing, mutate no
input, and record no diagnostic; unexpected exceptions map to error 1 and -1.
The pinned reference also reads only the lead but assigns widths to invalid
leaders `0xc0..0xc1`, `0xf5..0xf7`, `0xf8..0xfb`, `0xfc..0xfd`, and `0xfe`;
this implementation rejects them. Validation/decoding uses `xmlCheckUTF8` or
`xmlGetUTF8Char`. The guard-page loop places each of the 256 byte values at the
final readable byte before `PROT_NONE`; standalone non-terminated one-byte
inputs and no-allocation behavior are also tested. GNATprove proves 2
`UTF8_Lead_Size` checks for its result/null contract and native-call precondition. These checks do
not establish native bytes, readable extent/pointer validity, C mapping/ABI,
or complete Unicode/API semantics.
`xmlUTF8Charcmp` uses `XML3_Text.Buffers.Compare_UTF8_Character`, whose
contract bounds the result to -255..255 and requires `Result = -1` when
`Invalid`; these contracts do not prove byte-order equivalence or Unicode
semantics. Both NULL pointers return 0; a single NULL returns -1 for a NULL
left pointer or 1 for a NULL right pointer without reading the other pointer.
For non-NULL pointers, only the left lead is classified first; an invalid lead
returns invalid/-1 before reading right. The helper then compares at most the
left lead width (1..4, including NUL width 1) as unsigned bytes and returns the
first nonzero difference immediately, without decoding or validating either
full sequence. Equal bytes alone trigger `Get_UTF8_Char` validation of the
left first scalar before 0, including for aliased pointers. Equal malformed,
truncated, overlong, surrogate, or out-of-range prefixes return invalid/-1
instead of the pinned reference's 0. Thus `E2 x` versus `E3 y` is -1 without
diagnosis and `a` versus `0xff` is -158 without diagnosis. Valid first
characters retain the reference byte difference; suffixes are ignored, with no
case folding, normalization, grapheme matching, or XML-character validation.
The C adapter maps invalid to DOM error 9 (`XML_FROM_TREE` /
`XML_ERR_INVALID_CHAR`) and returns the numeric result; diagnostic allocation
failure may map to standard OOM error 2, and unexpected exceptions map to
error 1 and -1. Normal comparisons allocate nothing and do not mutate either
input, but diagnostics may
allocate. Success preserves any old last error, so callers must reset/check it
when distinguishing diagnosed failure from a legitimate -1. Caller memory
must remain stable/readable through accessed bytes; equality can read the
complete first scalar or NUL even for aliases. There is no cap beyond the
four-byte left width. GNATprove does not establish actual native bytes,
pointer validity/readability/stability, C mapping/ABI, or complete Unicode
behavior. The C/reference tests include 169 valid-character pairs, early
nonzero differences without diagnostics, malformed equal prefixes, aliases,
guard-page boundaries, and diagnostic-allocation failure/retry.
`xmlUTF8Strloc` delegates to `XML3_Text.Buffers.Find_UTF8_Character`, which
measures the pattern's first scalar with `Measure_UTF8_Prefix` using a four-byte
bound, copies that scalar to a local buffer, and passes it to the shared
`Scan_UTF8`. The scanner strictly validates a source scalar before comparing
it and returns the first match before advancing; other existing callers use
the empty default pattern and retain their previous behavior. The C adapter
only maps status, index, and diagnostics. The result is a zero-based Unicode
scalar index for the first occurrence of the pattern's first scalar, not a
byte offset. The pattern suffix and source suffix after a match are ignored.
The first pattern scalar and every visited source scalar through the match are
strictly validated; malformed/truncated/noncanonical prefixes and ordinary
no-match return -1 without diagnostics. NULL either pointer returns -1 without
reading the other. The preserved empty-pattern quirk returns 0 for a nonempty
source after reading only byte zero, without validating it; empty source
returns -1. Normal outcomes allocate nothing or mutate input. Inclusive
`Max_Bytes` exhaustion maps to error 115/-1 and unexpected exceptions to
error 1/-1. Inputs must remain readable and stable through the first pattern
scalar and through the matched scalar or NUL; the matching scalar may end at a
guard page without a terminator. GNATprove covers scan control, scalar-index
bounds, status/result contracts, and native-call preconditions, not native
bytes, readable extent, pointer validity/stability, C ABI/mapping, or complete
UTF-8/API semantics. C/reference and Ada tests cover scalar indexing,
first-scalar-only matching, malformed-prefix divergence, empty-pattern
behavior, DOM lifetime, exact-span guard cases, and no allocation.
GNATprove proves 6 checks for `Find_UTF8_Character` and 26 for `Scan_UTF8`;
these cover result bounds/status and scanner control, not native bytes or
complete UTF-8 behavior.
`xmlUTF8Strndup` delegates through `UTF8_Str_Sub_Copy` to
`XML3_Text.Buffers.Copy_UTF8_Slice` at start zero. That helper finds the start
and delegates the selected prefix to `Copy_UTF8_Prefix`, which validates before
`Copy_Span` creates an independent NUL-terminated allocation. NULL input or a
negative count returns NULL without reads or allocation; a non-NULL zero count
makes a new empty copy without reading input. Positive counts stop at the
requested scalar count or first NUL, leaving the suffix unvalidated. A
malformed, truncated, or noncanonical visited prefix fails before allocation
with NULL, no partial copy, and no diagnostic. The result is caller-owned and
freed with `xmlFree`; input is not mutated or freed. Cap exhaustion maps to
error 115, allocation failure to standard memory error 2, and unexpected
exceptions to error 1. Controls and noncharacters are valid UTF-8, not
XML-character validation; strict malformed-prefix rejection is an intentional
difference from unspecified/permissive invalid-reference behavior.
`xmlUTF8Strsub` also uses `Copy_UTF8_Slice`: `Find_UTF8_Position` validates the
skipped prefix, and `Copy_UTF8_Prefix` validates/copies only the selected span
through `Copy_Span`. NULL input and negative arguments return NULL without
reads/allocation; a start beyond the scalar length returns NULL. Count zero
still validates skipped scalars but does not read the target; start zero/count
zero performs no input reads and returns a fresh empty copy. Starting at the
scalar length returns an empty copy even with positive count. The `Last` cap is
global across skipped and selected bytes, not reset at the start. Malformed
skipped/selected data fails before allocation; suffix after the selected span
is not validated. Returned storage is owned by the caller; input is unchanged.
The pinned reference may skip non-NUL continuation bytes without verifying
them; strict checking is an intentional safety difference. `Copy_Span` and
existing `Slice` prove 6 checks each; `Copy_UTF8_Prefix` and
`Copy_UTF8_Slice` prove 2 each, and `Find_UTF8_Position` proves 1. The shared C
`Slice_Result` maps diagnostics for both UTF-8 adapters outside SPARK proof.
Proof covers scan/span control, bounds, contracts, and native-call preconditions,
not native bytes, readable/stable extents, pointer/offset validity, allocation,
C ABI/mapping, or complete Unicode semantics. Reduced-`Last` Ada tests cover
the global cap; no huge public C string is constructed. Shared malformed/
reference and guard-page vectors run against both implementations; OOM/
no-allocation checks are libxml3-only.
`xmlGetUTF8Char` delegates decoding to `XML3_Text.Buffers.Get_UTF8_Char`, which
reads at most the caller's `*len` bytes and returns one strict UTF-8 scalar.
NULL `utf`, NULL `len`, and `*len < 1` return -1; a writable length is zeroed
on failure, and `*len < 1` causes no input read. NUL returns code point 0 with
width 1; controls and noncharacters are accepted as valid UTF-8. Invalid,
truncated, overlong, surrogate, out-of-range, and unsupported lead sequences
return -1 without a diagnostic. Unexpected C exceptions map to error 1, zero
length, and -1. No allocation, input mutation, transcoding, or XML character
validation occurs.
The strict decoder deliberately rejects the pinned reference's F8..FF
lead-byte masking and its read of `utf[0]` before checking `*len < 1`.
`Get_UTF8_Char` proves 12 checks for scalar control, loop/index/overflow safety,
width bounds, and native-call preconditions; actual input bytes, pointer
validity/readable extent, C mapping, and complete Unicode API semantics remain
trusted. Shared normal, malformed, exact-span guard-page, and permissive
reference vectors run against both implementations with differing expectations
for the latter; the zero-length unreadable-pointer and no-allocation checks are
libxml3-only.
`xmlCopyCharMultiByte` and `xmlCopyChar` use pure `XML3_Text.UTF8_Width` and
`UTF8_Image`, then `XML3_Text.Buffers.Write_UTF8_Char`. GNATprove discharges
1, 25, and 10 checks for those helpers respectively. `Write_UTF8_Char`
checks its bounded loop and contract before calling the existing trusted
`XML3_Native_Memory.Write_Byte`. `XML3_Text.Decode` and
`XML3_Encoding.Decode_UTF16` reuse the shared encoder and prove 65 and 33
checks respectively. These results cover SPARK scalar calculation, bounds,
and written contracts, not native byte contents, output pointer validity or
extent, C ABI, or complete API semantics. Exhaustive scalar round trips,
sentinels, exact-width guard pages, ignored-`len` values, sticky-error
preservation, and no-allocation behavior are tested; the C adapters and native
writes remain outside the proof.

`xmlStrncatNew` uses `XML3_Text.Buffers.Concatenate_Bytes` directly without
C-string conversion. It obtains the effective right length first, then measures
the left under the remaining cap. Excessive positive lengths fail before reading
either input; a combined overflow fails before copying the right span.
`Concatenate_Bytes` proves 6 checks and `Copy_Pair` proves 9 checks. `Copy_Pair`
shares fresh allocation and raw-span copying with `Build_Append`,
but this API never frees its inputs. The String-based `Concatenate`/`Fits`
remain available for Ada `Duplicate`. Scalar bounds and written contracts are
checked; native allocation, pointer validity/readable extents, actual bytes and
effects, ABI and complete public semantics remain outside proof. Raw-byte,
guard-page and lifecycle cases run against the pinned reference; bounded-failure
and OOM cases are libxml3-only.
`xmlStrcat` and `xmlStrncat` use `XML3_Text.Buffers.Append`, whose
`Read_Length`/`Build_Append` helpers scan bounded lengths, allocate a fresh
result, copy the selected raw-byte spans and append NUL. `Append` frees the old
`cur` unless the status is `Unchanged`. NULL `add` and bounded length zero are
no-ops before negative-length handling; a negative length with non-NULL `add`
returns NULL without a diagnostic and consumes `cur`. Positive bounded spans
copy exactly the requested byte count, including embedded NUL. The append
result is independent and `xmlFree`-owned; `cur` must be NULL or a caller-owned
free-compatible allocation base, not a literal or borrowed DOM pointer, and
must not be reused after a consuming call.
Allocating before copying and freeing avoids the reference realloc alias
hazard when `add` points into `cur`; always-copy can increase peak memory and
copy work. `xmlStrcat` scans `add` first and bounds prefix scanning by the
remaining `Max_Bytes`; a NUL at the boundary is accepted, while an unresolved
scan reports DOM error 115. `xmlStrncat` rejects lengths above the cap before
reading either source. Cap failures return diagnostic NULL and consume `cur`;
OOM uses the existing diagnostic and also consumes `cur`. SPARK proves
`Read_Length` (4 checks),
`Build_Append` (6), `Concatenate_Bytes` (6), `Copy_Pair` (9), `Append` (1), bounded arithmetic, native-call
preconditions, and status/result contracts; actual native reads/writes,
allocation freshness/free, pointer validity, caller ownership, C mapping, and
complete API semantics remain trusted. Shared ordinary/null/empty/raw-span/
negative/parse and guard-page cases run against the reference and libxml3;
alias/cap/OOM/free-count cases are libxml3-only.
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
`Compare_UTF8_Character` proves 1 check for its result-range and invalid-status
contract, not full byte-order or Unicode equivalence. The QName proof includes
5 checks for `Locate_Prefix` (bounds and its written output/status contract),
18 for `Build`, 2 for `Overlaps`, 8 for `Compare`, 10 for `Prefix_Length`,
and 6 for `Split`.
`Locate_Prefix` does not prove native byte contents or `Native.Offset` pointer
semantics. `XML3_Text.Buffers.Read_Length` has 4 checks and `Measure` has 2.
`XML3_Text.Buffers.Case_Map` has 1 check,
`Compare_Bounded` has 1, `Compare_Scan` has 4, `Compare_Terminated` has 1,
`Concatenate` has 12, `Duplicate` has 1, `Find_Byte` has 3,
`Find_Substring` has 8, `Fits` has 0, and `Slice` and `Copy_Span` have 6 each.
The 502 entity
summaries report 0 flow errors, 158 warnings, and 0 `pragma Assume`
statements; warnings are not counted as discharged verification conditions.
The `Unescape_URI` warning notes that the initial value of `Span` has no
effect because the value is assigned by the bounded length branch before use.
The two `Escape_URI` warnings note that `Found`'s initialization has no
effect and its returned search position is not used; membership is determined
by `Find_Byte`'s status.

**Analyzer caveat:** generation of representation information for the trusted
`xml3_dom_allocation.ads` spec failed (`cannot generate code for file ...
(package spec)`); GNATprove continued with partial representation data. This
warning is not resolved by the successful proof. Native representation/layout
is outside the claim. One additional benign warning reports that the
initialization of `Existing` in `Store.Properties.Add_Property` has no effect,
because `Find_Matching_Property` initializes that `out` parameter before use.
Trusted external-termination warnings also remain. The string-duplicate,
namespace-list, namespace-copy, QName, substring-search, and slicing paths
include trusted termination
diagnostics for native reads, allocation, writes and frees; an unreachable/no-effect
diagnostic also remains for the portable pointer-array size guard on this 64-bit
host.
The `Get_Path` entities contribute 11 warnings: one input-mode warning on the
Runtime wrapper, unused helper outputs, and trusted native-call termination
warnings. They do not represent unproved checks.

The unedited analyzer summary is in [proof-summary.txt](proof-summary.txt).
This is a proof of the selected SPARK units and their written contracts, not
of the entire C ABI, native memory layout, synchronization implementation, or
full XML conformance. Public DOM APIs now delegate to the SPARK Store/Runtime;
the adapter and the native boundary remain trusted. See [assurance.md](assurance.md).

| Category | Checks |
| --- | ---: |
| Data dependencies | 364 |
| Initialization | 839 |
| Runtime checks | 5,555 |
| Assertions | 1,666 |
| Functional contracts | 4,286 |
| Termination | 262 |
| **Total** | **12,972** |

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
and Z3 is 4.13.0. The recorded full proof used this increased-time command,
not the default `make prove` target:

```sh
/home/ubuntu/.local/share/ada/candidate-14/bin/gnatprove -P proof.gpr --mode=all --prover=cvc5,z3 --timeout=120 --memlimit=4096 -j4
```

`proof.gpr` sets `--level=2 --report=all --checks-as-errors=on` and enables
assertions independently of the production profile. Unproved checks must
fail the command. No assumptions, proof exemptions, weakened contracts, or
new SPARK-off DOM logic were introduced. The aggregate uses the existing
proof session; it is not a cold-cache performance claim. The output is
`obj/proof/gnatprove/gnatprove.out`.

The project contains nineteen complete SPARK units: text, text buffers, QName,
parser, namespaces, encoding, DOM, bridge, constructors, Store, Store.Content,
queries, properties, documents, serialization, Runtime, import, materialize,
and the serialization core. Two trusted specs, native memory and DOM
allocation, bring the analyzer's unit count to twenty-one. Their bodies are not
proved: four allocation bodies and fifteen native-memory bodies are explicitly
`SPARK_Mode => Off`. All nineteen SPARK units were fully analyzed. The C
adapter, mutex/controlled guard, and error handling are not in
the proof project. Native layout/freshness, pointer validity, allocator and
thread-runtime correctness are assumptions, not consequences of ID equations.

## Verified implementation path

Public parsing follows `Runtime.Read → Documents.Read → Parse → Resolve →
Materialize.Build → Store.Adopt_Arena → Import.Adopt → Synchronize`.
`Discard_Arena` retires an unpublished source after failed adoption and then
releases its backing state. Failed adoption leaves that source valid and
caller-owned until cleanup. Errors remain distinct from memory exhaustion.

`Materialize.Has_PI_Data` distinguishes a PI with no data from a separator
followed by empty data by comparing the parser's `Value_First` position with
the target's `Name_Last`. The predicate is shared by `Add_Node_Budget` and
`Fill_Node`: absent data remains a NULL content pointer without an
arena terminator allocation, while present-but-empty data receives an owned
empty string. This preserves the distinction during parse, serialization,
and reparsing without a serializer or C-adapter special case.

`xmlDocDumpMemory` delegates to `xmlDocDumpMemoryEnc` with NULL encoding, and a
NULL encoding passed to `xmlDocDumpMemoryEnc` selects the same default mode.
The two format variants share that adapter and pass the scalar format flag as
a Boolean through Runtime and Store into `XML3_Serialization.Render`. All four
APIs reach the same SPARK serializer. Runtime/Store pass the encoding address
without C-string conversion. Store compares registered live document facades
before reading encoding, including rejecting unregistered/wrong-kind pointers
without dereferencing them. `Read_UTF8_Name` uses at most six native byte reads
and stops at the first mismatch; a fixed five-character field preserves case.
Its `Matches_UTF8_Byte` predicate is shared with the renderer's String check.
NULL selects default mode in Store; empty/unsupported names and suffixes fail
without fallback. Guard pages cover short names, invalid prefixes/suffixes,
valid names ending at the page boundary, and unreadable document/encoding
pointers; all eight ASCII-case combinations preserve their spelling. The
round-trip test frees the encoding name and source document before reparsing.
The unformatted APIs and `format=0`
retain compact output. Any nonzero format value, including negative values,
enables two-space indentation capped at 60 spaces. Before descending, the
serializer scans an element's immediate children; a direct Text or CDATA child
(including whitespace-only Text) suppresses indentation and inserted newlines
throughout that element subtree, then formatting resumes for following
siblings. The serializer does not mutate the DOM, but inserted output
whitespace becomes Text if the result is reparsed.

The default encoding mode omits the encoding declaration and emits non-ASCII
scalar text, attribute values, and namespace URIs as uppercase hexadecimal
character references; names, comments, processing instructions, and CDATA
retain raw UTF-8. `Render` reads immutable Store state, validates and measures
iteratively before allocation, then emits through the same traversal into an
exact-size native buffer. GNATprove reports 1 check for Runtime
`Dump_Memory_Encoding`, 7 for Store `Serialization.Dump`, 3 each for
`Read_UTF8_Name` and `Matches_UTF8_Byte`, 4 for `Is_UTF8`, and 9 for `Render`.
Within `Render`, `Put_Character_Reference` has 1 check, `Emit_Text` has 17,
and `Pass` has 23, including the formatting traversal. These SPARK checks and
written contracts do not prove native pointer readability, complete XML
conformance, or libxml2 lexical equivalence. Native
allocation, pointer extents/stability, mutex behavior, and native
byte reads/writes remain trusted. The C adapter handles pointer/scalar/null
conversion, output initialization, lock acquisition, and status/exception
mapping. Source encoding and standalone metadata are not retained; default
output therefore does not restore the parsed source encoding.

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

`xmlAddPrevSibling` and `xmlAddNextSibling` dispatch through
`Runtime.Insert_Sibling` to `Store.Insert_Sibling`; the SPARK core
`XML3_DOM.Insert_Sibling` proves 80 checks, the Store operation proves 10, and
the Runtime operation proves 1. The verified core uses the existing attachment
path followed by direct tail placement and proves its written graph-preservation
contracts. Native pointer validity, ABI mapping, synchronization, and complete
public C semantics remain outside the proof.

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

`xmlIsChar`, `xmlIsBlank`, `xmlIsBaseChar`, `xmlIsCombining`, `xmlIsDigit`,
`xmlIsExtender`, `xmlIsIdeographic`, and `xmlIsPubidChar` use the pure
`XML3_Text.XML_Char`, `XML3_Text.XML_Blank`, `XML3_Text.XML_Base_Char`,
`XML3_Text.XML_Combining`, `XML3_Text.XML_Digit`, `XML3_Text.XML_Extender`,
`XML3_Text.XML_Ideographic`, and `XML3_Text.XML_Pubid_Char` classifiers. The
helpers are analyzed in SPARK; proof output has no checks for the first seven
and one proved check for `XML_Pubid_Char`. The exported C adapters, narrowing
boundary, ABI, and complete upstream semantics remain outside the proof.
Runtime tests sweep code points through U+110000, check unsigned high values
and ensure current NCName behavior is unchanged; the no-allocation OOM
operation checks the native allocation counter. `XML_Base_Char` uses the
pinned historical 197 short ranges plus five ranges below U+0100 and excludes
U+4E00; `XML_Combining` uses the pinned 95 short ranges and excludes U+0346.
These fixed historical sets are not current Unicode categories or current
NCName rules (U+037F and `a` followed by U+0346 remain accepted), nor a DTD
subsystem. Only the function symbols are implemented; header macros and
range-group APIs remain unsupported.

`xmlIsXHTML` is implemented by `XML3_Text.Buffers.Is_XHTML`, using the bounded
`Matches_Literal` helper for exact NUL-terminated byte comparisons. The proof
summary reports 7 checks for `Is_XHTML` and 5 for `Matches_Literal`. The
function checks both-NULL before matching the three known XHTML 1.0 public IDs
first and the three system URIs second; a public match skips the system ID.
The C adapter only converts the integer result. UTF-8 validation, URI
resolution, DTD loading and HTML parsing are not performed. Runtime tests cover
the return matrix, truncated prefixes, guard-page boundaries, and a matched
public ID with an unreadable system pointer; these do not prove native pointer
validity or full public C semantics.

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

## `xmlGetNodePath`

`xmlGetNodePath` routes through `Runtime.Get_Path` to
`Store.Queries.Get_Path`. The Store resolves only registered facades before
metadata reads, checks live/ranged nodes and namespaces, and validates
path-relevant parent, property, child, and sibling chains with bounded walks.
The shared `XML3_Text.Buffers.Valid_Name` helper rejects invalid UTF-8/XML
names, prefixes, and PI targets rather than copying malformed path syntax.
Output length is measured before a single exact-size allocation; a second
bounded traversal reverse-prepends path components without recursion or an
ancestor array, frees the result on failure, and writes the terminator only
after emitted length matches the measured length. The reference's harmless
default-namespace wildcard and equal-prefix/different-URI matching quirks are
preserved; full XPath namespace resolution is not claimed.

GNATprove discharges 8 checks for `Get_Path`, 17 for `Occurrence`, 7 for
`Measure`, 14 for `Emit`, and 27 for `Write_Component`. These cover internal
control flow, bounds, arithmetic, and written contracts, not complete public
C semantics. Native pointer readability, allocation/free, byte copying and
writes, pointer arithmetic, ABI/status/diagnostic mapping, and full libxml2
semantics remain trusted or unproved.

`make test-text-buffers test-dom test-serialization tests/header-smoke.o
tests/oom-test` passed. The `node-path` OOM walk injected failure at index 0
and reached the expected no-site exit status 2 at index 1; the DOM
ASan/UBSan run with leak detection passed. Shared reference cases cover path
categories and namespace quirks; malformed constructed names, unregistered
facades, detached lifetime, and OOM cleanup are library-only checks.

## `xmlGetLineNo`

`xmlGetLineNo` resolves a registered facade before querying the Store. The
parser records a capped source line with a monotone cursor; only LF advances
it, matching the fixed reference's harmless standalone-CR quirk. The bounded
Store query returns stored lines for parsed element/text/comment/PI nodes and
uses a five-node neighbor fallback for saturated lines and eligible attribute
or CDATA nodes. Attribute/CDATA results may be -1 when detached or inherit a
different line after a move. Constructed element/text/comment/PI and synthetic
attribute-value text have line 0; NULL, document, and unregistered facades
return -1. The C adapter, native pointers, ABI, and complete public semantics
are outside the proof.

GNATprove discharges 7 checks for `Advance_Line`, 13 for `Line_At_Node`, 5 for
`Get_Line_Number`, and 1 for the Runtime wrapper. The API tests cover mixed
markup and source positions, LF-only counting, character references,
constructed nodes, saturation, edits and moves, and no-allocation lookup.

## `xmlNodeSetName`

`xmlNodeSetName` routes through the thin C lock/status adapter to
`Runtime.Set_Name` and `Store.Content.Set_Name`. The Store resolves a
registered facade before reading native node metadata and rejects unsupported
kinds before measuring the caller's name. Bounded UTF-8/XML-name validation,
reserved-name checks, expanded-name attribute conflict detection, exact
allocation/copy control flow, and projection are performed in SPARK. A
successful rename installs a separately owned `Name_Pin`; it is not aliased
to the mutable content owner. The model's holder predicate deduplicates owner
references when two pin fields intentionally identify one owner, and ordinary
content/document/namespace projections preserve the name pin. Existing
projection deltas retire the old owner only after the new name is installed.
Failure preserves the old name, content, links, namespace, and facade identity.

The supported node kinds are elements, attributes, and processing
instructions. Empty or malformed UTF-8 names, invalid NCNames, PI target
`xml` (case-insensitively), unnamespaced attribute `xmlns`, and duplicate
attribute expanded names fail with a DOM diagnostic. NULL and unsupported
kinds are no-ops. Conflicting attributes are rejected rather than deleted.
Entity references and complete public C semantics remain outside this subset.
Native pointer validity/readability, allocation, byte copying, ABI/status
mapping, and diagnostic delivery remain trusted boundaries.

## `xmlStringGetNodeList` / `xmlStringLenGetNodeList`

The C adapters perform bounded input conversion, locking, Runtime dispatch, and
status/diagnostic mapping. `Store.Content.Parse_Content_List` validates a
registered document before native metadata access, uses the strict SPARK text
decoder for UTF-8/XML and predefined/numeric references, and constructs one
detached text node through the existing document-owner path. General/unknown
entities and malformed input are rejected atomically; no entity-reference
nodes are created. Empty input returns NULL. A zero length returns NULL without
reading the input, deliberately avoiding the reference's unsafe first-byte
read. The proof covers the selected SPARK Store/Runtime/decoder contracts, not
C-string scanning, native pointer validity, allocation/copy, ABI, diagnostics,
or complete public semantics.

## `xmlNodeListGetRawString`

The thin C adapter ignores `doc`, returns NULL for a NULL list, and performs
locking, Runtime dispatch, and status/diagnostic mapping. The SPARK query checks
that the starting facade is registered before native metadata access, then
measures and copies only direct text/CDATA content in the bounded next-sibling
chain; it does not descend or mutate the DOM. Nonzero `inLine` preserves raw
bytes without UTF-8/XML validation. Zero `inLine` validates each selected node's
UTF-8 independently before concatenation, then validates XML characters and
escapes special characters, rejecting malformed content split across node
boundaries. A non-NULL list with no selected text produces an independently
`xmlFree`-owned empty string. Entity-reference nodes are unsupported. The proof covers the query's bounded
walk, size arithmetic, and status/result contracts, not native pointer
validity/readability, allocation/copy/free, ABI, or complete C semantics.

## `xmlNodeListGetString`

The thin C adapter performs scalar handling, locking, Runtime dispatch, and
status/diagnostic mapping. The SPARK query shares the direct text/CDATA bounded
next-sibling walk and does not descend or mutate the DOM. Nonzero `inLine`
duplicates raw bytes and ignores `doc`. Escaped mode accepts a NULL or registered
document and validates each selected node's UTF-8 independently before
concatenation; XML character validation and escaping then operate on the joined
content. Attribute escaping is selected from the starting node's parent.
Attribute tabs and line feeds are numeric references and quotes use `&quot;`, while text tabs,
line feeds, and quotes remain literal. Non-ASCII characters become uppercase
hexadecimal character references because this subset does not retain document
encoding; explicit UTF-8 documents can therefore differ from reference output.
The returned allocation is independent and freed with `xmlFree`; NULL list
returns NULL, while a non-NULL list with no selected text returns an allocated
empty string. Output-allocation failure returns NULL without changing the
source links, as exercised by the OOM integration tests. HTML-specific behavior
and entity expansion are unsupported.
The proof covers the bounded query, strict per-node UTF-8 checks, escaper,
character-reference helper, and written status/result contracts—not C pointer
validity/readability, native allocation/copy/free, ABI, or complete C semantics.

## Input encoding-name classification

`XML3_Encoding.Buffers.Classify_Bytes` replaces the C encoding-name scan and String
conversion. Its candidate set shares all six aliases with String `Classify`,
which is also used for XML declaration matching. At most nine bytes (including
NUL) are read; losing the last candidate returns Unsupported immediately.
The postcondition distinguishes NULL/Unspecified from non-NULL classifications.
The C adapter retains buffer/size priority and code-32/OOM mapping; no decoder,
BOM, explicit-override, or declaration policy changes. Guard pages cover
truncated/unsupported names and rejection before XML reads; all aliases run
through input overwrite/free, DOM use, output, document free and reparsing
against the pinned reference. GNATprove reports 3 checks for `Classify_Bytes`;
the shared `Classify`, `Equal_Name`, and `Upper` contribute 1, 5, and 1 checks.
These contracts do not prove native pointer extents/stability or byte effects;
ABI, diagnostic mapping and full public semantics remain trusted.

## NUL-terminated document input

`xmlReadDoc` and `xmlParseDoc` now use the existing SPARK `Measure`/`Read_Length`
instead of the C scan. The inclusive `Max_Bytes` bound and failure/zero-length
contract are unchanged; the adapter calls the parser only when a NUL was found.
NULL input retains diagnostics while an empty string reaches the parser.
Measurement adds no allocation or copy and does not inspect bytes after NUL.
Pinned-reference tests cover guard-page terminators, embedded NUL, empty input,
and protected original input followed by DOM use, output, document free and
reparsing. Existing small-bound tests exercise the helper's scan limit; they
do not allocate a maximum-sized C input. Pointer readability/extents/stability,
actual byte reads, C ABI and full public parser semantics remain trusted.

## Source identity (SHA-256)

```text
bcbb596778a6494ca5e9e3ab2191bcb364f4c9f7f11a514c6bff91b7a33c3949  src/xml3_c.adb
d913764c5546900095c87b49f394b39fa764e6f9c8b0ed9ce23db0bf887a5ac5  src/xml3_c.ads
761e9039b44085882da827f41a953a48331b00a9eb784ada76d70362a88ef003  include/libxml3.h
66072f8c4567c0b34ec94f316694791a290f312f6dad53fad4f6a2be770683fd  include/libxml/chvalid.h
c182792b54b0c427b508002c06c6228f7efb31f3b81dc45179c7c7febcb50909  include/libxml/entities.h
60048419b81a8ad53de631cbbfde91954bf2d8b6995adbefe6a1b8d153d05f03  include/libxml/parserInternals.h
e8286ea54caf89b1bf0d7501530fb072eebfde5d16e24107096b0935748fbc6c  include/libxml/uri.h
c688643449bc09c9977197b5b78325eaced0b8852e6bf0dd3497952bb081a5c6  include/libxml/valid.h
c627882f6a5e1fbaa14e99ac93231980994a550c2b25439581417c0c4fd40dc8  src/xml3_dom-import.adb
64707d2b0c629bbc574ed89d97aa4aedc643bde9744d13bf7ffcb3ae7c3f5ddf  src/xml3_dom-import.ads
af96365a55310b08822701ae7765f861d6009b5369cdc9d972b4bc52654fea35  src/xml3_dom-materialize.adb
11b0272dbbf8cf7988fb7c96ef8f104f22db1a1390e2c3f5df0bd6d3f6ef60c1  src/xml3_dom-materialize.ads
1ff1a09e0f8a5350705afe444d03c212f7007c97fe490eaf8a11d30ac4e2ab1c  src/xml3_dom.adb
2d3f9d24f1bb5cad35eb8a7da5095f0c92e4c80393b68f2ee22522f1d821675a  src/xml3_dom.ads
1b0b582fc5ab3c34e5d96d5fce20b536426df9f68fbe4b4e99423785eb978002  src/xml3_dom_allocation.adb
38c4ff80e2a8bafa63579a0cb03026926cb4ad4ee44d2324d86842e119ac1c05  src/xml3_dom_allocation.ads
c25f8e859f3b568737e637ba9e1c8eb0238fcb83aa8de34a09cea35ab1b345aa  src/xml3_dom_bridge.adb
a62a5e86be7f9e74c7618d38a3210b4e31842d1cba5304ad3cf4efd7d32987b8  src/xml3_dom_bridge.ads
6afe9e2f73272bbb594738c8eddafba8b182bc61dbfa8c958600c09b9eae9bd9  src/xml3_dom_constructors.adb
09ff151486509a88bccfa03febd237bbd90f228ca6b4219db4c2eb210c4f2fca  src/xml3_dom_constructors.ads
46fd9519a39976fcfbd0c9d8602b8e4f969e16547203f1022eb19718a862a2f8  src/xml3_dom_lock.adb
3010f199780bd3bc276580641cd87e54520e4bbaa1893c40b3b079b8e0439535  src/xml3_dom_lock.ads
804f1a3371bc434ce35784d7605c6a8153f401b55da2fbb8a49145a71bc42e1b  src/xml3_dom_mutex.c
60468a5397b526755d69964b15dc5ea8c53ccd76a02c3b7734b50707098bddc4  src/xml3_dom_runtime.adb
ad6bf14b471b3955f55cb46ac5bfefade69c954f338b926e771f9892e8615e3c  src/xml3_dom_runtime.ads
8f0ec7c10b1a7e8cc713cce07d2a679bb8435b8762409a65ae762cd33abb1da2  src/xml3_dom_store-content.adb
d435b0b71a5c32c26e14e816fd0e1286a52c190dcbdcdabac9106edc352723fe  src/xml3_dom_store-content.ads
7049538ece6d409cc138892870026f1216109b19baca4afe45a605160b9100e5  src/xml3_dom_store-documents.adb
6c52972b1a9bedcd5032918c0ae52efce069d7ab512555822beec7c833aae4c3  src/xml3_dom_store-documents.ads
2e00b21bc02cd7487ec57928182f9937e446d2ee0c2446ab246ee817d60c0c43  src/xml3_dom_store-properties.adb
75b21d6feaa1e9f26f08ece87e33f4b46f7f9b4c9311d60a130d03701a91aabb  src/xml3_dom_store-properties.ads
f949322c7f7db2f6988dc2beffe18707d30bfad6b768b6297658137d19d0c3b4  src/xml3_dom_store-queries.adb
f9230db704d5565e713241caf4484175e366e599730c9930fb386e0468636f22  src/xml3_dom_store-queries.ads
34aeae7dcdb99a887cf2413143eadd3d29a4d1b961f30c8ea6b21978bb95f9a3  src/xml3_dom_store-serialization.adb
af548cf41f7c38481f33c60efb9ab775a6fdcc04378f1a4ebd428c62a11b7d56  src/xml3_dom_store-serialization.ads
c58013fd806a30acb401ec56d6f6cf17010e026440b258e129b2a27bf574b302  src/xml3_dom_store.adb
050295d0cc9898f349737c3504194b2f822a7d4ee930f424c381c7e2c43f6d76  src/xml3_dom_store.ads
d6e1af24bbd85fb650716149f6a027e398b36daecba00be6179d6a910bcaf34d  src/xml3_encoding.adb
9ceb46a1797cfb01ee7a6ecb3a73ad5901bd264edb9715929d6c5f5882e2683e  src/xml3_encoding.ads
ebe2fb7188a68cf66761bc33a6667f1d2a51b6bedc5fa6ace8d746bd0ac33cca  src/xml3_encoding-buffers.adb
de07017f1ffcf80bed5df4869f67e2875dd2abaabbca37340c1ea179a7232b34  src/xml3_encoding-buffers.ads
53fed6a5a3374aa4f67ff6865a0d703274f89bfd44f036285a2166a31d843cfe  src/xml3_error_tls.c
ea5fb0d9851f8262d8ced6e2b2d4319125ed28dbc93c1deedf308823214b6d01  src/xml3_errors.adb
bc9416be82db99c3e992e91890de4024179f16fec29b3685b905212913d0a2c3  src/xml3_errors.ads
09734ebf88516572b7fbd7dc1b023316755d8ab156d7fcce58e2c785c0ec219f  src/xml3_namespaces.adb
055155bfd5a5e8b1c55cba12d27739810c9e70c6e3bb979f2aee07d4e9372831  src/xml3_namespaces.ads
27864d51e26e31e6459e0201d2932aa596592cc020366a3e60efd894a2f8ac92  src/xml3_native_memory.adb
253b7461252644c8b3d4135feba70582d31163dc1d2e6d44813beb1cc18dad6b  src/xml3_native_memory.ads
a2dd0794d3179e2f24d0827e75171abd04f416c952369a2266237ef9640a115f  src/xml3_parser.adb
8a8a1072a61711b93dcd35e5d7f10f2850d7180f6768b601478e0cde8364dc5c  src/xml3_serialization.adb
80ac8796a138b37de53368b154c0d1b0c9a98038d26d774f3a50658b670dd7ce  src/xml3_serialization.ads
5883e231cf0b6c7d7d81f6958665c21d77188f1bae9678a3706e4372c5c686df  src/xml3_parser.ads
eec5b19f01e1825c382a1df63677de010e792560f6874926f0dbfa927d06cc23  src/xml3_text.adb
26b152be00875c73f149041cb8e5ae0e0524065f8c8c5095c85389b2d36fcae9  src/xml3_text.ads
05e393dd15e0bcd89400ce784838371941f95bd1ac2e129fdb396f4cba94485e  src/xml3_text-qnames.adb
8fb4f085a0ade03d03c58f9e0d50a5349f500479afd2ac7c59eeaefcc00f0302  src/xml3_text-qnames.ads
e90a052a7062323a771955dcd002050cfb1cc097a74785dc59b823aa8c2a9317  src/xml3_text-buffers.adb
0ee5951176132380664985a03e7044f487e1b274899ef388d3f8ee677fcfd8d4  src/xml3_text-buffers.ads
4505b7c86e532182feeb995fe815c5b2e8ff1f2408310ca80e9153b73f3df01a  include/libxml/tree.h
dd8e13d68bed61197b021ef6ab6d35b37e5ba01073015cdd490203fc2ae19e0b  include/libxml/xmlstring.h
dcb0678d680679e8e777964ca8203cd3db64e22918bbff58960a3237f7fe51dd  proof.gpr
5ad0affe7e6bcd3fbef62dae8cc27dbc3936a9a4485e4a34bddb65a054fc7431  libxml3.gpr
65098019b727bb87c63e307f87104603cb6bcf1d90b5c97e4033f5628b3cfca5  Makefile
c5269fafd0c1bab521ca0e18f279ed6c5dc7ef0b10151bb4c3618381984005b7  .github/workflows/manual.yml
```

A source or contract change invalidates this record until proof is rerun.
Solver percentages can vary without changing the obligations. The proof
assumes the compiler, translator, solvers and runtime model are sound;
resource exhaustion and foreign-memory behavior remain outside it.
