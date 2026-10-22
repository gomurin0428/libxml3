import json
import subprocess
import sys


def input_hex(case):
    if "input_hex" in case:
        return case["input_hex"]
    return case["input"].encode("utf-8").hex()


def compare(executable, reference, cases, known_differences=()):
    fields = ("tree", "domain", "code", "level", "line", "int1", "int2")
    overrides = {}
    if not reference:
        for difference in known_differences:
            index = difference["case_index"]
            if index in overrides or not difference.get("reason"):
                raise AssertionError(f"invalid duplicate/undocumented difference: {index}")
            if not set(difference["fields"]).issubset(fields):
                raise AssertionError(f"unsupported difference fields at case {index}")
            overrides[index] = difference["fields"]
    for index, case in enumerate(cases):
        expected = {field: case["expected"].get(field) for field in fields}
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


def main():
    with open("tests/error-oracle.json", encoding="utf-8") as fixture:
        oracle = json.load(fixture)
    if oracle["version"] != "2.15.4":
        raise AssertionError(f"unexpected oracle version: {oracle['version']}")
    compare("./tests/error-snapshot-reference", True, oracle["cases"])
    compare(
        "./tests/error-snapshot",
        False,
        oracle["cases"],
        oracle.get("libxml3_known_differences", ()),
    )
    print(f"frozen error oracle passed: {len(oracle['cases'])} cases per library")


if __name__ == "__main__":
    main()
