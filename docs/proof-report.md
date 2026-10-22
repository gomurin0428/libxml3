# SPARK proof evidence

## Result

GNATprove completed with exit code **0**, **648 discharged checks**, **0 unproved**,
and **0 justified**. The run emitted non-failing warnings about unused assignments,
parser outputs, and the initialized scratch value; no proof checks remained unproved.
The unedited analyzer summary is in [proof-summary.txt](proof-summary.txt).
This is a report for the three SPARK units, not a proof of the C-facing library as
a whole and not a proof of full XML conformance. See [assurance.md](assurance.md).

| Category | Checks |
| --- | ---: |
| Data dependencies | 5 |
| Initialization | 60 |
| Run-time checks | 399 |
| Assertions / loop invariants | 75 |
| Functional contracts | 80 |
| Termination | 29 |
| Total | 648 |

79 checks were discharged by flow analysis and 569 by proof. `Parse`, `Decode`,
and namespace `Resolve` have explicit `Always_Terminates` aspects.
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

The proof project explicitly selects all three complete core specs and bodies. It
does **not** include the Ada C adapter. No model replaces a core body and no
imported executable function appears in the core. All public core preconditions
must be established by their callers; the unproved C adapter checks input sizes
and rebases Ada strings before calling them.

## Source identity (SHA-256)

```text
cb20d441b6fdce104d65f7ee67ca140ca7c9815e55315960986334074cdfa7fb  src/xml3_text.ads
1235d69f037ea80169feb37c84db4803ba07f07b2acbf024ea3f2202075f47b3  src/xml3_text.adb
195829f9223c3caddaf52407b9b49cb54879993e012d39239c9df17f94d74eb9  src/xml3_parser.ads
42c65322e4f5d0cd486213f31709ce5d6554e51383ba12ce787b9d0af6656086  src/xml3_parser.adb
821360f81f9f05491c49c31286e8e2bff689463d2dd708d7ad7688561c6b76eb  src/xml3_namespaces.ads
a6ee30ec54d99c8942c62efad12c04826b747588940966afa57c5414f4f5c514  src/xml3_namespaces.adb
67e6636bfadd7ea6ee9ba2a0475cf1072b48c7a66e193944b33ce4d843b51fee  proof.gpr
```

A source or contract change invalidates the recorded result until proof is rerun.
Solver workload/percentages may differ between machines without changing the
obligations. The proof assumes the soundness of the compiler, proof translation,
solvers and runtime model; resource exhaustion and the FFI remain outside it.
