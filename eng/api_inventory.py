#!/usr/bin/python3
"""Inventory declarations, not behavioral compatibility, from a pinned C build."""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from clang import cindex as clang

ROOT = Path(__file__).resolve().parents[1]
KINDS = {
    clang.CursorKind.FUNCTION_DECL: "function",
    clang.CursorKind.VAR_DECL: "variable",
    clang.CursorKind.TYPEDEF_DECL: "typedef",
    clang.CursorKind.STRUCT_DECL: "struct",
    clang.CursorKind.UNION_DECL: "union",
    clang.CursorKind.ENUM_DECL: "enum",
    clang.CursorKind.ENUM_CONSTANT_DECL: "constant",
    clang.CursorKind.FIELD_DECL: "field",
    clang.CursorKind.MACRO_DEFINITION: "macro",
}


def type_spelling(type_, include):
    return type_.spelling.replace(str(include) + "/", "")


def inventory(include, global_allocator=False):
    include = include.resolve()
    headers = sorted((include / "libxml").glob("*.h"))
    if not headers:
        raise ValueError(f"No libxml headers at {include}")
    source = "\n".join(f"#include <libxml/{p.name}>" for p in headers)
    if global_allocator:
        source = "#include <libxml/xmlversion.h>\n#undef LIBXML_THREAD_ALLOC_ENABLED\n" + source
    preprocessed = subprocess.check_output(
        ["clang-14", "-E", "-dM", "-x", "c", "-std=c11", f"-I{include}", "-"],
        input=source, text=True,
    )
    active_macros = {line.split()[1].split("(")[0] for line in preprocessed.splitlines()
                     if line.startswith("#define ")}
    unit = clang.Index.create().parse(
        "api-inventory.c", args=["-x", "c", "-std=c11", f"-I{include}"],
        unsaved_files=[("api-inventory.c", source)],
        options=clang.TranslationUnit.PARSE_DETAILED_PROCESSING_RECORD,
    )
    errors = [str(d) for d in unit.diagnostics if d.severity >= clang.Diagnostic.Error]
    if errors:
        raise ValueError("Header parse failed:\n" + "\n".join(errors))
    entries = {}
    for cursor in unit.cursor.walk_preorder():
        kind = KINDS.get(cursor.kind)
        if kind is None or cursor.location.file is None:
            continue
        path = Path(cursor.location.file.name).resolve()
        if path.parent != include / "libxml":
            continue
        name = cursor.spelling
        if kind in ("enum", "struct", "union") and not name:
            name = f"anonymous@{cursor.location.line}:{cursor.location.column}"
        if not name:
            continue
        declaration = type_spelling(cursor.type, include)
        if kind == "typedef":
            underlying = cursor.underlying_typedef_type
            declaration = type_spelling(underlying, include)
            canonical = underlying.get_canonical()
            if canonical.kind == clang.TypeKind.POINTER and canonical.get_pointee().kind in (
                clang.TypeKind.FUNCTIONPROTO, clang.TypeKind.FUNCTIONNOPROTO
            ):
                kind = "callback"
        if kind == "field":
            parent = cursor.semantic_parent
            parent_name = parent.spelling or f"anonymous@{parent.location.line}:{parent.location.column}"
            name = f"{parent_name}.{name}"
        if kind == "macro":
            if name not in active_macros:
                continue
            declaration = " ".join(t.spelling for t in cursor.get_tokens())
        key = f"{kind}:{path.name}:{name}"
        entry = {"id": key, "kind": kind, "header": path.name,
                 "name": name, "line": cursor.location.line, "declaration": declaration}
        if kind == "constant":
            entry["value"] = cursor.enum_value
        if kind in ("struct", "union", "enum"):
            entry["defined"] = cursor.is_definition()
        if kind == "function":
            entry["parameters"] = [{"name": p.spelling, "type": type_spelling(p.type, include)}
                                   for p in cursor.get_arguments()]
        previous = entries.get(key)
        if previous is not None:
            if kind in ("struct", "union", "enum"):
                if previous["defined"]:
                    continue
            elif previous != entry:
                raise ValueError(f"Conflicting declarations for {key}")
        entries[key] = entry
    return {
        "headers": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in headers},
        "entries": [entries[k] for k in sorted(entries)],
    }


def validate_coverage(catalog, coverage):
    entries = {e["id"]: e for e in catalog["entries"]}
    for key, row in coverage.items():
        if key not in entries:
            raise ValueError(f"Coverage for unknown declaration: {key}")
        if row["implementation"] not in ("partial", "implemented"):
            raise ValueError(f"Invalid implementation status: {key}")
        if row["proof"] != "not-proved":
            raise ValueError("C API inventory cannot inherit the core's proof")
        if not row["scope"] or not row["tests"]:
            raise ValueError(f"Missing scope or evidence: {key}")
        for evidence in row["tests"]:
            if not (ROOT / evidence).is_file():
                raise ValueError(f"Missing test file: {evidence}")


