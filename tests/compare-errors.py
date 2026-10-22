import json
import subprocess
import sys


FIELDS = ("tree", "domain", "code", "level", "line", "int1", "int2")
EXECUTABLES = ("./tests/error-snapshot-reference", "./tests/error-snapshot")


def numeric_snapshot(expected):
    return {field: expected.get(field) for field in FIELDS}


def load_oracle(path):
    with open(path, encoding="utf-8") as fixture:
        oracle = json.load(fixture)
    if oracle["version"] != "2.15.4":
        raise AssertionError(f"unexpected oracle version: {oracle['version']}")
    return oracle


def input_hex(case):
    if "input_hex" in case:
        return case["input_hex"]
    return case["input"].encode("utf-8").hex()


def compare(executable, reference, cases, known_differences=()):
    overrides = {}
    if not reference:
        for difference in known_differences:
            index = difference["case_index"]
            if index in overrides or not difference.get("reason"):
                raise AssertionError(f"invalid duplicate/undocumented difference: {index}")
            if not set(difference["fields"]).issubset(FIELDS):
                raise AssertionError(f"unsupported difference fields at case {index}")
            overrides[index] = difference["fields"]
    for index, case in enumerate(cases):
        expected = numeric_snapshot(case["expected"])
        expected.update(overrides.get(index, {}))
        result = subprocess.run(
            [executable, input_hex(case)],
            check=True,
            capture_output=True,
            text=True,
        )
        actual = json.loads(result.stdout)
        if actual != expected:
            raise AssertionError(
                f"{executable}: frozen case {index} differs\n"
                f"input={input_hex(case)}\n"
                f"expected={expected}\nactual={actual}"
            )


def compare_sequence(executable, sequence):
    result = subprocess.run(
        [executable, "--sequence"], check=True, capture_output=True, text=True
    )
    actual = [json.loads(line) for line in result.stdout.splitlines()]
    expected = [numeric_snapshot(state) for state in sequence]
    if actual != expected:
        raise AssertionError(
            f"{executable}: frozen state sequence differs\n"
            f"expected={expected}\nactual={actual}"
        )


def compare_limits(oracle):
    for index, case in enumerate(oracle["cases"]):
        prefix = case["prefix"].encode("utf-8")
        data = prefix + b"x" * case["length"] + case["suffix"].encode("utf-8")
        for executable in EXECUTABLES:
            expected = numeric_snapshot(case["expected"])
            if executable == "./tests/error-snapshot":
                # libxml3 uses the public value ceiling, not upstream's
                # internal lookahead-buffer limit (docs/compatibility.md).
                if case["length"] <= 10_000_000:
                    expected = numeric_snapshot({"tree": True})
                else:
                    expected = dict(tree=False, domain=1, code=114, level=3,
                                    line=1, int1=0, int2=len(prefix) + 1)
            result = subprocess.run(
                [executable, "--stdin", str(len(data))],
                input=data, check=True, capture_output=True,
            )
            actual = json.loads(result.stdout)
            if actual != expected:
                raise AssertionError(
                    f"{executable}: frozen limit case {index} differs "
                    f"({case['context']}, length={case['length']})\n"
                    f"expected={expected}\nactual={actual}"
                )


def main():
    if sys.argv[1:] == ["--limits"]:
        oracle = load_oracle("tests/limit-error-oracle.json")
        compare_limits(oracle)
        print(f"frozen limit oracle passed: {len(oracle['cases'])} cases per library")
        return
    if sys.argv[1:]:
        raise SystemExit("usage: compare-errors.py [--limits]")
    oracle = load_oracle("tests/error-oracle.json")
    compare("./tests/error-snapshot-reference", True, oracle["cases"])
    compare(
        "./tests/error-snapshot",
        False,
        oracle["cases"],
        oracle.get("libxml3_known_differences", ()),
    )
    for executable in EXECUTABLES:
        compare_sequence(executable, oracle["state_sequence"])
    print(f"frozen error oracle passed: {len(oracle['cases'])} cases per library")
    print(f"frozen state sequence passed: {len(oracle['state_sequence'])} steps per library")


if __name__ == "__main__":
    main()
