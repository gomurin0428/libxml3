# SPARK proof evidence

## Result

GNATprove completed with exit code **0**, **6,432 discharged checks**, **0 unproved**,
and **0 justified**. Non-failing warnings remain for unused outputs and
assignments, unavailable termination aspects on trusted external operations, and
representation generation for a trusted package spec; no proof checks remained
unproved.
The unedited analyzer summary is in [proof-summary.txt](proof-summary.txt).
This reports the parser/decoder and new DOM foundation, not a proof of the
C-facing library or full XML conformance. **The public C API still uses the old
DOM implementation.** See [assurance.md](assurance.md).

| Category | Checks |
| --- | ---: |
| Data dependencies | 154 |
| Initialization | 230 |
| Run-time checks | 3,224 |
| Assertions / loop invariants | 884 |
| Functional contracts | 1,789 |
| Termination | 151 |
| Total | 6,432 |

488 checks were discharged by flow analysis and 5,944 by proof. `Parse`, `Decode`,
namespace `Resolve`, and UTF-16 `Decode_UTF16` have explicit
`Always_Terminates` aspects.
Termination does not mean constant time
or a proved wall-clock bound. The numerical totals are the analyzer's categories;
they are not counts of vulnerabilities, test cases, or supported APIs.

## Reproduction

Verified on Ubuntu 22.04.5 x86_64 (glibc 2.35) using Alire packages
`gnat_native=14.2.1`, `gprbuild=26.0.1`, and `gnatprove=14.1.1`.
The GNAT compiler banner is 14.2.0. This GNATprove distribution reports `0.0w`
as its own version banner; **14.1.1 refers to the pinned Alire package**, not that
banner. Bundled Why3 is 1.6.0+git, cvc5 is 1.1.2 and Z3 is 4.13.0.

From the repository root, with the pinned toolchain's `bin` directory on PATH:

```sh
gnatprove -P proof.gpr --mode=all --prover=cvc5,z3 --timeout=10 -j4
```

`proof.gpr` sets `--level=2 --report=all --checks-as-errors=on`. The command must
exit unsuccessfully if proof checks remain unproved. Earlier incomplete-proof
runs did exit with code 1; no check suppressions or assumption pragmas were added.
The final summary is generated at `obj/proof/gnatprove/gnatprove.out`.
The private `Attach` and its extracted helpers were proved separately with
`--proof=progressive --timeout=10 --counterexamples=off`, followed by the whole
DOM unit and the aggregate invocation above. The aggregate reused that proof
session; this is not evidence of cold-cache proof timing or reproducibility.
Focused whole-unit invocations for `XML3_DOM`, `XML3_DOM.Import`, and
`XML3_DOM_Store` passed before the final aggregate run. The Store proof includes
`Adopt_Arena` and its source/destination rollback contracts. The `Count_Holders`
ghost helper and `Holder_Count` recurrence wrapper also passed proof; `Valid`
and `Pin_Equation` were unchanged. The focused materializer proof included
`Fill_Node` and `Fill_Namespace` and passed with zero unproved checks; the
materializer was unchanged for the Store adoption delta.

The proof project selects ten complete SPARK units (the original four plus
`XML3_DOM`, `XML3_DOM_Bridge`, `XML3_DOM_Constructors`, `XML3_DOM_Store`, and
`XML3_DOM.Import` and `XML3_DOM.Materialize`) and the two trusted boundary specs
`XML3_Native_Memory` and `XML3_DOM_Allocation`; the analyzer reports twelve units.
The two native bodies remain explicitly outside SPARK. Native memory layout and
allocation correctness are trusted, not replaced with a proved implementation.
The full run reported that representation information could not be generated
from the standalone `xml3_dom_allocation.ads` package spec, and continued with
partial representation data. No compiler internal error occurred in the final
run. A development-time GNAT 14 contract-compilation ICE was avoided by taking
explicit array snapshots in contracts, without weakening them. This result is
not evidence for native layout accuracy.
The Ada C adapter is **not** in this proof project. All SPARK preconditions must
be established by callers; new DOM contracts do not cover exported functions
that still use the legacy implementation.

