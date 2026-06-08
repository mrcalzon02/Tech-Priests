#!/usr/bin/env python3
"""
Stage 4 lifecycle global owner scanner.

This read-only scanner inventories modules that assign, wrap, or call the core
pair/priest lifecycle globals, then sorts them by approximate control.lua load
order where possible.

Target globals:
- create_pair
- remove_pair_for_entity
- respawn_pair_priest
- ensure_pair_priest
- sanity_recall_all_priests
- tech_priests_destroy_priest_0500
- tech_priests_allow_priest_station_cleanup_0500

Run from repository root:

    python tools/audit_lifecycle_global_owners.py

Outputs:

    tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_LIFECYCLE_GLOBAL_OWNERS.md
    tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_LIFECYCLE_GLOBAL_OWNERS.json
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

ROOT = Path("tech-priests_src")
CONTROL = ROOT / "control.lua"
MD = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_LIFECYCLE_GLOBAL_OWNERS.md")
JSON_OUT = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_LIFECYCLE_GLOBAL_OWNERS.json")

GLOBALS = [
    "create_pair",
    "remove_pair_for_entity",
    "respawn_pair_priest",
    "ensure_pair_priest",
    "sanity_recall_all_priests",
    "tech_priests_destroy_priest_0500",
    "tech_priests_allow_priest_station_cleanup_0500",
]

ASSIGN_PATTERNS = [
    ("global_assignment", re.compile(r"(?:_G\s*\.\s*|_G\s*\[\s*['\"])(%s)(?:['\"]\s*\])?\s*=")),
    ("function_definition", re.compile(r"function\s+(%s)\s*\(")),
    ("global_function_definition", re.compile(r"function\s+_G\s*\.\s*(%s)\s*\(")),
]

CALL_PATTERNS = [
    ("global_call", re.compile(r"(?<!function\s)\b(%s)\s*\(")),
    ("_G_call", re.compile(r"_G\s*\.\s*(%s)\s*\(")),
]

@dataclass
class Hit:
    path: str
    line: int
    global_name: str
    kind: str
    classification: str
    control_order: int
    source: str
    context: List[str]


def build_pattern(template: str, name: str) -> re.Pattern[str]:
    return re.compile(template % re.escape(name))


def iter_lua(root: Path) -> Iterable[Path]:
    for path in root.rglob("*.lua"):
        if ".git" in path.parts or "__pycache__" in path.parts:
            continue
        yield path


def module_path_from_require(req: str) -> str:
    return req.replace(".", "/") + ".lua"


def load_order(root: Path) -> Dict[str, int]:
    order: Dict[str, int] = {}
    if not CONTROL.exists():
        return order
    idx = 0
    control_rel = CONTROL.relative_to(root).as_posix()
    order[control_rel] = idx
    text = CONTROL.read_text(encoding="utf-8", errors="replace")
    for m in re.finditer(r"require\s*\(?\s*['\"]([^'\"]+)['\"]", text):
        idx += 1
        rel = module_path_from_require(m.group(1))
        order.setdefault(rel, idx)
    # Generated legacy fragments are hard-loaded from control in fixed order; make
    # sure their natural order is represented even if parsing misses a require.
    for n in range(1, 23):
        rel = f"scripts/generated/control_legacy_part_{n:03d}.lua"
        if rel not in order:
            idx += 1
            order[rel] = idx
    return order


def classify(path: str, global_name: str, kind: str, context: str) -> str:
    p = path.replace("\\", "/").lower()
    c = context.lower()
    if "generated/control_legacy" in p:
        if kind in {"global_assignment", "function_definition", "global_function_definition"}:
            return "legacy-definition-or-assignment"
        return "legacy-call"
    if "priest_lifecycle_seal_0500" in p:
        return "lifecycle-seal-owner-or-wrapper"
    if "priest_recovery_safety_0503" in p:
        return "recovery-safety-owner-or-wrapper"
    if "pair_death_and_respawn" in p:
        return "pair-death-respawn-wrapper"
    if "station_pair_recovery" in p:
        return "station-pair-recovery-wrapper"
    if "pair_link_hardening" in p:
        return "pair-link-hardening-wrapper"
    if "mobility_recovery_contract" in p:
        return "mobility-recovery-wrapper"
    if "movement_recovery_authority" in p:
        return "movement-recovery-wrapper"
    if "task_pair_audit" in p:
        return "task-pair-audit-wrapper"
    if "behavior_execution_doctrine" in p:
        return "behavior-doctrine-wrapper"
    if kind in {"global_assignment", "function_definition", "global_function_definition"}:
        return "other-assignment-or-wrapper"
    return "call-or-reference"


def is_assignment_kind(kind: str) -> bool:
    return kind in {"global_assignment", "function_definition", "global_function_definition"}


def scan_file(path: Path, root: Path, order_map: Dict[str, int], context_lines: int) -> List[Hit]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    rel = path.relative_to(root).as_posix()
    hits: List[Hit] = []
    seen: set[Tuple[int, str, str]] = set()
    for idx, line in enumerate(lines, start=1):
        before = lines[max(0, idx - 1 - context_lines):idx - 1]
        after = lines[idx:min(len(lines), idx + context_lines)]
        context = before + [line] + after
        blob = "\n".join(context)
        for name in GLOBALS:
            for kind, template in ASSIGN_PATTERNS:
                if build_pattern(template.pattern, name).search(line):
                    key = (idx, name, kind)
                    if key not in seen:
                        seen.add(key)
                        hits.append(Hit(rel, idx, name, kind, classify(rel, name, kind, blob), order_map.get(rel, 999999), line.strip(), context))
            for kind, template in CALL_PATTERNS:
                if build_pattern(template.pattern, name).search(line):
                    # Avoid double-counting assignment/function-definition lines as calls.
                    if any(build_pattern(t.pattern, name).search(line) for _, t in ASSIGN_PATTERNS):
                        continue
                    key = (idx, name, kind)
                    if key not in seen:
                        seen.add(key)
                        hits.append(Hit(rel, idx, name, kind, classify(rel, name, kind, blob), order_map.get(rel, 999999), line.strip(), context))
    return hits


def scan(root: Path, context_lines: int) -> Tuple[List[Hit], Dict[str, int]]:
    order_map = load_order(root)
    hits: List[Hit] = []
    for path in iter_lua(root):
        hits.extend(scan_file(path, root, order_map, context_lines))
    hits.sort(key=lambda h: (h.global_name, h.control_order, h.path.lower(), h.line, h.kind))
    return hits, order_map


def counts_by(hits: Sequence[Hit], attr: str) -> Dict[str, int]:
    out: Dict[str, int] = {}
    for hit in hits:
        key = getattr(hit, attr)
        out[key] = out.get(key, 0) + 1
    return dict(sorted(out.items(), key=lambda kv: (-kv[1], kv[0])))


def final_assignment_candidates(hits: Sequence[Hit]) -> Dict[str, List[Hit]]:
    out: Dict[str, List[Hit]] = {}
    for name in GLOBALS:
        assigns = [h for h in hits if h.global_name == name and is_assignment_kind(h.kind)]
        assigns.sort(key=lambda h: (h.control_order, h.path.lower(), h.line))
        out[name] = assigns[-6:]
    return out


def markdown(root: Path, hits: Sequence[Hit], order_map: Dict[str, int]) -> str:
    lines: List[str] = []
    lines.append("# Stage 4 Lifecycle Global Owner Report")
    lines.append("")
    lines.append("Generated by `tools/audit_lifecycle_global_owners.py`.")
    lines.append("")
    lines.append(f"- Source root: `{root.as_posix()}`")
    lines.append(f"- Total lifecycle global hits: `{len(hits)}`")
    lines.append("")
    lines.append("## Counts by global")
    lines.append("")
    lines.append("| Global | Count |")
    lines.append("|---|---:|")
    for key, count in counts_by(hits, "global_name").items():
        lines.append(f"| `{key}` | {count} |")
    lines.append("")
    lines.append("## Counts by kind")
    lines.append("")
    lines.append("| Kind | Count |")
    lines.append("|---|---:|")
    for key, count in counts_by(hits, "kind").items():
        lines.append(f"| `{key}` | {count} |")
    lines.append("")
    lines.append("## Counts by classification")
    lines.append("")
    lines.append("| Classification | Count |")
    lines.append("|---|---:|")
    for key, count in counts_by(hits, "classification").items():
        lines.append(f"| `{key}` | {count} |")
    lines.append("")
    lines.append("## Last assignment/wrapper candidates by control.lua order")
    lines.append("")
    lines.append("These are static candidates, not runtime proof. Later modules can assign globals from their install functions, and load order assumes the `control.lua` require sequence succeeds.")
    lines.append("")
    for name, assigns in final_assignment_candidates(hits).items():
        lines.append(f"### `{name}`")
        lines.append("")
        if not assigns:
            lines.append("No assignment/function-definition sites found.")
            lines.append("")
            continue
        lines.append("| Order | File | Line | Kind | Classification | Source |")
        lines.append("|---:|---|---:|---|---|---|")
        for h in assigns:
            src = h.source.replace("|", "\\|")
            order = h.control_order if h.control_order < 999999 else "?"
            lines.append(f"| {order} | `{h.path}` | {h.line} | `{h.kind}` | `{h.classification}` | `{src}` |")
        lines.append("")
    lines.append("## All hits")
    lines.append("")
    lines.append("| Global | Order | File | Line | Kind | Classification | Source |")
    lines.append("|---|---:|---|---:|---|---|---|")
    for h in hits:
        src = h.source.replace("|", "\\|")
        order = h.control_order if h.control_order < 999999 else "?"
        lines.append(f"| `{h.global_name}` | {order} | `{h.path}` | {h.line} | `{h.kind}` | `{h.classification}` | `{src}` |")
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("This report is a static owner/wrapper map. The next manual pass should compare the last assignment candidates against the documented control.lua lifecycle order and runtime diagnostics. It should not be used alone to delete or reorder lifecycle wrappers.")
    lines.append("")
    return "\n".join(lines)


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Audit lifecycle global owner/wrapper sites")
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--markdown", default=str(MD))
    parser.add_argument("--json", default=str(JSON_OUT))
    parser.add_argument("--context", type=int, default=5)
    args = parser.parse_args(argv)
    root = Path(args.root)
    if not root.exists():
        raise SystemExit(f"missing source root: {root}")
    hits, order_map = scan(root, max(0, args.context))
    md = Path(args.markdown)
    js = Path(args.json)
    md.parent.mkdir(parents=True, exist_ok=True)
    js.parent.mkdir(parents=True, exist_ok=True)
    md.write_text(markdown(root, hits, order_map), encoding="utf-8")
    js.write_text(json.dumps({
        "source_root": root.as_posix(),
        "total_hits": len(hits),
        "counts_by_global": counts_by(hits, "global_name"),
        "counts_by_kind": counts_by(hits, "kind"),
        "counts_by_classification": counts_by(hits, "classification"),
        "final_assignment_candidates": {name: [asdict(h) for h in hs] for name, hs in final_assignment_candidates(hits).items()},
        "hits": [asdict(h) for h in hits],
    }, indent=2, sort_keys=True), encoding="utf-8")
    print(f"Scanned {root}; lifecycle global hits={len(hits)}")
    print(f"Wrote {md}")
    print(f"Wrote {js}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
