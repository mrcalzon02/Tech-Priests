#!/usr/bin/env python3
"""
Stage 4 visible-priest lifecycle scanner.

The broad lifecycle scanner intentionally captures GUI, rendering, proxy, item,
and world-entity lifecycles. This second-pass scanner narrows the surface to
visible Tech-Priest lifecycle risks:

- creating priest entities,
- destroying priest entities,
- respawning/replacing priests,
- removing pairs because of priest events,
- stuck/recall/missing-priest recovery paths,
- lifecycle seal interaction points.

Run from repository root:

    python tools/audit_visible_priest_lifecycle.py

Outputs:

    tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_VISIBLE_PRIEST_LIFECYCLE.md
    tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_VISIBLE_PRIEST_LIFECYCLE.json
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence

ROOT = Path("tech-priests_src")
MD = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_VISIBLE_PRIEST_LIFECYCLE.md")
JSON_OUT = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_VISIBLE_PRIEST_LIFECYCLE.json")

PRIEST_TEXT = re.compile(r"priest|tech%-priest|tech_priest|magos", re.IGNORECASE)
PATTERNS = [
    ("priest_create_entity", re.compile(r"create_entity\s*\([^\n]*priest|name\s*=\s*[^\n]*priest|tech%-priest", re.IGNORECASE)),
    ("priest_destroy", re.compile(r"priest[^\n]*\.\s*destroy\s*\(|\.\s*destroy\s*\([^\n]*priest", re.IGNORECASE)),
    ("destroy_priest_api", re.compile(r"destroy_priest|tech_priests_destroy_priest_0500", re.IGNORECASE)),
    ("respawn_pair_priest", re.compile(r"respawn_pair_priest", re.IGNORECASE)),
    ("ensure_pair_priest", re.compile(r"ensure_pair_priest", re.IGNORECASE)),
    ("remove_pair_for_entity", re.compile(r"remove_pair_for_entity", re.IGNORECASE)),
    ("create_pair", re.compile(r"create_pair", re.IGNORECASE)),
    ("missing_priest", re.compile(r"missing[_%-]?priest|lost_priest", re.IGNORECASE)),
    ("stuck_or_recall", re.compile(r"stuck|recall|force_recall|pending_recall", re.IGNORECASE)),
    ("priest_destructible", re.compile(r"priest[^\n]*\.\s*destructible\s*=|\.\s*destructible\s*=\s*false", re.IGNORECASE)),
    ("priest_active", re.compile(r"priest[^\n]*\.\s*active\s*=", re.IGNORECASE)),
    ("lifecycle_seal", re.compile(r"priest_lifecycle_seal|TechPriestsPriestLifecycleSeal0500|lifecycle_0500", re.IGNORECASE)),
]

@dataclass
class Hit:
    path: str
    line: int
    kind: str
    classification: str
    source: str
    context_before: List[str]
    context_after: List[str]


def iter_lua(root: Path) -> Iterable[Path]:
    for path in root.rglob("*.lua"):
        if ".git" in path.parts or "__pycache__" in path.parts:
            continue
        yield path


def classify(path: str, kind: str, blob: str) -> str:
    p = path.replace("\\", "/").lower()
    b = blob.lower()
    if "priest_lifecycle_seal_0500" in p:
        return "canonical-lifecycle-seal"
    if kind in {"priest_destroy", "destroy_priest_api"}:
        if "station" in b and ("cleanup" in b or "allow" in b or "pickup" in b or "remove_pair" in b):
            return "station-authorized-priest-destroy-path"
        return "visible-priest-destroy-review"
    if kind in {"respawn_pair_priest", "ensure_pair_priest", "missing_priest"}:
        if "blocked" in b or "disabled" in b or "0500" in b:
            return "respawn-recovery-blocked-by-seal"
        return "respawn-or-missing-priest-review"
    if kind == "priest_create_entity":
        if "create_pair" in b or "respawn" in b or "recovery" in p or "vanish" in p:
            return "visible-priest-create-recovery-review"
        return "visible-priest-create-review"
    if kind in {"stuck_or_recall"}:
        if "disabled" in b or "0500" in b:
            return "stuck-recall-disabled-by-seal"
        return "stuck-recall-review"
    if kind in {"priest_destructible", "priest_active"}:
        return "visible-priest-state-write"
    if kind in {"remove_pair_for_entity", "create_pair"}:
        return "pair-map-lifecycle-review"
    if kind == "lifecycle_seal":
        return "lifecycle-seal-reference"
    return "visible-priest-lifecycle-review"


def relevant_line(line: str) -> bool:
    return PRIEST_TEXT.search(line) is not None


def scan_file(path: Path, root: Path, context_lines: int) -> List[Hit]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    rel = path.relative_to(root).as_posix()
    hits: List[Hit] = []
    for idx, line in enumerate(lines, start=1):
        for kind, pat in PATTERNS:
            if not pat.search(line):
                continue
            if kind in {"stuck_or_recall", "remove_pair_for_entity", "create_pair"} and not relevant_line("\n".join(lines[max(0, idx-5):min(len(lines), idx+5)])):
                continue
            before = lines[max(0, idx - 1 - context_lines):idx - 1]
            after = lines[idx:min(len(lines), idx + context_lines)]
            blob = "\n".join(before + [line] + after)
            hits.append(Hit(rel, idx, kind, classify(rel, kind, blob), line.strip(), before, after))
    return hits


def scan(root: Path, context_lines: int) -> List[Hit]:
    hits: List[Hit] = []
    for path in iter_lua(root):
        hits.extend(scan_file(path, root, context_lines))
    hits.sort(key=lambda h: (h.classification, h.path.lower(), h.line, h.kind))
    return hits


def counts_by(hits: Sequence[Hit], attr: str) -> Dict[str, int]:
    out: Dict[str, int] = {}
    for h in hits:
        key = getattr(h, attr)
        out[key] = out.get(key, 0) + 1
    return dict(sorted(out.items(), key=lambda kv: (-kv[1], kv[0])))


def markdown(root: Path, hits: Sequence[Hit]) -> str:
    lines: List[str] = []
    lines.append("# Stage 4 Visible Priest Lifecycle Report")
    lines.append("")
    lines.append("Generated by `tools/audit_visible_priest_lifecycle.py`.")
    lines.append("")
    lines.append(f"- Source root: `{root.as_posix()}`")
    lines.append(f"- Visible-priest lifecycle hits: `{len(hits)}`")
    lines.append("")
    lines.append("## Counts by classification")
    lines.append("")
    lines.append("| Classification | Count |")
    lines.append("|---|---:|")
    for key, count in counts_by(hits, "classification").items():
        lines.append(f"| `{key}` | {count} |")
    lines.append("")
    lines.append("## Counts by kind")
    lines.append("")
    lines.append("| Kind | Count |")
    lines.append("|---|---:|")
    for key, count in counts_by(hits, "kind").items():
        lines.append(f"| `{key}` | {count} |")
    lines.append("")
    lines.append("## Hits")
    lines.append("")
    lines.append("| File | Line | Kind | Classification | Source |")
    lines.append("|---|---:|---|---|---|")
    for h in hits:
        src = h.source.replace("|", "\\|")
        lines.append(f"| `{h.path}` | {h.line} | `{h.kind}` | `{h.classification}` | `{src}` |")
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("This second-pass report is still conservative, but it is focused on visible Tech-Priest lifecycle rather than rendering, GUI, proxy, or unrelated world-entity cleanup. Use it to identify create/destroy/respawn/recovery paths before changing movement or behavior-critical command code.")
    lines.append("")
    return "\n".join(lines)


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Audit visible Tech-Priest lifecycle surfaces")
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--markdown", default=str(MD))
    parser.add_argument("--json", default=str(JSON_OUT))
    parser.add_argument("--context", type=int, default=7)
    args = parser.parse_args(argv)
    root = Path(args.root)
    if not root.exists():
        raise SystemExit(f"missing source root: {root}")
    hits = scan(root, max(0, args.context))
    md = Path(args.markdown)
    js = Path(args.json)
    md.parent.mkdir(parents=True, exist_ok=True)
    js.parent.mkdir(parents=True, exist_ok=True)
    md.write_text(markdown(root, hits), encoding="utf-8")
    js.write_text(json.dumps({
        "source_root": root.as_posix(),
        "total_hits": len(hits),
        "counts_by_classification": counts_by(hits, "classification"),
        "counts_by_kind": counts_by(hits, "kind"),
        "hits": [asdict(h) for h in hits],
    }, indent=2, sort_keys=True), encoding="utf-8")
    print(f"Scanned {root}; visible-priest lifecycle hits={len(hits)}")
    print(f"Wrote {md}")
    print(f"Wrote {js}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
