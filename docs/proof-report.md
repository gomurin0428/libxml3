# SPARK proof evidence

## Result

GNATprove completed with exit code **0**, **4,309 discharged checks**, **0 unproved**,
and **0 justified**. Non-failing warnings remain for unused outputs and
assignments, trusted external subprogram termination, and representation
generation for a trusted package spec; no proof checks remained unproved.
The unedited analyzer summary is in [proof-summary.txt](proof-summary.txt).
This reports the parser/decoder and new DOM foundation, not a proof of the
C-facing library or full XML conformance. **The public C API still uses the old
DOM implementation.** See [assurance.md](assurance.md).

| Category | Checks |
| --- | ---: |
| Data dependencies | 105 |
| Initialization | 140 |
| Run-time checks | 2,195 |
| Assertions / loop invariants | 614 |
| Functional contracts | 1,123 |
| Termination | 132 |
| Total | 4,309 |

329 checks were discharged by flow analysis and 3,980 by proof. `Parse`, `Decode`,
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
The focused `Attach` proof was also run successfully with `--timeout=30`;
the final aggregate invocation above reused the proof session. A cold run may
need that larger solver budget. This changes neither the contracts nor the
proof obligations.

The proof project selects seven complete SPARK units (the original four plus
`XML3_DOM`, `XML3_DOM_Bridge`, and `XML3_DOM_Constructors`) and the two trusted
boundary specs `XML3_Native_Memory` and `XML3_DOM_Allocation`; the analyzer
reports nine units.
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
0543f81b4e1ad1a7ee9617ec6f7d13bdafcce8587ed02b3b92284f61975e4117  src/xml3_dom.ads
5e89e794c05fb206fb56c332f0179f514ef58649e590b956e1c567dde569d5a1  src/xml3_dom.adb
a62a5e86be7f9e74c7618d38a3210b4e31842d1cba5304ad3cf4efd7d32987b8  src/xml3_dom_bridge.ads
6c5b0151f2d06bc264e23026480383e1ef4a10722785bf26575c50b628dd42c0  src/xml3_dom_bridge.adb
5a434888dd9904ff0bebfd1ef6aa3711047cf97375d3e0d538f0dc4dbb8d9839  src/xml3_dom_constructors.ads
e98d478d78ae0a0dae9496f7c44188e78aa3f90800b9ac18260963e65b59353f  src/xml3_dom_constructors.adb
414c2f0326017f5e816a3c3172ba31d9993e4fcd21ba8b0600c539ef29411991  src/xml3_native_memory.ads
4f21092f60816af983662a55496e98ed8c5d74ad82a4e66bd131dfd6b6e14d27  src/xml3_native_memory.adb
b87754dd3f575f8f64ad374aee2832ab60bff6eb9c2477900f743d7805865122  src/xml3_dom_allocation.ads
42b3dd88e64ac8b1e6ccc43947ae926102ca80aa06de6c29ea77356f88e2b7a3  src/xml3_dom_allocation.adb
e5f2db92eb726b08af031fe32c69348a032682f9abeee3ed5249952a6f3e3d35  proof.gpr
```

A source or contract change invalidates the recorded result until proof is rerun.
Solver workload/percentages may differ between machines without changing the
obligations. The proof assumes the soundness of the compiler, proof translation,
solvers and runtime model; resource exhaustion and the FFI remain outside it.
