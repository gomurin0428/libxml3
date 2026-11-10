#!/usr/bin/env python3
"""Run GNATprove one compilation unit at a time and check the aggregate.

GNATprove analyzes units modularly, so proving every unit of proof.gpr
separately covers the same verification conditions as one whole-project
run, while each invocation stays short and an interrupted run can resume
where it stopped.  The summary GNATprove writes after the last unit
aggregates the results of every unit in the object directory, and is
checked here for completeness and for unproved checks.

Usage:
  eng/prove_units.py [--clean] [--timeout S] [--memlimit MB] [-j N]
                     [--gnatprove PATH] [UNIT ...]

Without --clean, units already completed by a previous run (with the same
switches) are skipped.  Naming units restricts the run to them; the final
check then still covers every unit of the project.

Completion stamps record the switches, not the sources: start again with
--clean after changing a proved source.
"""

import argparse
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "proof.gpr"
OBJECT_DIR = ROOT / "obj" / "proof"
STATE_DIR = OBJECT_DIR / "units"
SUMMARY = OBJECT_DIR / "gnatprove" / "gnatprove.out"
UNPROVED = re.compile(r": (low|medium|high|error):")


def units_of(project: Path) -> dict[str, list[str]]:
    text = project.read_text()
    files = re.findall(r'"([A-Za-z0-9_.-]+\.ad[sb])"', text)
    units: dict[str, list[str]] = {}
    for name in files:
        units.setdefault(name[:-4], []).append(name)
    return units


def own_failure(log: Path, returncode: int) -> list[str]:
    """Messages showing that this run itself failed.

    GNATprove's exit status also reflects unproved checks of other units in
    the aggregate, so a run is judged by its own messages."""
    text = log.read_text()
    problems = [line.rstrip() for line in text.splitlines()
                if UNPROVED.search(line)]
    if "BUG DETECTED" in text:
        problems.append("GNATprove reported an internal error")
    if (returncode != 0 and not problems and
            "unproved check messages considered as errors" not in text):
        problems.append(f"gnatprove exited with status {returncode}")
    return problems


def run(args, command: list[str], log: Path) -> list[str]:
    with log.open("w") as out:
        result = subprocess.run([args.gnatprove, "-P", str(PROJECT),
                                 *command], cwd=ROOT, stdout=out,
                                stderr=subprocess.STDOUT, check=False)
    return own_failure(log, result.returncode)


def summary_problems(units: dict[str, list[str]]) -> list[str]:
    if not SUMMARY.exists():
        return [f"{SUMMARY} is missing"]
    text = SUMMARY.read_text()
    problems = []
    analyzed = re.search(r"^Analyzed (\d+) units", text, re.M)
    if not analyzed or int(analyzed.group(1)) != len(units):
        found = analyzed.group(1) if analyzed else "no"
        problems.append(f"summary analyzed {found} units, expected {len(units)}")
    missing = [u for u in units if f"in unit {u}," not in text]
    if missing:
        problems.append("units missing from summary: " + ", ".join(missing))
    total = re.search(r"^Total\s+(\d+).*$", text, re.M)
    if not total:
        problems.append("summary has no Total row")
    else:
        columns = total.group(0).split()
        # Total, flow, provers, justified, unproved: "." means none.
        if columns[-2] != "." or columns[-1] != ".":
            problems.append("summary reports justified or unproved checks: "
                            + total.group(0))
    if "not proved" in text:
        problems.append("summary lists entities that are not proved")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--clean", action="store_true",
                        help="remove previous proof results before starting")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--memlimit", type=int, default=4096)
    parser.add_argument("-j", dest="jobs", type=int, default=4)
    parser.add_argument("--gnatprove", default=shutil.which("gnatprove")
                        or "gnatprove")
    parser.add_argument("units", nargs="*")
    args = parser.parse_args()

    units = units_of(PROJECT)
    unknown = [u for u in args.units if u not in units]
    if unknown:
        print("unknown units: " + ", ".join(unknown), file=sys.stderr)
        return 2
    selected = args.units or list(units)
    switches = ["--mode=all", "--prover=cvc5,z3",
                f"--timeout={args.timeout}", f"--memlimit={args.memlimit}",
                f"-j{args.jobs}"]
    stamp_text = " ".join(switches) + "\n"

    if args.clean:
        subprocess.run([args.gnatprove, "-P", str(PROJECT), "--clean"],
                       cwd=ROOT, check=False, stdout=subprocess.DEVNULL)
        shutil.rmtree(STATE_DIR, ignore_errors=True)
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    failed = []
    for unit in selected:
        stamp = STATE_DIR / f"{unit}.done"
        log = STATE_DIR / f"{unit}.log"
        if stamp.exists() and stamp.read_text() == stamp_text:
            print(f"skip   {unit} (already proved)", flush=True)
            continue
        stamp.unlink(missing_ok=True)
        start = time.monotonic()
        print(f"prove  {unit}", flush=True)
        messages = run(args, [*switches, "-u", *units[unit]], log)
        elapsed = time.monotonic() - start
        if messages:
            failed.append(unit)
            print(f"FAIL   {unit} ({elapsed:.0f}s), see {log}", flush=True)
            for line in messages[:20]:
                print(f"       {line}", flush=True)
        else:
            stamp.write_text(stamp_text)
            print(f"ok     {unit} ({elapsed:.0f}s)", flush=True)

    if failed:
        print("failed units: " + ", ".join(failed), file=sys.stderr)
        return 1
    pending = [u for u in units
               if not (STATE_DIR / f"{u}.done").exists()
               or (STATE_DIR / f"{u}.done").read_text() != stamp_text]
    if pending:
        print("units not yet proved with these switches: "
              + ", ".join(pending))
        return 0 if args.units else 1
    problems = summary_problems(units)
    for problem in problems:
        print(problem, file=sys.stderr)
    if problems:
        return 1
    print(f"all {len(units)} units proved; summary: "
          f"{SUMMARY.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
