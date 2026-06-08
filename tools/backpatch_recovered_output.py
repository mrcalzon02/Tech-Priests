#!/usr/bin/env python3
"""
Backpatch tech-priests_src from the newest recovered tech-priests_<version> output folder.

This is a recovery helper for the source/output split:

    tech-priests_src/          canonical source tree to repair
    tech-priests_0.1.628/      recovered output candidate / current truth

Default behavior is dry-run. Pass --apply to copy files.

Examples:

    python tools/backpatch_recovered_output.py
    python tools/backpatch_recovered_output.py --output tech-priests_0.1.628
    python tools/backpatch_recovered_output.py --file scripts/core/runtime_event_registry.lua --apply
    python tools/backpatch_recovered_output.py --all --apply

The script never writes into the recovered output folder. It only copies from
output to source.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


SOURCE_DIR = "tech-priests_src"
OUTPUT_RE = re.compile(r"^tech-priests_(\d+)\.(\d+)\.(\d+)$")
IGNORE_DIRS = {".git", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache"}
IGNORE_SUFFIXES = {".pyc", ".pyo"}
PROTECTED_GLOBALS = {
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


@dataclass(frozen=True)
class OutputCandidate:
    path: Path
    version: Tuple[int, int, int]

    @property
    def version_string(self) -> str:
        return ".".join(str(v) for v in self.version)


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def iter_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        rel_parts = set(path.relative_to(root).parts)
        if rel_parts & IGNORE_DIRS:
            continue
        if path.suffix in IGNORE_SUFFIXES:
            continue
        yield path


def find_outputs(repo_root: Path) -> List[OutputCandidate]:
    candidates: List[OutputCandidate] = []
    for child in repo_root.iterdir():
        if not child.is_dir():
            continue
        m = OUTPUT_RE.match(child.name)
        if not m:
            continue
        info = child / "info.json"
        if not info.exists():
            continue
        version = tuple(int(x) for x in m.groups())
        try:
            info_version = str(read_json(info).get("version", ""))
        except Exception:
            info_version = ""
        if info_version and info_version != ".".join(str(v) for v in version):
            print(f"warning: folder/info version mismatch in {child.name}: info.json says {info_version}", file=sys.stderr)
        candidates.append(OutputCandidate(child, version))
    candidates.sort(key=lambda c: c.version)
    return candidates


def newest_output(repo_root: Path) -> OutputCandidate:
    candidates = find_outputs(repo_root)
    if not candidates:
        raise SystemExit("no tech-priests_<version> output folders with info.json found")
    return candidates[-1]


def rel_to_posix(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def files_differ(a: Path, b: Path) -> bool:
    if not b.exists():
        return True
    if a.stat().st_size != b.stat().st_size:
        return True
    return a.read_bytes() != b.read_bytes()


def copy_one(output_root: Path, source_root: Path, rel: str, apply: bool) -> bool:
    rel = rel.replace("\\", "/").strip("/")
    src = output_root / rel
    dst = source_root / rel
    if not src.exists() or not src.is_file():
        print(f"MISSING output file: {rel}", file=sys.stderr)
        return False
    if not files_differ(src, dst):
        print(f"UNCHANGED {rel}")
        return False
    print(f"{'COPY' if apply else 'DRY-RUN copy'} {rel}")
    if apply:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    return True


def select_files(output_root: Path, explicit: Sequence[str], all_files: bool) -> List[str]:
    if explicit:
        return [f.replace("\\", "/").strip("/") for f in explicit]
    if all_files:
        return [rel_to_posix(path, output_root) for path in iter_files(output_root)]
    raise SystemExit("choose --file <path> or --all")


def scan_protected_globals(root: Path) -> List[Tuple[str, int, str]]:
    names = "|".join(sorted(PROTECTED_GLOBALS))
    patterns = [
        re.compile(rf"^\s*(?:{names})\s*="),
        re.compile(rf"^\s*_G\s*\.\s*(?:{names})\s*="),
        re.compile(rf"^\s*_G\s*\[\s*['\"](?:{names})['\"]\s*\]\s*="),
    ]
    hits: List[Tuple[str, int, str]] = []
    for path in root.rglob("*.lua"):
        rel_parts = set(path.relative_to(root).parts)
        if rel_parts & IGNORE_DIRS:
            continue
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for i, line in enumerate(lines, start=1):
            if any(p.search(line) for p in patterns):
                hits.append((rel_to_posix(path, root), i, line.strip()))
    return hits


def write_recovery_note(source_root: Path, output_root: Path, apply: bool) -> None:
    note = source_root / "docs" / "RECOVERY_BASELINE.md"
    content = f"""# Recovery Baseline