DOM runtime checks for this revision: `make test-dom-core test-dom-bridge`
passed. `make check` also passed on this revision, including both foundation
test targets; `make -n clean` includes both test binaries.
The full proof covers `Replace_Child_Links`, `Replace_Lemma`,
`Attach`, `Replace_Root`, and `Projection_Pins_Allowed`.
The full run also covers the public/internal projection setters. The new tests
exercise position-preserving root replacement, descendant replacement, document
propagation, unchanged graphs on rejection, and public projection mismatch
rejection. These are foundation tests, not exported root-replacement API tests.
`Merge_Text`, `Free_Marked_Subtree`, and its public
`Free_Subtree` wrapper also passed. Merge tests check unchanged graphs for
invalid lengths, null buffers, self-merges and foreign documents, plus sibling
unlinking, target retention and content-owner transitions on success. This is the
logical commit of a prepared merged buffer; buffer allocation, copying and the
public `xmlAddChild` integration are not implemented by this operation.
The bridge
test uses real allocated facades read through the public C headers and wraps
`free` to check projection ordering and tracked-allocation lifetimes. It is not
a test of the exported C APIs using the new state store: they are not connected.
Live-entry framing proofs passed for `Take_Release`,
`Acknowledge_Release`, and `XML3_DOM_Bridge.Synchronize`. The
`Live_Entries_Preserved` frame retains capacity and counts, existing live nodes
and owners, and live namespaces whose pre-state owner was live. This logical
store guarantee does not assert native facade freshness or pointer bounds; the
public XML3_C adapter remains on the legacy implementation.

`XML3_DOM_Constructors.Create_Node` now orchestrates checked allocation sizing,
node/owner registration, implicit XML namespace creation, projection, and
rollback. Registered allocations are retired through the logical store and
release protocol, never directly freed. Its contract preserves pre-existing
live nodes on both success and failure. Capacity growth and facade presence
have explicit frame contracts; a proved leaf-subtree lemma supports rollback.
`Set_Marked_Document` isolates document propagation with an exact node frame.
The native bridge test constructs document/element/text facades from capacity
one, checks fields and strings through C headers, rejects a namespace on a text
node, injects native malloc failure, and verifies detached-node lifetime and
exactly-once freeing. Native bytes, address freshness/non-overlap, and layout
correspondence are still trusted, not proved by these contracts. The exported
`xmlNewDoc`, `xmlNewNode`, and `xmlNewText` are not wired to this constructor yet.

`XML3_DOM_Store` adds an opaque, limited owner of the internal state. It checks
live IDs and exact facade identity before delegating construction, attachment,
root replacement, unlinking and release, synchronizes effects, and reclaims an
empty backing state. Its lifecycle tests cover real C facade fields, namespace
rejection, allocation failure, detached lifetime, final reclamation, and text
merge/rollback ordering. `Add_Child` appends ordinary children or merges
adjacent text with a prepared NUL-terminated buffer. It registers the buffer
with a reserved owner before `Merge_Text`; reservation release and
synchronization route a rejected prepared buffer through the release protocol.
`Adopt_Arena` initializes an empty Store or performs overflow-checked growth for
nodes, namespaces and one owner, calls `Import.Adopt` once, then synchronizes
and returns the imported document facade on success. On failure the source
remains wholly unchanged and caller-owned; newly initialized empty backing
state is reclaimed through `Reclaim_Empty`, and the native source arena is
never directly freed. Tests cover empty-Store allocation failure, map-allocation
failure with an existing document, growth-allocation failure, successful
adoption and native traversal, preservation of the first document during a
second import, unlinking, detached-root lifetime, and final Store cleanup.
The public C API remains on the legacy DOM. Native metadata reads still require
valid library pointers; this is not arbitrary pointer validation or a protected
shared runtime.

