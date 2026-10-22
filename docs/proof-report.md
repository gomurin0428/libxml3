# SPARK proof evidence

## Result

GNATprove completed with exit code **0**, **551 discharged checks**, **0 unproved**,
**0 justified**, and no warning/error diagnostics for the source hashes below.
The unedited analyzer summary is in [proof-summary.txt](proof-summary.txt).
This is a report for the three SPARK units, not a proof of the C-facing library as
a whole and not a proof of full XML conformance. See [assurance.md](assurance.md).

| Category | Checks |
| --- | ---: |
| Data dependencies | 4 |
| Initialization | 52 |
| Run-time checks | 323 |
| Assertions / loop invariants | 64 |
| Functional contracts | 76 |
| Termination | 32 |
| Total | 551 |

74 checks were discharged by flow analysis and 477 by proof. `Parse`, `Decode`,
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
f46613d6d41e08d6005451b93c5cb62acc629bdd297449713907d116f28183a4  src/xml3_text.ads
9fa5dccb353fcaad2a6dbc9de4e4f31335691c59a7f07bbcf8283f2f9307213e  src/xml3_text.adb
97c9d2d32fe4d2f2f1c3dfe2a17189be4ede0eefeddc12c2e77052feb19e6735  src/xml3_parser.ads
288c6bb88cec0fe1dc01265a68bc81b81d0da683e1a53690398c311f0f491aaa  src/xml3_parser.adb
3c6d280155993cf20da3a35b4605bdbf91e906d8e271d7323354574fb0552cba  src/xml3_namespaces.ads
de45df71155d60e0c0264b6e3035c225a31ee2a9940c7de0109815ccece83531  src/xml3_namespaces.adb
67e6636bfadd7ea6ee9ba2a0475cf1072b48c7a66e193944b33ce4d843b51fee  proof.gpr
```

A source or contract change invalidates the recorded result until proof is rerun.
Solver workload/percentages may differ between machines without changing the
obligations. The proof assumes the soundness of the compiler, proof translation,
solvers and runtime model; resource exhaustion and the FFI remain outside it.
