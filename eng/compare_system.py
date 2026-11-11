#!/usr/bin/env python3
"""Compare the differential output of libxml3 with the OS libxml2.

`make compare` checks libxml3 against the pinned reference build, which is
the compatibility baseline.  This auxiliary comparison runs the same corpus
against whatever libxml2 the operating system provides, which may be older.
An older libxml2 can differ from the baseline in ways libxml3 deliberately
does not reproduce; those differences are listed in KNOWN_DIFFERENCES with
the libxml2 versions they apply to, and the system output is normalized for
them before comparing.  Every other difference fails the comparison.

Usage:
  eng/compare_system.py --system-version X.Y.Z SYSTEM_OUT LIBXML3_OUT
"""

import argparse
import difflib
import re
import sys
from dataclasses import dataclass
from typing import Callable

# A namespace value in the differential output: "<type>:<prefix>=<href>",
# where prefix and href are hex-encoded bytes or "null".
NAMESPACE = re.compile(
    r"(?P<lead>(?:^|[ (])(?:ns|def|prefix|uri):\d+:(?:[0-9a-f]*|null)=)"
    r"(?P<href>[0-9a-f]*)(?=[ )]|$)")


def map_hrefs(line: str, change: Callable[[bytes], bytes]) -> str:
    def replace(match: re.Match) -> str:
        href = match.group("href")
        if len(href) % 2:
            return match.group(0)
        return match.group("lead") + change(bytes.fromhex(href)).hex()
    return NAMESPACE.sub(replace, line)


def decode_amp_reference(line: str) -> str:
    return map_hrefs(line, lambda value: value.replace(b"&#38;", b"&"))


@dataclass(frozen=True)
class KnownDifference:
    name: str
    before: tuple[int, int, int]  # first libxml2 version without it
    description: str
    normalize: Callable[[str], str]


KNOWN_DIFFERENCES = [
    KnownDifference(
        name="namespace-amp-reference",
        before=(2, 13, 0),
        description=(
            "libxml2 before 2.13.0 kept '&amp;' and '&#38;' in a namespace "
            "declaration as the text '&#38;' in the namespace name when "
            "entities are not substituted. Reported as libxslt issue 106 "
            "and fixed upstream by commit f506ec66 (parser: Always decode "
            "entities in namespace URIs, regression test "
            "test/entity-in-ns-uri.xml); the baseline and libxml3 decode "
            "it to '&'."),
        normalize=decode_amp_reference),
]


def parse_version(text: str) -> tuple[int, int, int]:
    parts = text.strip().split(".")
    if len(parts) != 3 or not all(part.isdigit() for part in parts):
        raise argparse.ArgumentTypeError(f"not a version: {text!r}")
    return tuple(int(part) for part in parts)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--system-version", type=parse_version, required=True)
    parser.add_argument("system_output")
    parser.add_argument("libxml3_output")
    args = parser.parse_args()

    with open(args.system_output, encoding="ascii") as handle:
        system = handle.read().splitlines()
    with open(args.libxml3_output, encoding="ascii") as handle:
        libxml3 = handle.read().splitlines()

    version = ".".join(map(str, args.system_version))
    applicable = [item for item in KNOWN_DIFFERENCES
                  if args.system_version < item.before]
    normalized = system
    for item in applicable:
        changed = [item.normalize(line) for line in normalized]
        count = sum(old != new for old, new in zip(normalized, changed))
        print(f"system libxml2 {version}: known difference {item.name} "
              f"normalized on {count} line(s)")
        normalized = changed

    if normalized == libxml3:
        print(f"system libxml2 {version}: outputs match "
              f"({len(libxml3)} lines)")
        return 0
    sys.stdout.writelines(difflib.unified_diff(
        [line + "\n" for line in normalized],
        [line + "\n" for line in libxml3],
        fromfile=f"{args.system_output} (normalized)",
        tofile=args.libxml3_output))
    return 1


if __name__ == "__main__":
    sys.exit(main())
