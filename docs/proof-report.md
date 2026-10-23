# SPARK proof evidence

## Result

GNATprove completed with exit code **0**, **989 discharged checks**, **0 unproved**,
and **0 justified**. The run emitted non-failing warnings about unused outputs and
assignments; no proof checks remained unproved.
The unedited analyzer summary is in [proof-summary.txt](proof-summary.txt).
This is a report for the four SPARK units, not a proof of the C-facing library as
a whole and not a proof of full XML conformance. See [assurance.md](assurance.md).

| Category | Checks |
| --- | ---: |
| Data dependencies | 13 |
| Initialization | 87 |
| Run-time checks | 592 |
| Assertions / loop invariants | 98 |
| Functional contracts | 156 |
| Termination | 43 |
| Total | 989 |

123 checks were discharged by flow analysis and 866 by proof. `Parse`, `Decode`,
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

The proof project explicitly selects all four complete core specs and bodies. It
does **not** include the Ada C adapter. No model replaces a core body and no
imported executable function appears in the core. All public core preconditions
must be established by their callers; the C adapter is outside the proof scope
and checks input sizes and array bounds while supplying heap workspaces to the core.

## Source identity (SHA-256)

```text
7e1c81bf4f77e1e6d433710179b63f28bf00057aeef6f5cf07708a113dd4d809  src/xml3_text.ads
47f78aaebd907be02955b0d9b991eb47d7b2c344c3cae7b924a7ca575ba10c5b  src/xml3_text.adb
07138e9a9c47e6ae18255e627b814b29f688e4e89b954913cdabf264d75b53c1  src/xml3_parser.ads
d8c805436661fc48888321833a25eb594a19789b3231af2abc8463f31e1874e9  src/xml3_parser.adb
055155bfd5a5e8b1c55cba12d27739810c9e70c6e3bb979f2aee07d4e9372831  src/xml3_namespaces.ads
09734ebf88516572b7fbd7dc1b023316755d8ab156d7fcce58e2c785c0ec219f  src/xml3_namespaces.adb
095e4c527eced72f9fe7d7cf91f4fe637358beb094a53b9bde84bf3c2f6a904d  src/xml3_encoding.ads
7a7d9e2c073d9619dfe9e2945e8454ba957e9e8fd7da915d91cf724a9d2542af  src/xml3_encoding.adb
acdafd1faea5cde058a67f4d85a89822f420e1d74f1dfa6178684fb2a82e40ae  proof.gpr
```

A source or contract change invalidates the recorded result until proof is rerun.
Solver workload/percentages may differ between machines without changing the
obligations. The proof assumes the soundness of the compiler, proof translation,
solvers and runtime model; resource exhaustion and the FFI remain outside it.
