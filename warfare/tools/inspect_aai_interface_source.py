#!/usr/bin/env python3
"""Inspect the locally SHA-1-verified AAI archive without repackaging source.

Outputs *identifiers, signatures and source locations only*, never Lua bodies.
Argument names are preliminary, not proof of safe external call semantics.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path

FUNCTIONS = (
    "get_surface_paths", "get_unit_by_entity", "get_unit_by_signal",
    "get_unit_count_by_type", "get_units", "on_entity_deployed",
    "set_path_waypoint", "set_unit_command", "set_unit_data",
    "write_global", "write_unit",
)
NAME = r"[A-Za-z_][A-Za-z0-9_]*"

def patterns(name: str) -> list[tuple[str, re.Pattern]]:
    escaped = re.escape(name)
    return [
        ("lua-function", re.compile(
            rf"(?m)^\s*function\s+[{NAME}:.]*\b{escaped}\s*\(([^)]*)\)"
        )),
        ("table-lambda", re.compile(
            rf"(?m)^\s*{escaped}\s*=\s*function\s*\(([^)]*)\)"
        )),
        ("local-function", re.compile(
            rf"(?m)^\s*local\s+function\s+{escaped}\s*\(([^)]*)\)"
        )),
        ("table-reference", re.compile(
            rf"(?m)^\s*{escaped}\s*=\s*([A-Za-z_][A-Za-z0-9_:.]*)\s*[,}}]"
        )),
    ]

def inspect(path: Path) -> dict:
    result = {
        "original_mod_archive": path.name,
        "archive_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "artifact_contains_mod_source": False,
        "method_signatures_are_verified_semantics": False,
        "registration_sites": [],
        "candidate_method_declarations": {name: [] for name in FUNCTIONS},
    }
    with zipfile.ZipFile(path) as z:
        for member in z.namelist():
            if not member.endswith(".lua") or member.endswith("/"):
                continue
            text = z.read(member).decode("utf-8", errors="replace")
            for match in re.finditer(r"remote\s*\.\s*add_interface\s*\(", text):
                result["registration_sites"].append({
                    "file": member, "line": text.count("\n", 0, match.start()) + 1,
                })
            for name in FUNCTIONS:
                entries = result["candidate_method_declarations"][name]
                for kind, regex in patterns(name):
                    for match in regex.finditer(text):
                        arguments = match.group(1).strip()
                        if len(arguments) > 120:
                            arguments = "[argument list too long]"
                        item = {
                            "file": member,
                            "line": text.count("\n", 0, match.start()) + 1,
                            "kind": kind,
                            "arguments_or_delegate": arguments,
                        }
                        if item not in entries:
                            entries.append(item)
    for entries in result["candidate_method_declarations"].values():
        entries.sort(key=lambda d: (d["file"], d["line"]))
    return result

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mods_dir", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    paths = list(args.mods_dir.glob("aai-programmable-vehicles_0.9.2.zip"))
    if len(paths) != 1:
        print("[WAR-SOURCE] FAIL AAI 0.9.2 archive not found exactly once")
        return 1
    result = inspect(paths[0])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("[WAR-SOURCE] PASS original archive inspected without copying source")
    for site in result["registration_sites"]:
        print(f"[WAR-SOURCE] interface registration site: {site['file']}:{site['line']}")
    for name, entries in result["candidate_method_declarations"].items():
        if not entries:
            print(f"[WAR-SOURCE] unresolved signature {name}")
        else:
            for item in entries[:10]:
                print(f"[WAR-SOURCE] {name} {item['kind']} "
                      f"({item['arguments_or_delegate']}) {item['file']}:{item['line']}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