Attachment validation, topology mutation and document propagation now have
separate proof boundaries. `Unlink_Tail_Lemma`, `Append_Child_Links`,
`Relink_Marked_Subtree`, the complete private `Attach`, and
`Set_Marked_Document` all passed. Explicit frame and result assertions are
proved obligations, not assumptions; the original attachment contract remains.

`XML3_DOM.Import.Adopt` transfers a single-owner source arena into the destination
without per-node construction/attachment. Checked, strictly increasing maps
translate node/namespace links and pins; existing live/tombstone nodes, live
namespaces, and live/releasing owners are preserved. The destination retains the
source native allocation and the source Ada state is consumed only after
installation. Capacity rejection or map allocation failure preserves both
graphs. No native arena is freed during adoption; synchronization subsequently
rewrites facade metadata IDs. Direct `Import.Adopt` still requires worst-case
append capacity for every source node/namespace and one owner, even though
mapping reuses unused slots. `Store.Adopt_Arena` provides checked destination
initialization/growth around that preflight; free holes alone do not ensure
admission at capacity. This is an internal foundation constraint, not a new
public parser size policy.

The native arena test covers this transfer with reusable node/namespace/owner
slots, unchanged original-document fields, capacity rejection, and a size-targeted
map allocation failure. It checks that source-state consumption does not free the
arena, metadata IDs change on synchronization, a detached subtree keeps its
arena/document/namespace storage alive, and the final native free occurs exactly
once after node and namespace pointer fields are cleared. The test exposed a
missing namespace-clear command: the bridge now uses the proved core query
`Namespace_Release_Required` to emit empty pointer fields when that namespace's
owner is releasing. These tests do not establish arbitrary-pointer validity or
native layout correctness.

`XML3_DOM.Materialize.Build` consumes successful internal parser/resolver output
and directly assembles a fresh candidate arena in SPARK. It assigns node and
namespace IDs, constructs topology and ownership, budgets strings with checked
arithmetic, and initializes one native facade/string block. Its executable
`Check_Arena` validator uses the same per-entry graph predicates as `Valid`;
the proved postcondition establishes validity, editability, facade presence,
arena ownership, and the required projection state. Parser/resolver range facts
do not authorize arbitrary graph metadata: structural inconsistencies are
rejected rather than assumed. On success, the caller adopts the source once and
synchronizes the destination. Non-ghost assembly and append work is linear in
the emitted nodes and namespaces. Assertion-enabled ghost checks can be
superlinear; no wall-clock performance benchmark is claimed.

The bridge integration test exercises actual `Parse` → `Resolve` →
`Materialize.Build` → `Import.Adopt` → `Synchronize` on a mixed XML sample. It
checks the expected 12 DOM nodes and 4 namespaces, the projected C fields,
strings, links, properties, namespace bindings and metadata, plus preservation
of the existing destination document. It injects failure at each of the three
materializer allocations and verifies rollback. An invalid in-range namespace
binding returns `Internal_Error`, publishes no source, and frees all three
acquired allocations exactly once. Detaching and freeing the imported document
also verifies retained subtree/namespace storage and exactly-once arena release.
These tests exercise native allocation and layout correspondence but do not
prove those external-memory properties.

The materializer's native boundary is limited to allocation/free, offset and
address projection, facade initialization, and byte/string writes. Ownership,
topology, graph validation, release decisions, and policy remain in SPARK.
`XML3_C` and its public parser/API routing remain on the legacy implementation.

## Source identity (SHA-256)

