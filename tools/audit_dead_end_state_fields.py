#!/usr/bin/env python3
"""
Stage 5 dead-end state field scanner for Tech Priests.

This read-only scanner inventories assignments, clears, and status literals for
state fields that can leave a pair stranded if they are set without a matching
completion/cancel/timeout/release path.

Run from repository root:

    python tools/audit_dead_end_state_fields.py

Outputs:

    tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_STATE_FIELDS.md
    tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_STATE_FIELDS.json
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence

ROOT = Path("tech-priests_src")
MD = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_STATE_FIELDS.md")
JSON_OUT = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_STATE_FIELDS.json")

FIELD_GROUPS: Dict[str, Sequence[str]] = {
    "mode": [
        "mode",
    ],
    "active-task": [
        "active_task",
        "active_task_0285",
        "active_order_0469",
        "dispatcher_action",
        "dispatcher_phase",
    ],
    "order-queue": [
        "order_queue_0469",
        "pending_keys",
        "paused_tick",
        "pause_reason",
        "status",
        "current",
        "pending",
    ],
    "direct-acquisition": [
        "direct_acquisition_task_0336",
        "active_acquisition_0333",
        "dispatcher_direct_0513",
        "direct_due_tick_0273",
        "direct_due_tick_0312",
        "direct_due_tick_0315",
        "direct_due_tick_0336",
        "next_direct_laser_tick_0315",
        "direct_last_visual_tick_0306",
    ],
    "emergency-craft": [
        "emergency_craft",
        "station_crafting_task_0337",
        "active_craft_0479",
        "dispatcher_emergency_production_0514",
    ],
    "movement": [
        "movement_request_0418",
        "movement_controller_state_0418",
        "movement_controller_reason_0418",
        "movement_lease",
        "movement_owner",
        "movement_request",
        "movement_target",
    ],
    "lifecycle-recall-missing": [
        "recalling",
        "pending_recall",
        "force_recall",
        "recall_requested",
        "stuck_since",
        "last_stuck_tick",
        "stuck_recall_pending",
        "lost_priest_0490",
        "missing_priest_rescue_0490",
        "paused_by_missing_priest_0498",
        "paused_by_missing_priest_0500",
        "link_0495",
        "missing_since",
        "lifecycle_0503",
        "lifecycle_0506",
        "lifecycle_0508",
    ],
    "reservations": [
        "reservation",
        "reservations",
        "target_claims",
        "cluster_reservations",
        "claim",
        "release",
        "expires_tick",
        "reserved_by",
    ],
    "repair": [
        "repair_executor_0516",
        "dispatcher_repair_0516",
        "repair_task",
        "repair_target",
    ],
    "consecration": [
        "consecration_0515",
        "consecration_task",
        "sanctify",
        "target_claims",
    ],
    "combat": [
        "combat_target",
        "combat_repair",
        "combat_repair_doctrine_0517",
        "cluster_reservations",
    ],
    "construction": [
        "construction_task",
        "construction",
        "constructible",
        "ghost",
        "build_target",
    ],
    "logistics": [
        "logistic_requested_item",
        "machine_logistics_0528",
        "logistics_fetch_0527",
        "waiting-known-source-fetch",
        "move-to-storage",
        "move-to-machine",
    ],
}

STATUS_LITERALS = [
    "paused-missing-priest",
    "travelling-to-direct-acquisition",
    "travelling-to-dirt-scrape",
    "waiting-known-source-fetch",
    "move-to-storage",
    "move-to-machine",
    "moving-to-construction-source",
    "deferred-missing-station-item",
    "complete",
    "cancelled",
    "expired",
    "active",
    "pending",
    "paused",
    "failed",
]

@dataclass
class Hit:
    path: str
    line: int
    group: str
    field: str
    kind: str
    source: str
    context_before: List[str]
    context_after: List[str]


def iter_lua(root: Path) -> Iterable[Path]:
    for path in root.rglob("*.lua"):
        if ".git" in path.parts or "__pycache__" in path.parts:
            continue
        yield path


def classify_kind(line: str, field: str) -> str:
    stripped = line.strip()
    escaped = re.escape(field)
    if re.search(r"\.\s*" + escaped + r"\s*=\s*nil\b", stripped):
        return "field-clear"
    if re.search(r"\.\s*" + escaped + r"\s*=", stripped):
        return "field-assignment"
    if re.search(r"\b" + escaped + r"\s*=\s*nil\b", stripped):
        return "local-or-table-clear"
    if re.search(r"\b" + escaped + r"\s*=", stripped):
        return "local-or-table-assignment"
    if field in STATUS_LITERALS:
        return "status-literal"
    if "release" in stripped.lower() or "cleanup" in stripped.lower() or "expire" in stripped.lower():
        return "cleanup-or-release-reference"
    return "reference"


def scan_file(path: Path, root: Path, context_lines: int) -> List[Hit]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    rel = path.relative_to(root).as_posix()
    hits: List[Hit] = []
    seen: set[tuple[int, str, str]] = set()
    for idx, line in enumerate(lines, start=1):
        for group, fields in FIELD_GROUPS.items():
            for field in fields:
                if field not in line:
                    continue
                key = (idx, group, field)
                if key in seen:
                    continue
                seen.add(key)
                before = lines[max(0, idx - 1 - context_lines):idx - 1]
                after = lines[idx:min(len(lines), idx + context_lines)]
                hits.append(Hit(rel, idx, group, field, classify_kind(line, field), line.strip(), before, after))
        for literal in STATUS_LITERALS:
            if literal in line:
                group = "status-literals"
                key = (idx, group, literal)
                if key in seen:
                    continue
                seen.add(key)
                before = lines[max(0, idx - 1 - context_lines):idx - 1]
                after = lines[idx:min(len(lines), idx + context_lines)]
                hits.append(Hit(rel, idx, group, literal, "status-literal", line.strip(), before, after))
    return hits


def scan(root: Path, context_lines: int) -> List[Hit]:
    hits: List[Hit] = []
    for path in iter_lua(root):
        hits.extend(scan_file(path, root, context_lines))
    hits.sort(key=lambda h: (h.group, h.path.lower(), h.line, h.field))
    return hits


def counts_by(hits: Sequence[Hit], attr: str) -> Dict[str, int]:
    out: Dict[str, int] = {}
    for hit in hits:
        key = getattr(hit, attr)
        out[key] = out.get(key, 0) + 1
    return dict(sorted(out.items(), key=lambda kv: (-kv[1], kv[0])))


def markdown(root: Path, hits: Sequence[Hit]) -> str:
    lines: List[str] = []
    lines.append("# Stage 5 Dead-End State Field Report")
    lines.append("")
    lines.append("Generated by `tools/audit_dead_end_state_fields.py`.")
    lines.append("")
    lines.append(f"- Source root: `{root.as_posix()}`")
    lines.append(f"- Total state-field hits: `{len(hits)}`")
    lines.append("")
    lines.append("## Counts by state group")
    lines.append("")
    lines.append("| Group | Count |")
    lines.append("|---|---:|")
    for key, count in counts_by(hits, "group").items():
        lines.append(f"| `{key}` | {count} |")
    lines.append("")
    lines.append("## Counts by kind")
    lines.append("")
    lines.append("| Kind | Count |")
    lines.append("|---|---:|")
    for key, count in counts_by(hits, "kind").items():
        lines.append(f"| `{key}` | {count} |")
    lines.append("")
    lines.append("## Counts by field")
    lines.append("")
    lines.append("| Field | Count |")
    lines.append("|---|---:|")
    for key, count in counts_by(hits, "field").items():
        lines.append(f"| `{key}` | {count} |")
    lines.append("")
    lines.append("## Hits")
    lines.append("")
    lines.append("| Group | Field | File | Line | Kind | Source |")
    lines.append("|---|---|---|---:|---|---|")
    for hit in hits:
        src = hit.source.replace("|", "\\|")
        lines.append(f"| `{hit.group}` | `{hit.field}` | `{hit.path}` | {hit.line} | `{hit.kind}` | `{src}` |")
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("This report is intentionally broad. It identifies state fields that need manual pairing: set vs clear, start vs complete, claim vs release, pause vs unpause, and movement request vs movement completion. It does not prove a bug by itself.")
    lines.append("")
    return "\n".join(lines)


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Audit dead-end state fields")
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--markdown", default=str(MD))
    parser.add_argument("--json", default=str(JSON_OUT))
    parser.add_argument("--context", type=int, default=5)
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
        "counts_by_group": counts_by(hits, "group"),
        "counts_by_kind": counts_by(hits, "kind"),
        "counts_by_field": counts_by(hits, "field"),
        "hits": [asdict(hit) for hit in hits],
    }, indent=2, sort_keys=True), encoding="utf-8")
    print(f"Scanned {root}; state-field hits={len(hits)}")
    print(f"Wrote {md}")
    print(f"Wrote {js}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
