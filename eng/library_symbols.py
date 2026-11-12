#!/usr/bin/env python3
"""Generate or check libxml3.sym, the symbols the shared library exports.

The library is linked with gprbuild's restricted symbol policy, so it
exports exactly the names in libxml3.sym: the C entry points the
interface units export (External_Name of an Export aspect in
src/xml3_c.ads and src/xml3_errors.ads), the library's own init and
finalization routines, and the entry points written in C.

Usage:
  eng/library_symbols.py          rewrite libxml3.sym
  eng/library_symbols.py --check  fail when libxml3.sym is stale
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SYMBOL_FILE = ROOT / "libxml3.sym"
INTERFACE_SPECS = ["src/xml3_c.ads", "src/xml3_errors.ads"]
# The library's elaboration and finalization (Library_Auto_Init).
RUNTIME = ["xml3init", "xml3final"]
# Entry points written in C: the formatting with variable arguments
# (src/xml3_format.c) and the allocator (src/xml3_memory.c).
C_ENTRY_POINTS = [
    "xmlStrPrintf", "xmlStrVPrintf",
    "xmlMalloc", "xmlMallocAtomic", "xmlRealloc", "xmlMemStrdup",
    "xmlMemSetup", "xmlMemGet", "xmlGcMemSetup", "xmlGcMemGet",
    "xmlMemMalloc", "xmlMemRealloc", "xmlMemFree", "xmlMemoryStrdup",
    "xmlMallocLoc", "xmlMallocAtomicLoc", "xmlReallocLoc", "xmlMemStrdupLoc",
    "xmlMemSize", "xmlMemUsed", "xmlMemBlocks", "xmlMemDisplayLast",
    "xmlMemDisplay", "xmlMemShow", "xmlMemoryDump", "xmlInitMemory",
    "xmlCleanupMemory",
]
EXPORT = re.compile(r'with\s+Export\b[^;]*?External_Name\s*=>\s*"([^"]+)"',
                    re.S)


def symbols() -> list[str]:
    names = set(RUNTIME) | set(C_ENTRY_POINTS)
    for spec in INTERFACE_SPECS:
        names.update(EXPORT.findall((ROOT / spec).read_text()))
    return sorted(names)


def main() -> int:
    text = "".join(name + "\n" for name in symbols())
    if "--check" in sys.argv[1:]:
        if not SYMBOL_FILE.exists() or SYMBOL_FILE.read_text() != text:
            print(f"Stale generated file: {SYMBOL_FILE}", file=sys.stderr)
            return 1
        return 0
    SYMBOL_FILE.write_text(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
