#!/usr/bin/env python3
"""
Update the repository-level GitHub file manifest for Tech Priests.

Run from the repository root:

    python tools/update_github_manifest.py

The manifest is intended to make the repository searchable from GitHub and from
assistant/connector tooling even when the active mod source is nested under
versioned output folders.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


DEFAULT_MANIFEST = "GITHUB_FILE_MANIFEST.md"
DEFAULT_JSON_INDEX = "GITHUB_FILE_INDEX.json"

IGNORE_DIR_NAMES = {
    ".git",
    ".hg",
    ".svn",
    ".idea",
    ".vscode",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    "node_modules",
    ".venv",
    "venv",
    "env",
    "dist",
    "build",
}

IGNORE_FILE_NAMES = {
    DEFAULT_JSON_INDEX,
}

TEXT_EXTENSIONS = {
    ".lua",
    ".json",
    ".md",
    ".txt",
    ".cfg",
    ".csv",
    ".tsv",
    ".xml",
    ".ini",
    ".py",
    ".bat",
    ".ps1",
    ".sh",
    ".yml",
    ".yaml",
}

BINARY_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".ogg",
    ".mp3",
    ".wav",
    ".zip",
    ".7z",
    ".rar",
    ".exe",
    ".dll",
    ".pdb",
    ".blend",
}

ROOT_HINT_NAMES = {
    "source",
    "src",
    "current",
    "current-output",
    "current_output",
    "output",
    "release",
    "releases",
}


@dataclass
class FileRecord:
    path: str
    kind: str
    size: int
    sha256: str
    lines: Optional[int] = None
    summary: str = ""
    requires: List[str] = field(default_factory=list)
    functions: List[str] = field(default_factory=list)
    commands: List[str] = field(default_factory=list)
    gui_names: List[str] = field(default_factory=list)
    locale_sections: List[str] = field(default_factory=list)
    json_keys: List[str] = field(default_factory=list)
    search_terms: List[str] = field(default_factory=list)


def relpath(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def looks_text(path: Path) -> bool:
    if path.suffix.lower() in TEXT_EXTENSIONS:
        return True
    if path.suffix.lower() in BINARY_EXTENSIONS:
        return False
    try:
        sample = path.read_bytes()[:8192]
    except OSError:
        return False
    if b"\x00" in sample:
        return False
    try:
        sample.decode("utf-8")
        return True
    except UnicodeDecodeError:
        try:
            sample.decode("cp1252")
            return True
        except UnicodeDecodeError:
            return False


def file_kind(path: Path, is_text: bool) -> str:
    ext = path.suffix.lower()
    if ext == ".lua":
        return "lua"
    if ext == ".json":
        return "json"
    if ext == ".md":
        return "markdown"
    if ext == ".cfg":
        return "locale-cfg"
    if ext in {".png", ".jpg", ".jpeg", ".gif", ".webp"}:
        return "image"
    if ext in {".ogg", ".mp3", ".wav"}:
        return "audio"
    if ext == ".zip":
        return "zip"
    return "text" if is_text else "binary"


def read_text_limited(path: Path, max_bytes: int) -> str:
    data = path.read_bytes()[:max_bytes]
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("cp1252", errors="replace")


def unique_keep_order(values: Iterable[str], limit: Optional[int] = None) -> List[str]:
    seen = set()
    out = []
    for value in values:
        value = str(value).strip()
        if not value or value in seen:
            continue
        seen.add(value)
        out.append(value)
        if limit is not None and len(out) >= limit:
            break
    return out


def tokenize_path(path: str) -> List[str]:
    raw = re.split(r"[^A-Za-z0-9_]+", path)
    return [p.lower() for p in raw if len(p) >= 2]


def first_comment_summary(text: str, kind: str) -> str:
    lines = text.splitlines()
    comments: List[str] = []
    for line in lines[:60]:
        stripped = line.strip()
        if not stripped:
            continue
        if kind == "lua" and stripped.startswith("--"):
            cleaned = stripped.lstrip("-").strip()
            if cleaned and not cleaned.startswith("="):
                comments.append(cleaned)
        elif kind == "markdown":
            return stripped.lstrip("#").strip()[:220]
        elif kind == "python" and stripped.startswith("#"):
            comments.append(stripped.lstrip("#").strip())
        elif comments:
            break
    return " ".join(comments[:3])[:260]


def extract_lua_symbols(text: str) -> Tuple[List[str], List[str], List[str], List[str]]:
    requires = re.findall(r"\brequire\s*\(?\s*['\"]([^'\"]+)['\"]", text)
    functions = re.findall(r"\bfunction\s+([A-Za-z_][A-Za-z0-9_:.]*)\s*\(", text)
    functions += re.findall(r"\blocal\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", text)
    commands = re.findall(r"\badd_command\s*\(\s*['\"]([^'\"]+)['\"]", text)
    commands += re.findall(r"TechPriestsDebugCommandRegistry\.add\s*\(\s*['\"]([^'\"]+)['\"]", text)
    gui_names = re.findall(r"\bname\s*=\s*['\"]([^'\"]+)['\"]", text)
    gui_names += re.findall(r"\bgui_name\s*=\s*['\"]([^'\"]+)['\"]", text)
    gui_names += re.findall(r"\bM\.gui_name\s*=\s*['\"]([^'\"]+)['\"]", text)
    return (
        unique_keep_order(requires, 80),
        unique_keep_order(functions, 120),
        unique_keep_order(commands, 80),
        unique_keep_order(gui_names, 120),
    )


def extract_locale_sections(text: str) -> List[str]:
    return unique_keep_order(re.findall(r"^\s*\[([^\]]+)\]\s*$", text, flags=re.MULTILINE), 120)


def extract_json_keys(text: str) -> List[str]:
    try:
        data = json.loads(text)
    except Exception:
        return []
    keys: List[str] = []

    def walk(value, depth: int = 0) -> None:
        if depth > 2:
            return
        if isinstance(value, dict):
            for k, v in value.items():
                keys.append(str(k))
                walk(v, depth + 1)
        elif isinstance(value, list):
            for item in value[:20]:
                walk(item, depth + 1)

    walk(data)
    return unique_keep_order(keys, 120)


def extract_search_terms(record: FileRecord) -> List[str]:
    terms: List[str] = []
    terms.extend(tokenize_path(record.path))
    for bucket in (
        record.requires,
        record.functions,
        record.commands,
        record.gui_names,
        record.locale_sections,
        record.json_keys,
    ):
        for value in bucket:
            terms.extend(tokenize_path(value))
    return unique_keep_order(terms, 80)


def should_skip(path: Path, root: Path, manifest_path: Path) -> bool:
    if path == manifest_path:
        return True
    if path.name in IGNORE_FILE_NAMES:
        return True
    rel_parts = path.relative_to(root).parts
    if any(part in IGNORE_DIR_NAMES for part in rel_parts[:-1]):
        return True
    return False


def iter_files(root: Path, manifest_path: Path) -> Iterable[Path]:
    for dirpath, dirnames, filenames in os.walk(root):
        d = Path(dirpath)
        dirnames[:] = [name for name in dirnames if name not in IGNORE_DIR_NAMES]
        for filename in filenames:
            path = d / filename
            if should_skip(path, root, manifest_path):
                continue
            yield path


def index_file(path: Path, root: Path, max_scan_bytes: int) -> FileRecord:
    is_text = looks_text(path)
    kind = file_kind(path, is_text)
    size = path.stat().st_size
    sha = sha256_file(path)
    rec = FileRecord(path=relpath(path, root), kind=kind, size=size, sha256=sha)

    if is_text:
        text = read_text_limited(path, max_scan_bytes)
        try:
            rec.lines = sum(1 for _ in path.open("r", encoding="utf-8", errors="replace"))
        except OSError:
            rec.lines = text.count("\n") + 1 if text else 0
        rec.summary = first_comment_summary(text, kind)
        if kind == "lua":
            rec.requires, rec.functions, rec.commands, rec.gui_names = extract_lua_symbols(text)
        elif kind == "locale-cfg":
            rec.locale_sections = extract_locale_sections(text)
        elif kind == "json":
            rec.json_keys = extract_json_keys(text)

    rec.search_terms = extract_search_terms(rec)
    return rec


def format_bytes(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024
    return f"{n:.1f} GB"


def md_escape(value: object) -> str:
    text = str(value if value is not None else "")
    return text.replace("|", "\\|").replace("\n", " ").strip()


def list_preview(values: Sequence[str], limit: int = 12) -> str:
    if not values:
        return ""
    shown = list(values[:limit])
    if len(values) > limit:
        shown.append(f"...+{len(values) - limit}")
    return ", ".join(shown)


def directory_summary(records: Sequence[FileRecord]) -> List[Tuple[str, int, int]]:
    stats: Dict[str, List[int]] = {}
    for rec in records:
        directory = str(Path(rec.path).parent).replace("\\", "/")
        if directory == ".":
            directory = "(root)"
        top = rec.path.split("/", 1)[0]
        for key in {directory, top}:
            if key not in stats:
                stats[key] = [0, 0]
            stats[key][0] += 1
            stats[key][1] += rec.size
    rows = [(k, v[0], v[1]) for k, v in stats.items()]
    rows.sort(key=lambda r: (r[0].count("/"), r[0]))
    return rows


def recognized_roots(root: Path) -> List[str]:
    out = []
    for child in sorted(root.iterdir(), key=lambda p: p.name.lower()):
        if not child.is_dir() or child.name in IGNORE_DIR_NAMES:
            continue
        lower = child.name.lower()
        if lower in ROOT_HINT_NAMES or lower.startswith("tech-priests_") or lower.startswith("tech_priests_"):
            out.append(child.name)
    return out


def render_markdown(records: Sequence[FileRecord], root: Path, script_path: str) -> str:
    now = _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()
    total_bytes = sum(r.size for r in records)
    text_count = sum(1 for r in records if r.lines is not None)
    binary_count = len(records) - text_count
    roots = recognized_roots(root)

    lines: List[str] = []
    lines.append("# GitHub File Manifest")
    lines.append("")
    lines.append("> Auto-generated. Do not hand-edit the indexed sections; rerun the manifest generator instead.")
    lines.append("")
    lines.append(f"- Generated UTC: `{now}`")
    lines.append(f"- Generator: `{script_path}`")
    lines.append(f"- Repository root: `{root.name}`")
    lines.append(f"- Files indexed: `{len(records)}`")
    lines.append(f"- Text files: `{text_count}`")
    lines.append(f"- Binary/asset files: `{binary_count}`")
    lines.append(f"- Total indexed bytes: `{format_bytes(total_bytes)}`")
    if roots:
        lines.append(f"- Recognized source/output roots: `{', '.join(roots)}`")
    lines.append("")
    lines.append("## How to refresh")
    lines.append("")
    lines.append("```bash")
    lines.append("python tools/update_github_manifest.py")
    lines.append("```")
    lines.append("")
    lines.append("The manifest indexes paths, file kinds, hashes, text line counts, Lua `require` targets, functions, GUI element names, commands, locale sections, JSON keys, and search terms. It is designed so GitHub search can find nested source files by symbols and concepts even when the active Factorio mod is stored inside a versioned output folder.")
    lines.append("")

    lines.append("## Directory summary")
    lines.append("")
    lines.append("| Directory / root | Files | Bytes |")
    lines.append("|---|---:|---:|")
    for directory, count, bytes_ in directory_summary(records):
        lines.append(f"| `{md_escape(directory)}` | {count} | {md_escape(format_bytes(bytes_))} |")
    lines.append("")

    lines.append("## Full file path index")
    lines.append("")
    lines.append("| Path | Kind | Size | Lines | SHA-256 | Summary |")
    lines.append("|---|---|---:|---:|---|---|")
    for rec in records:
        sha = rec.sha256[:12]
        line_text = "" if rec.lines is None else str(rec.lines)
        lines.append(
            f"| `{md_escape(rec.path)}` | {md_escape(rec.kind)} | {md_escape(format_bytes(rec.size))} | {line_text} | `{sha}` | {md_escape(rec.summary)} |"
        )
    lines.append("")

    symbol_records = [
        r for r in records
        if r.requires or r.functions or r.commands or r.gui_names or r.locale_sections or r.json_keys or r.search_terms
    ]
    lines.append("## Search and symbol index")
    lines.append("")
    for rec in symbol_records:
        lines.append(f"### `{md_escape(rec.path)}`")
        lines.append("")
        lines.append(f"- Kind: `{md_escape(rec.kind)}`")
        lines.append(f"- SHA-256: `{rec.sha256}`")
        if rec.lines is not None:
            lines.append(f"- Lines: `{rec.lines}`")
        if rec.summary:
            lines.append(f"- Summary: {md_escape(rec.summary)}")
        if rec.requires:
            lines.append(f"- Lua requires: `{md_escape(list_preview(rec.requires, 20))}`")
        if rec.functions:
            lines.append(f"- Lua functions: `{md_escape(list_preview(rec.functions, 30))}`")
        if rec.commands:
            lines.append(f"- Commands: `{md_escape(list_preview(rec.commands, 30))}`")
        if rec.gui_names:
            lines.append(f"- GUI names: `{md_escape(list_preview(rec.gui_names, 30))}`")
        if rec.locale_sections:
            lines.append(f"- Locale sections: `{md_escape(list_preview(rec.locale_sections, 30))}`")
        if rec.json_keys:
            lines.append(f"- JSON keys: `{md_escape(list_preview(rec.json_keys, 30))}`")
        if rec.search_terms:
            lines.append(f"- Search terms: `{md_escape(list_preview(rec.search_terms, 50))}`")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def write_json_index(records: Sequence[FileRecord], path: Path) -> None:
    payload = {
        "generated_utc": _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat(),
        "files": [record.__dict__ for record in records],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Update the Tech Priests GitHub file manifest.")
    parser.add_argument("--root", default=".", help="Repository root to scan. Defaults to current directory.")
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST, help=f"Markdown manifest path. Defaults to {DEFAULT_MANIFEST}.")
    parser.add_argument("--json-index", default=None, help=f"Optional JSON index path. Suggested: {DEFAULT_JSON_INDEX}.")
    parser.add_argument("--max-scan-bytes", type=int, default=256_000, help="Maximum text bytes to scan per file for symbols.")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    if not root.exists() or not root.is_dir():
        print(f"error: root does not exist or is not a directory: {root}", file=sys.stderr)
        return 2

    manifest_path = (root / args.manifest).resolve()
    records = [index_file(path, root, args.max_scan_bytes) for path in iter_files(root, manifest_path)]
    records.sort(key=lambda r: r.path.lower())

    try:
        script_rel = relpath(Path(__file__).resolve(), root)
    except ValueError:
        script_rel = Path(__file__).name
    manifest = render_markdown(records, root, script_rel)
    manifest_path.write_text(manifest, encoding="utf-8")

    if args.json_index:
        write_json_index(records, (root / args.json_index).resolve())

    print(f"Indexed {len(records)} files into {manifest_path.relative_to(root).as_posix()}")
    if args.json_index:
        print(f"Wrote JSON index to {args.json_index}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