def render(catalog, coverage):
    validate_coverage(catalog, coverage)
    counts = Counter(e["kind"] for e in catalog["entries"])
    by_header = Counter(e["header"] for e in catalog["entries"])
    lines = ["# API台帳（生成物）", "",
             f"基準: libxml2 {catalog['baseline']['version']} / `{catalog['baseline']['commit']}`。", "",
             "これは宣言の台帳です。関数の存在・型の一致・テスト成功・形式証明は別の指標です。",
             "未記載のcoverageは未評価・未比較・未証明を意味します。完全互換率は算出しません。",
             "対象構成外の条件付き宣言は含まず、マクロにはヘッダーガード等も含みます。",
             "抽出範囲・再生成手順は [compatibility-baseline.md](compatibility-baseline.md) を参照。", "",
             "## 宣言種別", "", "| 種別 | 件数 |", "| --- | ---: |"]
    lines.extend(f"| {k} | {v} |" for k, v in sorted(counts.items()))
    lines.extend(["", "## ヘッダー", "", "| ヘッダー | 宣言数 |", "| --- | ---: |"])
    lines.extend(f"| {k} | {by_header[k]} |" for k in catalog["headers"])
    lines.extend(["", "## 現在の実装・比較範囲", "",
                  "比較テストの実行結果はPRに記録します。下表はテストへの対応付けで、全入力の等価性を主張しません。", "",
                  "| 宣言 | 実装 | 範囲 | テスト | C APIの証明 |", "| --- | --- | --- | --- | --- |"])
    for key, row in sorted(coverage.items()):
        tests = ", ".join(f"[{p}](../{p})" for p in row["tests"])
        lines.append(f"| `{key}` | {row['implementation']} | {row['scope']} | {tests} | {row['proof']} |")
    return "\n".join(lines) + "\n"


def write_or_check(path, data, check):
    if check:
        if not path.is_file() or path.read_text() != data:
            raise ValueError(f"Stale generated file: {path}")
    else:
        path.write_text(data)


def serialize(catalog):
    metadata = {k: v for k, v in catalog.items() if k != "entries"}
    prefix = json.dumps(metadata, indent=2, ensure_ascii=False).rstrip()[:-1]
    rows = ",\n".join("    " + json.dumps(e, ensure_ascii=False, sort_keys=True)
                       for e in catalog["entries"])
    return prefix.rstrip() + ',\n  "entries": [\n' + rows + "\n  ]\n}\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--include", type=Path,
                        default=ROOT / "build/reference/include/libxml2")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--report-only", action="store_true",
                        help="Render frozen inventory without re-reading upstream headers")
    args = parser.parse_args()
    baseline = json.loads((ROOT / "compat/baseline.json").read_text())
    target = ROOT / "compat/api-inventory.json"
    if args.report_only:
        catalog = json.loads(target.read_text())
        if catalog["baseline"] != baseline:
            raise ValueError("Inventory uses a different baseline")
    else:
        catalog = {"baseline": baseline, **inventory(args.include)}
        entries = {e["id"]: dict(e, profiles=["thread-allocator"]) for e in catalog["entries"]}
        for entry in inventory(args.include, global_allocator=True)["entries"]:
            previous = entries.get(entry["id"])
            if previous:
                if {k: v for k, v in previous.items() if k != "profiles"} != entry:
                    raise ValueError(f"Allocator variants disagree for {entry['id']}")
                previous["profiles"].append("global-allocator")
            else:
                entries[entry["id"]] = dict(entry, profiles=["global-allocator"])
        catalog["entries"] = [entries[k] for k in sorted(entries)]
        version = next((e for e in catalog["entries"] if e["id"] ==
                        "macro:xmlversion.h:LIBXML_VERSION"), None)
        if version is None or version["declaration"] != f"LIBXML_VERSION {baseline['version_number']}":
            raise ValueError("Reference header version mismatch")
        if target.exists():
            frozen = json.loads(target.read_text())
            if frozen["headers"] != catalog["headers"]:
                raise ValueError("Reference header hashes differ; audit a baseline change explicitly")
        write_or_check(target, serialize(catalog), args.check)
        if args.check:
            library = args.include.parent.parent / "lib/libxml2.so"
            symbols = subprocess.check_output(["nm", "-D", "--defined-only", str(library)], text=True)
            exported = {line.split()[-1].split("@")[0] for line in symbols.splitlines()
                        if len(line.split()) >= 3}
            declared = {e["name"] for e in catalog["entries"] if e["kind"] in ("function", "variable")}
            missing = exported - declared
            if missing:
                raise ValueError(f"Exported symbols missing from inventory: {sorted(missing)}")
    coverage = json.loads((ROOT / "compat/coverage.json").read_text())
    write_or_check(ROOT / "docs/api-coverage.md", render(catalog, coverage), args.check)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        sys.exit(str(error))
