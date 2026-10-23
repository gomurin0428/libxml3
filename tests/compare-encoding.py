#!/usr/bin/env python3
"""Compare frozen UTF-16 observations against libxml2 and libxml3."""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ORACLE = ROOT / "tests" / "encoding-oracle.json"
EXECUTABLES = (ROOT / "tests" / "encoding-snapshot",
               ROOT / "tests" / "encoding-snapshot-reference")
FIELDS = ("tree", "domain", "code", "level", "line", "int1", "int2",
          "name_hex", "content_hex", "attribute_hex")


def load_oracle(path=ORACLE):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def snapshot(executable, case):
    data = bytes.fromhex(case["input_hex"])
    encoding = case["encoding"] or "-"
    completed = subprocess.run(
        [str(executable), str(len(data)), encoding],
        input=data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return json.loads(completed.stdout)


def selected_fields(snapshot_value):
    return {field: snapshot_value.get(field) for field in FIELDS}


def compare_case(executable, case, expected):
    actual = snapshot(executable, case)
    wanted = selected_fields(expected)
    if actual != wanted:
        differences = {
            field: {"expected": wanted[field], "actual": actual.get(field)}
            for field in FIELDS if wanted[field] != actual.get(field)
        }
        raise AssertionError(
            f"{case['name']}: snapshot differs: "
            f"{json.dumps(differences, sort_keys=True)}"
        )


def compare_oracle(oracle=None):
    if oracle is None:
        oracle = load_oracle()
    cases = oracle["cases"]
    implementation, reference = EXECUTABLES
    for case in cases:
        compare_case(reference, case, case["expected"])
        if "libxml3_expected" in case:
            reason = case.get("libxml3_difference")
            if not isinstance(reason, str) or not reason.strip():
                raise AssertionError(
                    f"{case['name']}: libxml3 difference requires a reason"
                )
            expected = case["libxml3_expected"]
        else:
            expected = case["expected"]
        compare_case(implementation, case, expected)
    print(f"UTF-16 oracle passed: {len(cases)} frozen cases per library")


if __name__ == "__main__":
    compare_oracle()
