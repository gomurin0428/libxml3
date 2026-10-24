# SPARK proof evidence

## Result

GNATprove completed with exit code **0**, **3,358 discharged checks**, **0 unproved**,
and **0 justified**. The run emitted non-failing warnings about unused outputs and
assignments; no proof checks remained unproved.
The unedited analyzer summary is in [proof-summary.txt](proof-summary.txt).
This reports the parser/decoder and new DOM foundation, not a proof of the
C-facing library or full XML conformance. **The public C API still uses the old
DOM implementation.** See [assurance.md](assurance.md).

| Category | Checks |
| --- | ---: |
| Data dependencies | 91 |
| Initialization | 117 |
| Run-time checks | 1,833 |
| Assertions / loop invariants | 497 |
| Functional contracts | 697 |
| Termination | 123 |
| Total | 3,358 |

287 checks were discharged by flow analysis and 3,071 by proof. `Parse`, `Decode`,
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

The proof project selects six complete SPARK units (the original four plus
`XML3_DOM` and `XML3_DOM_Bridge`) and the two trusted boundary specs
`XML3_Native_Memory` and `XML3_DOM_Allocation`; the analyzer reports eight units.
The two native bodies remain explicitly outside SPARK. Native memory layout and
allocation correctness are trusted, not replaced with a proved implementation.
The Ada C adapter is **not** in this proof project. All SPARK preconditions must
be established by callers; new DOM contracts do not cover exported functions
that still use the legacy implementation.

DOM runtime checks: `make test-dom-core test-dom-bridge build` passed. The bridge
test uses real allocated facades read through the public C headers and wraps
`free` to check projection ordering and tracked-allocation lifetimes. It is not
a test of the exported C APIs using the new state store: they are not connected.

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
449b6910327b1fc541c2247fd3bf01f0f7839a3b6339534d869c03cafd371113  src/xml3_dom.ads
1e1b4c201124be3357b3696585a47a98d37d11f9b50fe825d364e29529408814  src/xml3_dom.adb
c8330e5907f2b6f3be23757a20b3a02e37b5a282e1d8ed8b3ddd6d139d41dd40  src/xml3_dom_bridge.ads
db96daf269750c2bdfc57ac56a3353c34cb445f591454d86a53829645e7737de  src/xml3_dom_bridge.adb
414c2f0326017f5e816a3c3172ba31d9993e4fcd21ba8b0600c539ef29411991  src/xml3_native_memory.ads
4f21092f60816af983662a55496e98ed8c5d74ad82a4e66bd131dfd6b6e14d27  src/xml3_native_memory.adb
b87754dd3f575f8f64ad374aee2832ab60bff6eb9c2477900f743d7805865122  src/xml3_dom_allocation.ads
42b3dd88e64ac8b1e6ccc43947ae926102ca80aa06de6c29ea77356f88e2b7a3  src/xml3_dom_allocation.adb
13834802bd21b8a91f07d051f0b4ea1731ebac3ab081b6952ad1552e6bf6315b  proof.gpr
```

A source or contract change invalidates the recorded result until proof is rerun.
Solver workload/percentages may differ between machines without changing the
obligations. The proof assumes the soundness of the compiler, proof translation,
solvers and runtime model; resource exhaustion and the FFI remain outside it.