```text
7e1c81bf4f77e1e6d433710179b63f28bf00057aeef6f5cf07708a113dd4d809  src/xml3_text.ads
47f78aaebd907be02955b0d9b991eb47d7b2c344c3cae7b924a7ca575ba10c5b  src/xml3_text.adb
07138e9a9c47e6ae18255e627b814b29f688e4e89b954913cdabf264d75b53c1  src/xml3_parser.ads
2e31dde2f0ae750a8af15781b4d22bac59e14b388344c49a9a087021d7883f92  src/xml3_parser.adb
055155bfd5a5e8b1c55cba12d27739810c9e70c6e3bb979f2aee07d4e9372831  src/xml3_namespaces.ads
09734ebf88516572b7fbd7dc1b023316755d8ab156d7fcce58e2c785c0ec219f  src/xml3_namespaces.adb
095e4c527eced72f9fe7d7cf91f4fe637358beb094a53b9bde84bf3c2f6a904d  src/xml3_encoding.ads
7a7d9e2c073d9619dfe9e2945e8454ba957e9e8fd7da915d91cf724a9d2542af  src/xml3_encoding.adb
0c04531dac383e80a73568cb2c306013d5ea74dad1dbd0b5383df400866566b5  src/xml3_dom.ads
ee3d1035e276e306af97a1723de1927ca0598e446cb95fe670678a7a881da852  src/xml3_dom.adb
52e5a8f207dbf63a67ca2d5ad99622ddee3d1d931d2822830dbb490fdd4a5713  src/xml3_dom-import.ads
d96c80620eb295816de0e000a976500fca97c1365d33dd96c57d31a726c2d5eb  src/xml3_dom-import.adb
11b0272dbbf8cf7988fb7c96ef8f104f22db1a1390e2c3f5df0bd6d3f6ef60c1  src/xml3_dom-materialize.ads
16edecdcbf79a79f0568afe025877c9b9113afaab08bf983d5b7dd053b757392  src/xml3_dom-materialize.adb
a62a5e86be7f9e74c7618d38a3210b4e31842d1cba5304ad3cf4efd7d32987b8  src/xml3_dom_bridge.ads
dd29f41eca701df16260920c23075459c3eedc99175d2d9302ee7225d1d945a8  src/xml3_dom_bridge.adb
5a434888dd9904ff0bebfd1ef6aa3711047cf97375d3e0d538f0dc4dbb8d9839  src/xml3_dom_constructors.ads
e98d478d78ae0a0dae9496f7c44188e78aa3f90800b9ac18260963e65b59353f  src/xml3_dom_constructors.adb
58da3a27e44f5600ed0d8dcf03f5e73818c473d45b49b70010a347590adbc1fa  src/xml3_dom_store.ads
d0f36b20a2f2e37a8b121530cb48676e8a0387df0affec40fb8c04fbdc935e21  src/xml3_dom_store.adb
414c2f0326017f5e816a3c3172ba31d9993e4fcd21ba8b0600c539ef29411991  src/xml3_native_memory.ads
4f21092f60816af983662a55496e98ed8c5d74ad82a4e66bd131dfd6b6e14d27  src/xml3_native_memory.adb
38c4ff80e2a8bafa63579a0cb03026926cb4ad4ee44d2324d86842e119ac1c05  src/xml3_dom_allocation.ads
1b0b582fc5ab3c34e5d96d5fce20b536426df9f68fbe4b4e99423785eb978002  src/xml3_dom_allocation.adb
126d2cb2b55b01f0c18ac5ee4dd8f6a4c670f4e2e340e32e2e56f1f20a14f453  proof.gpr
6f5bc198d60a35d2307e415ba89a4ab63fad8568a994887615d84acae966adb5  Makefile
472f04d1a860daaf7d0d381b0b3025f6e6d3b427b167706909c2696cb0f4dc53  tests/dom_bridge_test.gpr
2666eefa8c6789cdc15c13e4c297d4b3bfb9af08898aaaed815cbb42df788b9e  tests/dom_bridge_test.adb
84bf1b9432e3daa394b3da8c29ed55fd72924bafba81ff5632aaedc47cdd7de7  tests/dom_bridge_facade.c
```

A source or contract change invalidates the recorded result until proof is rerun.
Solver workload/percentages may differ between machines without changing the
obligations. The proof assumes the soundness of the compiler, proof translation,
solvers and runtime model; resource exhaustion and the FFI remain outside it.
