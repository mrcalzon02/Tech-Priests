#!/usr/bin/env python3
"""
Scan the Tech Priests source tree for Factorio event/tick authority patterns.

Run from the repository root:

    python tools/audit_event_authority.py

Optional:

    python tools/audit_event_authority.py --root tech-priests_src --markdown tech-priests_src/docs/CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.md --json tech-priests_src/docs/CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.json

This tool is intentionally read-only. It does not edit Lua files and does not
attempt to decide final architecture. It creates an inventory so Stage 2 can
classify direct event/tick registration, registry ownership, and broker service
registration from source rather than memory.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Iterable, List, Optional


DEFAULT_ROOTS = ["tech-priests_src"]

PATTERNS = [
    ("direct_script_on_event", re.compile(r"\bscript\s*\.\s*on_event\s*\(")),
    ("direct_script_on_nth_tick", re.compile(r"\bscript\s*\.\s*on_nth_tick\s*\(")),
    ("direct_script_on_init", re.compile(r"\bscript\s*\.\s*on_init\s*\(")),
    ("direct_script_on_configuration_changed", re.compile(r"\bscript\s*\.\s*on_configuration_changed\s*\(")),
    ("registry_on_event", re.compile(r"\b(?:R|Registry|registry)\s*\.\s*on_event\s*\(")),
    ("registry_on_nth_tick", re.compile(r"\b(?:R|Registry|registry)\s*\.\s*on_nth_tick\s*\(")),
    ("registry_on_init", re.compile(r"\b(?:R|Registry|registry)\s*\.\s*on_init\s*\(")),
    ("registry_on_configuration_changed", re.compile(r"\b(?:R|Registry|registry)\s*\.\s*on_configuration_changed\s*\(")),
    ("broker_register_service", re.compile(r"\.\s*register_service\s*\(")),
    ("registry_global_read", re.compile(r"TechPriestsRuntimeEventRegistry")),
    ("registry_require", re.compile(r"require\s*\(?\s*['\"]scripts\.core\.runtime_event_registry['\"]")),
    ("tick_broker_require", re.compile(r"require\s*\(?\s*['\"]scripts\.core\.runtime_tick_broker['\"]")),
]

DIRECT_KINDS = {
    "direct_script_on_event",
    "direct_script_on_nth_tick",
    "direct_script_on_init",
    "direct_script_on_configuration_changed",
}

REGISTRY_KINDS = {
    "registry_on_event",
    "registry_on_nth_tick",
    "registry_on_init",
    "registry_on_configuration_changed",
}


@dataclass
class Hit:
    path: str
    line: int
    kind: str
    text: str
    context_before: List[str] = field(default_factory=list)
    context_after: List[str] = field(default_factory=list)
    provisional_classification: str = "unclassified"


def iter_lua_files(root: Path) -> Iterable[Path]:
    ignore_dirs = {".git", "__pycache__", ".venv", "venv", "node_modules"}
    for path in root.rglob("*.lua"):
        if any(part in ignore_dirs for part in path.parts):
            continue
        yield path


def classify_hit(path: str, kind: str, text: str, before: List[str], after: List[str]) -> str:
    blob = "\n".join(before + [text] + after).lower()
    p = path.replace("\\", "/")

    if p.endswith("scripts/core/runtime_event_registry.lua") and kind in DIRECT_KINDS:
        return "canonical-registry-internal"
    if p.endswith("scripts/core/efficiency_economy_0596.lua") and kind == "direct_script_on_nth_tick":
        return "early-raw-nth-tick-monkeypatch"
    if "fallback" in blob or "registry is unavailable" in blob or "unavailable" in blob:
        if kind in DIRECT_KINDS:
            return "direct-compatibility-fallback"
    if kind in REGISTRY_KINDS:
        return "registry-owned"
    if kind == "broker_register_service":
        return "broker-service-registration"
    if kind == "registry_global_read":
        return "registry-global-reference"
    if kind == "registry_require":
        return "registry-require"
    if kind == "tick_broker_require":
        return "tick-broker-require"
    if kind in DIRECT_KINDS:
        return "direct-registration-review-required"
    return "unclassified"


def scan_file(path: Path, root: Path, context: int) -> List[Hit]:
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []

    hits: List[Hit] = []
    rel = path.relative_to(root).as_posix()
    for index, line in enumerate(lines, start=1):
        for kind, pattern in PATTERNS:
            if pattern.search(line):
                before = lines[max(0, index - 1 - context): index - 1]
                after = lines[index: min(len(lines), index + context)]
                hits.append(Hit(
                    path=rel,
                    line=index,
                    kind=kind,
                    text=line.strip(),
                    context_before=[s.rstrip() for s in before],
                    context_after=[s.rstrip() for s in after],
                    provisional_classification=classify_hit(rel, kind, line, before, after),
                ))
    return hits


def scan(root: Path, context: int) -> List[Hit]:
    hits: List[Hit] = []
    for path in iter_lua_files(root):
        hits.extend(scan_file(path, root, context))
    hits.sort(key=lambda h: (h.path.lower(), h.line, h.kind))
    return hits


def counts_by(items: Iterable[Hit], attr: str) -> dict:
    counts = {}
    for item in items:
        key = getattr(item, attr)
        counts[key] = counts.get(key, 0) + 1
    return dict(sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])))


def markdown_report(root: Path, hits: List[Hit]) -> str:
    direct = [h for h in hits if h.kind in DIRECT_KINDS]
    registry = [h for h in hits if h.kind in REGISTRY_KINDS]

    lines: List[str] = []
    lines.append("# Stage 2 Event Authority Scanner Report")
    lines.append("")
    lines.append("Generated by `tools/audit_event_authority.py`.")
    lines.append("")
    lines.append(f"- Source root: `{root.as_posix()}`")
    lines.append(f"- Total hits: `{len(hits)}`")
    lines.append(f"- Direct `script.*` registration hits: `{len(direct)}`")
    lines.append(f"- Registry route hits: `{len(registry)}`")
    lines.append("")

    lines.append("## Counts by kind")
    lines.append("")
    lines.append("| Kind | Count |")
    lines.append("|---|---:|")
    for kind, count in counts_by(hits, "kind").items():
        lines.append(f"| `{kind}` | {count} |")
    lines.append("")

    lines.append("## Counts by provisional classification")
    lines.append("")
    lines.append("| Classification | Count |")
    lines.append("|---|---:|")
    for cls, count in counts_by(hits, "provisional_classification").items():
        lines.append(f"| `{cls}` | {count} |")
    lines.append("")

    lines.append("## Direct registration hits")
    lines.append("")
    if not direct:
        lines.append("No direct registration hits found.")
    else:
        lines.append("| File | Line | Kind | Classification | Source |")
        lines.append("|---|---:|---|---|---|")
        for h in direct:
            source = h.text.replace("|", "\\|")
            lines.append(f"| `{h.path}` | {h.line} | `{h.kind}` | `{h.provisional_classification}` | `{source}` |")
    lines.append("")

    lines.append("## Registry/broker/global hits")
    lines.append("")
    other = [h for h in hits if h.kind not in DIRECT_KINDS]
    lines.append("| File | Line | Kind | Classification | Source |")
    lines.append("|---|---:|---|---|---|")
    for h in other:
        source = h.text.replace("|", "\\|")
        lines.append(f"| `{h.path}` | {h.line} | `{h.kind}` | `{h.provisional_classification}` | `{source}` |")
    lines.append("")

    lines.append("## Notes")
    lines.append("")
    lines.append("This scanner is intentionally conservative. `direct-registration-review-required` does not prove a bug; it means the call should be manually classified as registry internal, early monkey-patch, fallback, legacy exception, or migration target.")
    lines.append("")
    return "\n".join(lines)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Audit Tech Priests event/tick authority patterns.")
    parser.add_argument("--root", default=None, help="Source root to scan. Defaults to tech-priests_src if present, else current directory.")
    parser.add_argument("--markdown", default="tech-priests_src/docs/CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.md", help="Markdown report output path.")
    parser.add_argument("--json", default="tech-priests_src/docs/CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.json", help="JSON report output path.")
    parser.add_argument("--context", type=int, default=2, help="Context lines to store in JSON around each hit.")
    args = parser.parse_args(argv)

    if args.root:
        root = Path(args.root)
    else:
        root = next((Path(p) for p in DEFAULT_ROOTS if Path(p).exists()), Path("."))

    if not root.exists() or not root.is_dir():
        raise SystemExit(f"source root does not exist: {root}")

    hits = scan(root, max(0, args.context))

    md_path = Path(args.markdown)
    json_path = Path(args.json)
    md_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.parent.mkdir(parents=True, exist_ok=True)

    md_path.write_text(markdown_report(root, hits), encoding="utf-8")
    json_path.write_text(json.dumps({
        "source_root": root.as_posix(),
        "total_hits": len(hits),
        "counts_by_kind": counts_by(hits, "kind"),
        "counts_by_classification": counts_by(hits, "provisional_classification"),
        "hits": [asdict(h) for h in hits],
    }, indent=2, sort_keys=True), encoding="utf-8")

    direct_count = sum(1 for h in hits if h.kind in DIRECT_KINDS)
    print(f"Scanned {root}; hits={len(hits)} direct={direct_count}")
    print(f"Wrote {md_path}")
    print(f"Wrote {json_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
