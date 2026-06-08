#!/usr/bin/env python3
"""
Stage 4 strict visible-priest lifecycle operation-site scanner.

The broad visible-priest scanner intentionally catches many text references. This
third-pass scanner only records likely lifecycle operation sites:

- surface.create_entity / .create_entity blocks that mention priest/magos nearby
- .destroy(...) calls that mention priest/magos nearby
- actual calls or definitions for create_pair, remove_pair_for_entity,
  respawn_pair_priest, ensure_pair_priest, sanity_recall_all_priests
- lifecycle seal exported destroy/allow APIs

Run from repository root:

    python tools/audit_visible_priest_lifecycle_sites.py

Outputs:

    tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_VISIBLE_PRIEST_LIFECYCLE_SITES.md
    tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_VISIBLE_PRIEST_LIFECYCLE_SITES.json
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

ROOT = Path("tech-priests_src")
MD = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_VISIBLE_PRIEST_LIFECYCLE_SITES.md")
JSON_OUT = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_VISIBLE_PRIEST_LIFECYCLE_SITES.json")

PRIEST_CONTEXT = re.compile(r"priest|tech%-priest|tech_priest|magos", re.IGNORECASE)
OP_PATTERNS = [
    ("create_entity", re.compile(r"\.\s*create_entity\s*\(")),
    ("destroy_call", re.compile(r"\.\s*destroy\s*\(")),
    ("create_pair", re.compile(r"\bcreate_pair\s*\(|function\s+[^\n]*create_pair|_G\.create_pair")),
    ("remove_pair_for_entity", re.compile(r"\bremove_pair_for_entity\s*\(|function\s+[^\n]*remove_pair_for_entity|_G\.remove_pair_for_entity")),
    ("respawn_pair_priest", re.compile(r"\brespawn_pair_priest\s*\(|function\s+[^\n]*respawn_pair_priest|_G\.respawn_pair_priest")),
    ("ensure_pair_priest", re.compile(r"\bensure_pair_priest\s*\(|function\s+[^\n]*ensure_pair_priest|_G\.ensure_pair_priest")),
    ("sanity_recall_all_priests", re.compile(r"\bsanity_recall_all_priests\s*\(|function\s+[^\n]*sanity_recall_all_priests|_G\.sanity_recall_all_priests")),
    ("lifecycle_destroy_api", re.compile(r"tech_priests_destroy_priest_0500|destroy_priest\s*\(")),
    ("lifecycle_allow_cleanup_api", re.compile(r"tech_priests_allow_priest_station_cleanup_0500|allow_station_cleanup\s*\(")),
]

@dataclass
class Site:
    path: str
    line: int
    kind: str
    classification: str
    source: str
    context: List[str]


def iter_lua(root: Path) -> Iterable[Path]:
    for path in root.rglob("*.lua"):
        if ".git" in path.parts or "__pycache__" in path.parts:
            continue
        yield path


def has_priest_context(lines: Sequence[str]) -> bool:
    return PRIEST_CONTEXT.search("\n".join(lines)) is not None


def classify(path: str, kind: str, context: str) -> str:
    p = path.replace("\\", "/").lower()
    c = context.lower()
    if "priest_lifecycle_seal_0500" in p:
        return "canonical-lifecycle-seal-operation"
    if "priest_recovery_safety" in p or "priest_vanish_guard" in p:
        if kind == "create_entity":
            return "recovery-visible-priest-create"
        return "recovery-visible-priest-operation"
    if kind == "destroy_call":
        if "tech_priests_destroy_priest_0500" in c or "allow_priest_station_cleanup" in c or "allow_station_cleanup" in c:
            return "seal-mediated-priest-destroy"
        if "station" in c and ("mined" in c or "pickup" in c or "remove_pair" in c or "cleanup" in c):
            return "station-cleanup-visible-priest-destroy-review"
        return "direct-visible-priest-destroy-review"
    if kind == "create_entity":
        if "create_pair" in c:
            return "create-pair-visible-priest-create"
        if "respawn" in c or "missing" in c or "recover" in c or "vanish" in c:
            return "recovery-visible-priest-create"
        return "visible-priest-create-review"
    if kind in {"respawn_pair_priest", "ensure_pair_priest", "sanity_recall_all_priests"}:
        if "0500" in c or "blocked" in c or "disabled" in c:
            return "seal-blocked-recall-respawn-operation"
        return "recall-respawn-operation-review"
    if kind in {"create_pair", "remove_pair_for_entity"}:
        return "pair-map-lifecycle-operation"
    if kind in {"lifecycle_destroy_api", "lifecycle_allow_cleanup_api"}:
        return "lifecycle-seal-api-reference"
    return "visible-priest-lifecycle-operation-review"


def scan_file(path: Path, root: Path, context_lines: int) -> List[Site]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    rel = path.relative_to(root).as_posix()
    sites: List[Site] = []
    seen: set[Tuple[str, int, str]] = set()
    for idx, line in enumerate(lines, start=1):
        for kind, pat in OP_PATTERNS:
            if not pat.search(line):
                continue
            before_i = max(0, idx - 1 - context_lines)
            after_i = min(len(lines), idx + context_lines)
            context = lines[before_i:after_i]
            if kind in {"create_entity", "destroy_call"} and not has_priest_context(context):
                continue
            key = (rel, idx, kind)
            if key in seen:
                continue
            seen.add(key)
            sites.append(Site(rel, idx, kind, classify(rel, kind, "\n".join(context)), line.strip(), context))
    return sites


def scan(root: Path, context_lines: int) -> List[Site]:
    sites: List[Site] = []
    for path in iter_lua(root):
        sites.extend(scan_file(path, root, context_lines))
    sites.sort(key=lambda s: (s.classification, s.path.lower(), s.line, s.kind))
    return sites


def counts_by(sites: Sequence[Site], attr: str) -> Dict[str, int]:
    out: Dict[str, int] = {}
    for site in sites:
        key = getattr(site, attr)
        out[key] = out.get(key, 0) + 1
    return dict(sorted(out.items(), key=lambda kv: (-kv[1], kv[0])))


def markdown(root: Path, sites: Sequence[Site]) -> str:
    lines: List[str] = []
    lines.append("# Stage 4 Visible Priest Lifecycle Operation Sites")
    lines.append("")
    lines.append("Generated by `tools/audit_visible_priest_lifecycle_sites.py`.")
    lines.append("")
    lines.append(f"- Source root: `{root.as_posix()}`")
    lines.append(f"- Visible-priest lifecycle operation sites: `{len(sites)}`")
    lines.append("")
    lines.append("## Counts by classification")
    lines.append("")
    lines.append("| Classification | Count |")
    lines.append("|---|---:|")
    for key, count in counts_by(sites, "classification").items():
        lines.append(f"| `{key}` | {count} |")
    lines.append("")
    lines.append("## Counts by kind")
    lines.append("")
    lines.append("| Kind | Count |")
    lines.append("|---|---:|")
    for key, count in counts_by(sites, "kind").items():
        lines.append(f"| `{key}` | {count} |")
    lines.append("")
    lines.append("## Sites")
    lines.append("")
    lines.append("| File | Line | Kind | Classification | Source |")
    lines.append("|---|---:|---|---|---|")
    for site in sites:
        src = site.source.replace("|", "\\|")
        lines.append(f"| `{site.path}` | {site.line} | `{site.kind}` | `{site.classification}` | `{src}` |")
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("This is the strict third-pass lifecycle report. It is intended to replace the broad visible-priest text-reference report for repair triage. It still requires human review, but it avoids counting ordinary `priest` name mentions as lifecycle operations.")
    lines.append("")
    return "\n".join(lines)


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Audit strict visible priest lifecycle operation sites")
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--markdown", default=str(MD))
    parser.add_argument("--json", default=str(JSON_OUT))
    parser.add_argument("--context", type=int, default=10)
    args = parser.parse_args(argv)
    root = Path(args.root)
    if not root.exists():
        raise SystemExit(f"missing source root: {root}")
    sites = scan(root, max(0, args.context))
    md = Path(args.markdown)
    js = Path(args.json)
    md.parent.mkdir(parents=True, exist_ok=True)
    js.parent.mkdir(parents=True, exist_ok=True)
    md.write_text(markdown(root, sites), encoding="utf-8")
    js.write_text(json.dumps({
        "source_root": root.as_posix(),
        "total_sites": len(sites),
        "counts_by_classification": counts_by(sites, "classification"),
        "counts_by_kind": counts_by(sites, "kind"),
        "sites": [asdict(site) for site in sites],
    }, indent=2, sort_keys=True), encoding="utf-8")
    print(f"Scanned {root}; visible-priest lifecycle operation sites={len(sites)}")
    print(f"Wrote {md}")
    print(f"Wrote {js}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
