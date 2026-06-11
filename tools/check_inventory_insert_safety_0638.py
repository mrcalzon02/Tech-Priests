#!/usr/bin/env python3
"""
Tech-Priests 0.1.638 inventory insert safety checker.

Flags generic deposit/reserve/balancing code that references machine inventories
which must not be used as arbitrary LuaInventory.insert targets:

- defines.inventory.furnace_result
- defines.inventory.furnace_source
- defines.inventory.fuel
- defines.inventory.assembling_machine_output

The checker is intentionally conservative.  It allows machine-specific modules to
exist, but still reports any suspicious generic inventory scope so the repair
conversation has to consciously review it before packaging.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
from dataclasses import dataclass
from typing import Iterable

BANNED_INVENTORIES = {
    "defines.inventory.furnace_result",
    "defines.inventory.furnace_source",
    "defines.inventory.fuel",
    "defines.inventory.assembling_machine_output",
}

GENERIC_SCOPE_HINTS = re.compile(
    r"(deposit|reserve|balance|stash|station_inventor|station_inventory|station_inventories|"
    r"safe_deposit|inventory_steward|direct_acquisition|acquisition_executor|emergency_supply)",
    re.IGNORECASE,
)

INSERT_HINTS = re.compile(r"\.insert\s*\(|LuaInventory\.insert|inv_insert\s*\(", re.IGNORECASE)

COMMENT_ONLY = re.compile(r"^\s*(?:--|#)")

@dataclass(frozen=True)
class Finding:
    path: pathlib.Path
    line: int
    kind: str
    text: str


def iter_lua_files(root: pathlib.Path) -> Iterable[pathlib.Path]:
    for path in root.rglob("*.lua"):
        rel = path.relative_to(root)
        parts = set(rel.parts)
        if ".git" in parts:
            continue
        yield path


def detect_scope(lines: list[str], idx: int) -> str:
    start = max(0, idx - 24)
    end = min(len(lines), idx + 25)
    window = "\n".join(lines[start:end])
    if GENERIC_SCOPE_HINTS.search(window):
        return "generic-scope"
    return "unclassified-scope"


def scan_file(root: pathlib.Path, path: pathlib.Path) -> list[Finding]:
    rel = path.relative_to(root)
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    findings: list[Finding] = []

    for idx, line in enumerate(lines):
        if COMMENT_ONLY.match(line):
            continue
        for banned in BANNED_INVENTORIES:
            if banned in line:
                scope = detect_scope(lines, idx)
                findings.append(Finding(rel, idx + 1, f"banned-inventory:{scope}", line.strip()))

    # A secondary heuristic: if a file has both raw insert calls and banned
    # inventory constants, keep the raw insert visible in the report too.
    file_has_banned = any(f.path == rel for f in findings)
    if file_has_banned:
        for idx, line in enumerate(lines):
            if COMMENT_ONLY.match(line):
                continue
            if INSERT_HINTS.search(line):
                scope = detect_scope(lines, idx)
                findings.append(Finding(rel, idx + 1, f"insert-call:{scope}", line.strip()))

    return findings


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Check Tech-Priests generic inventory insert safety.")
    parser.add_argument("root", nargs="?", default=".", help="Repository root to scan; default: current directory")
    parser.add_argument("--allow-unclassified", action="store_true", help="Do not fail on unclassified machine inventory references")
    args = parser.parse_args(argv)

    root = pathlib.Path(args.root).resolve()
    scan_root = root / "tech-priests_src" if (root / "tech-priests_src").is_dir() else root

    findings: list[Finding] = []
    for path in iter_lua_files(scan_root):
        findings.extend(scan_file(scan_root, path))

    if not findings:
        print("OK: no unsafe generic inventory insert surface found.")
        return 0

    generic = [f for f in findings if "generic-scope" in f.kind]
    unclassified = [f for f in findings if "unclassified-scope" in f.kind]

    print("Inventory insert safety findings:")
    for f in findings:
        print(f"{f.path}:{f.line}: {f.kind}: {f.text}")

    if generic:
        print("\nFAIL: generic deposit/reserve/acquisition scope references banned machine inventories.")
        return 1
    if unclassified and not args.allow_unclassified:
        print("\nFAIL: unclassified banned machine inventory references require manual review.")
        return 1

    print("\nWARN: only unclassified references found; manual review required.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