Current recovered output baseline:

```text
{output_root.name}
```

The source tree should be backpatched from this recovered output before new repair work continues.

Rules:

- Edit `tech-priests_src/` as source.
- Treat `{output_root.name}/` as recovered truth until a newer versioned output is deliberately prepared.
- Do not hand-patch output folders as the primary workflow.
- Prepare future test outputs by copying source into a new versioned output folder.
- Do not assign or monkey-patch protected Factorio globals such as `log`, `script`, `game`, `defines`, or `storage`.
"""
    print(f"{'WRITE' if apply else 'DRY-RUN write'} {note.relative_to(source_root.parent).as_posix()}")
    if apply:
        note.parent.mkdir(parents=True, exist_ok=True)
        note.write_text(content, encoding="utf-8")


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Backpatch tech-priests_src from recovered output")
    parser.add_argument("--repo-root", default=".", help="Repository root; default current directory")
    parser.add_argument("--source", default=SOURCE_DIR, help="Source tree; default tech-priests_src")
    parser.add_argument("--output", default=None, help="Recovered output folder; default newest tech-priests_<version>")
    parser.add_argument("--file", action="append", default=[], help="Relative file path inside the mod tree; repeatable")
    parser.add_argument("--all", action="store_true", help="Backpatch all files from output to source")
    parser.add_argument("--write-note", action="store_true", help="Write docs/RECOVERY_BASELINE.md into source")
    parser.add_argument("--apply", action="store_true", help="Actually copy/write; default is dry-run")
    parser.add_argument("--skip-protected-global-scan", action="store_true", help="Skip protected global assignment scan after apply/dry-run")
    args = parser.parse_args(argv)

    repo_root = Path(args.repo_root).resolve()
    source_root = (repo_root / args.source).resolve()
    if not source_root.exists():
        raise SystemExit(f"source tree missing: {source_root}")

    if args.output:
        output_root = (repo_root / args.output).resolve()
        if not output_root.exists():
            raise SystemExit(f"output tree missing: {output_root}")
        output = OutputCandidate(output_root, tuple(int(x) for x in OUTPUT_RE.match(output_root.name).groups()) if OUTPUT_RE.match(output_root.name) else (0, 0, 0))
    else:
        output = newest_output(repo_root)
        output_root = output.path.resolve()

    print(f"source: {source_root.relative_to(repo_root).as_posix()}")
    print(f"recovered output: {output_root.relative_to(repo_root).as_posix()}")

    rels = select_files(output_root, args.file, args.all)
    changed = 0
    for rel in rels:
        if copy_one(output_root, source_root, rel, args.apply):
            changed += 1

    if args.write_note:
        write_recovery_note(source_root, output_root, args.apply)

    print(f"{'applied' if args.apply else 'dry-run'} changed={changed}")

    if not args.skip_protected_global_scan:
        hits = scan_protected_globals(source_root)
        if hits:
            print("PROTECTED GLOBAL ASSIGNMENTS FOUND:")
            for rel, line, text in hits:
                print(f"  {rel}:{line}: {text}")
            return 1
        print("protected-global scan clean: source")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
