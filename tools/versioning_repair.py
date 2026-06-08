#!/usr/bin/env python3
"""
Tech Priests versioning, source/output, and recovery helper.

This tool exists because the project now has a canonical source tree and a
versioned output/test tree:

    tech-priests_src/
    tech-priests_0.1.620/

Rules enforced by this workflow:

- Source is the normal edit target.
- Output folders are generated/test candidates.
- Recovered output may be back-patched into source only by explicit command.
- Versioned output folders must match info.json's version.
- Runtime files should not assign to protected Factorio globals such as log,
  game, script, defines, storage, commands, remote, rendering, or settings.

Run from repository root:

    python tools/versioning_repair.py audit
    python tools/versioning_repair.py backpatch --file scripts/core/runtime_event_registry.lua --apply
    python tools/versioning_repair.py verify
    python tools/versioning_repair.py prepare-output --version 0.1.621 --note "Describe the repair" --apply

Dry-run is the default for mutating commands. Pass --apply to write changes.
"""

from __future__ import annotations

import argparse
import datetime as dt
import filecmp
import hashlib
import json
import os
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


DEFAULT_SOURCE = "tech-priests_src"
DEFAULT_OUTPUT_PREFIX = "tech-priests_"
PROTECTED_FACTORIO_GLOBALS = {
    "log",
    "game",
    "script",
    "defines",
    "storage",
    "global",
    "commands",
    "remote",
    "rendering",
    "settings",
    "data",
    "mods",
}
IGNORE_DIRS = {".git", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache"}
IGNORE_SUFFIXES = {".pyc", ".pyo"}


@dataclass
class Difference:
    relpath: str
    status: str
    source_sha: str = ""
    output_sha: str = ""


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def rel_files(root: Path) -> Dict[str, Path]:
    out: Dict[str, Path] = {}
    if not root.exists():
        return out
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        parts = set(path.relative_to(root).parts)
        if parts & IGNORE_DIRS:
            continue
        if path.suffix in IGNORE_SUFFIXES:
            continue
        out[path.relative_to(root).as_posix()] = path
    return out


def find_current_output(root: Path, source: Path, explicit: Optional[str]) -> Path:
    if explicit:
        return (root / explicit).resolve()
    info = read_json(source / "info.json")
    version = str(info.get("version", "")).strip()
    if not version:
        raise SystemExit(f"missing version in {source / 'info.json'}")
    return (root / f"{DEFAULT_OUTPUT_PREFIX}{version}").resolve()


def compare_trees(source: Path, output: Path) -> List[Difference]:
    sf = rel_files(source)
    of = rel_files(output)
    diffs: List[Difference] = []
    for rel in sorted(set(sf) | set(of)):
        sp = sf.get(rel)
        op = of.get(rel)
        if sp is None:
            diffs.append(Difference(rel, "output-only", output_sha=sha256(op)))
        elif op is None:
            diffs.append(Difference(rel, "source-only", source_sha=sha256(sp)))
        else:
            sh = sha256(sp)
            oh = sha256(op)
            if sh != oh:
                diffs.append(Difference(rel, "changed", sh, oh))
    return diffs


def copy_file(src: Path, dst: Path, apply: bool) -> None:
    print(f"{'COPY' if apply else 'DRY-RUN copy'} {src} -> {dst}")
    if apply:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


def backpatch_files(source: Path, output: Path, files: Sequence[str], apply: bool) -> int:
    if not output.exists():
        raise SystemExit(f"output tree does not exist: {output}")
    if not source.exists():
        raise SystemExit(f"source tree does not exist: {source}")
    if not files:
        raise SystemExit("backpatch requires at least one --file path")
    changed = 0
    for rel in files:
        rel = rel.replace("\\", "/").strip("/")
        src = output / rel
        dst = source / rel
        if not src.exists():
            print(f"MISSING in output: {rel}", file=sys.stderr)
            continue
        if dst.exists() and filecmp.cmp(src, dst, shallow=False):
            print(f"UNCHANGED {rel}")
            continue
        copy_file(src, dst, apply)
        changed += 1
    return changed


def append_changelog(changelog: Path, version: str, note: str, apply: bool) -> None:
    if not note:
        return
    today = dt.date.today().isoformat()
    entry = (
        "---------------------------------------------------------------------------------------------------\n"
        f"Version: {version}\n"
        f"Date: {today}\n"
        "  Changes:\n"
        f"    - {note}\n\n"
    )
    print(f"{'APPEND' if apply else 'DRY-RUN append'} changelog entry for {version}")
    if apply:
        old = changelog.read_text(encoding="utf-8", errors="replace") if changelog.exists() else ""
        changelog.write_text(entry + old, encoding="utf-8")


def copy_source_to_output(source: Path, output: Path, apply: bool) -> None:
    print(f"{'REBUILD' if apply else 'DRY-RUN rebuild'} output tree {output} from {source}")
    if not apply:
        return
    if output.exists():
        shutil.rmtree(output)
    def ignore(directory: str, names: List[str]) -> set:
        ignored = set()
        for name in names:
            p = Path(directory) / name
            if name in IGNORE_DIRS or p.suffix in IGNORE_SUFFIXES:
                ignored.add(name)
        return ignored
    shutil.copytree(source, output, ignore=ignore)


def prepare_output(root: Path, source: Path, version: str, note: str, apply: bool) -> Path:
    info_path = source / "info.json"
    info = read_json(info_path)
    old_version = str(info.get("version", ""))
    info["version"] = version
    output = (root / f"{DEFAULT_OUTPUT_PREFIX}{version}").resolve()
    print(f"version {old_version} -> {version}")
    print(f"output folder: {output.name}")
    if apply:
        write_json(info_path, info)
    append_changelog(source / "changelog.txt", version, note, apply)
    copy_source_to_output(source, output, apply)
    return output


def scan_protected_globals(root: Path) -> List[Tuple[str, int, str]]:
    hits: List[Tuple[str, int, str]] = []
    direct_re = re.compile(r"^\s*({names})\s*=".format(names="|".join(sorted(PROTECTED_FACTORIO_GLOBALS))))
    g_re = re.compile(r"^\s*_G\s*\.\s*({names})\s*=".format(names="|".join(sorted(PROTECTED_FACTORIO_GLOBALS))))
    bracket_re = re.compile(r"^\s*_G\s*\[\s*['\"]({names})['\"]\s*\]\s*=".format(names="|".join(sorted(PROTECTED_FACTORIO_GLOBALS))))
    for path in root.rglob("*.lua"):
        if set(path.relative_to(root).parts) & IGNORE_DIRS:
            continue
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for idx, line in enumerate(lines, start=1):
            if direct_re.search(line) or g_re.search(line) or bracket_re.search(line):
                hits.append((path.relative_to(root).as_posix(), idx, line.strip()))
    return hits


def verify(root: Path, source: Path, output: Path) -> int:
    problems = 0
    sinfo = read_json(source / "info.json")
    sv = str(sinfo.get("version", ""))
    expected_output = f"{DEFAULT_OUTPUT_PREFIX}{sv}"
    if output.name != expected_output:
        print(f"VERSION-FOLDER MISMATCH: source info.json version {sv}, output folder {output.name}, expected {expected_output}")
        problems += 1
    if output.exists() and (output / "info.json").exists():
        oinfo = read_json(output / "info.json")
        ov = str(oinfo.get("version", ""))
        if ov != sv:
            print(f"VERSION MISMATCH: source={sv} output={ov}")
            problems += 1
    else:
        print(f"OUTPUT MISSING info.json: {output}")
        problems += 1

    for label, tree in (("source", source), ("output", output)):
        hits = scan_protected_globals(tree)
        if hits:
            print(f"PROTECTED GLOBAL ASSIGNMENTS in {label}:")
            for rel, line, text in hits:
                print(f"  {rel}:{line}: {text}")
            problems += len(hits)
        else:
            print(f"protected-global scan clean: {label}")
    if problems == 0:
        print("verify OK")
    else:
        print(f"verify found {problems} problem(s)")
    return 1 if problems else 0


def print_diffs(diffs: Sequence[Difference], limit: int) -> None:
    print(f"differences: {len(diffs)}")
    for diff in diffs[:limit]:
        print(f"{diff.status:12} {diff.relpath} src={diff.source_sha[:12]} out={diff.output_sha[:12]}")
    if len(diffs) > limit:
        print(f"... {len(diffs) - limit} more")


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Tech Priests source/output versioning repair helper")
    parser.add_argument("--repo-root", default=".", help="Repository root. Defaults to current directory.")
    parser.add_argument("--source", default=DEFAULT_SOURCE, help="Source tree path relative to repo root.")
    parser.add_argument("--output", default=None, help="Output tree path relative to repo root. Defaults to tech-priests_<source version>.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_audit = sub.add_parser("audit", help="Compare source and output trees by SHA-256")
    p_audit.add_argument("--limit", type=int, default=80)

    p_back = sub.add_parser("backpatch", help="Copy selected recovered output files back into source")
    p_back.add_argument("--file", action="append", default=[], help="Relative file path inside mod tree; repeatable")
    p_back.add_argument("--apply", action="store_true", help="Actually write files; default is dry-run")

    p_prepare = sub.add_parser("prepare-output", help="Set source version and rebuild a versioned output folder from source")
    p_prepare.add_argument("--version", required=True, help="New version, for example 0.1.621")
    p_prepare.add_argument("--note", default="", help="Optional changelog note")
    p_prepare.add_argument("--apply", action="store_true", help="Actually write files; default is dry-run")

    p_verify = sub.add_parser("verify", help="Verify version folder consistency and protected global assignments")

    args = parser.parse_args(argv)
    root = Path(args.repo_root).resolve()
    source = (root / args.source).resolve()
    output = find_current_output(root, source, args.output)

    if args.cmd == "audit":
        print(f"source: {source}")
        print(f"output: {output}")
        print_diffs(compare_trees(source, output), args.limit)
        return 0
    if args.cmd == "backpatch":
        changed = backpatch_files(source, output, args.file, args.apply)
        print(f"backpatch {'applied' if args.apply else 'dry-run'} changes={changed}")
        return 0
    if args.cmd == "prepare-output":
        prepare_output(root, source, args.version, args.note, args.apply)
        return 0
    if args.cmd == "verify":
        return verify(root, source, output)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
