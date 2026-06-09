#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence

ROOT = Path("tech-priests_src")
MD = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_TRANSITION_SITES.md")
JSON_OUT = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_TRANSITION_SITES.json")

WATCH_FIELDS = {
    "mode": "mode",
    "active-task": "active_task|active_task_0285|active_order_0469|dispatcher_action|dispatcher_phase",
    "order-queue": "order_queue_0469|pending_keys|paused_tick|pause_reason|status|current|pending",
    "direct-acquisition": "direct_acquisition_task_0336|active_acquisition_0333|dispatcher_direct_0513|direct_due_tick_0273|direct_due_tick_0312|direct_due_tick_0315|direct_due_tick_0336|next_direct_laser_tick_0315|direct_last_visual_tick_0306",
    "emergency-craft": "emergency_craft|station_crafting_task_0337|active_craft_0479|dispatcher_emergency_production_0514",
    "movement": "movement_request_0418|movement_controller_state_0418|movement_controller_reason_0418|movement_lease|movement_owner|movement_request|movement_target",
    "lifecycle-recall-missing": "recalling|pending_recall|force_recall|recall_requested|stuck_since|last_stuck_tick|stuck_recall_pending|lost_priest_0490|missing_priest_rescue_0490|paused_by_missing_priest_0498|paused_by_missing_priest_0500|missing_since|lifecycle_0503|lifecycle_0506|lifecycle_0508",
    "reservations": "target_claims|cluster_reservations|expires_tick|reserved_by|reservation|reservations",
    "repair": "repair_executor_0516|dispatcher_repair_0516|repair_task|repair_target",
    "consecration": "consecration_0515|consecration_task|sanctify|target_claims",
    "combat": "combat_target|combat_repair|combat_repair_doctrine_0517|cluster_reservations",
    "construction": "construction_task|build_target",
    "logistics": "logistic_requested_item|machine_logistics_0528|logistics_fetch_0527",
}

STATUS_WORDS = [
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
class Site:
    path: str
    line: int
    group: str
    field: str
    kind: str
    risk_hint: str
    source: str

def iter_lua(root: Path) -> Iterable[Path]:
    for path in root.rglob("*.lua"):
        if ".git" in path.parts or "__pycache__" in path.parts:
            continue
        yield path

def detect_sites(line: str) -> List[tuple[str, str, str]]:
    sites: List[tuple[str, str, str]] = []
    stripped = line.strip()
    lower = stripped.lower()

    for group, pattern in WATCH_FIELDS.items():
        for field in pattern.split("|"):
            if field not in stripped:
                continue
            esc = re.escape(field)
            if re.search(r"(?:\.|\b)" + esc + r"\s*=\s*nil\b", stripped):
                sites.append((group, field, "clear"))
            elif re.search(r"(?:\.|\b)" + esc + r"\s*=", stripped):
                sites.append((group, field, "assignment"))
            elif field in {"target_claims", "cluster_reservations", "reservation", "reservations"} and any(word in lower for word in ("release", "cleanup", "expire", "claim")):
                sites.append((group, field, "reservation-transition-reference"))

    if re.search(r"\.\s*status\s*=|\bstatus\s*=", stripped):
        for word in STATUS_WORDS:
            if word in stripped:
                sites.append(("status-transition", word, "status-assignment"))

    if re.search(r"\.\s*mode\s*=|\bmode\s*=", stripped):
        for word in STATUS_WORDS:
            if word in stripped:
                sites.append(("mode-transition", word, "mode-assignment"))

    if re.search(r"\.\s*(claim|release|cleanup_expired|is_claimed)\s*\(", stripped):
        sites.append(("reservations", "reservation-api-call", "reservation-api-call"))

    if any(word in lower for word in ("pause", "unpause", "resume")) and any(word in stripped for word in ("active_order_0469", "order_queue_0469", "paused", "paused_by_missing_priest")):
        sites.append(("pause-resume", "pause-resume", "pause-resume-reference"))

    dedup: List[tuple[str, str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for site in sites:
        if site not in seen:
            seen.add(site)
            dedup.append(site)
    return dedup

def risk_hint(group: str, field: str, kind: str, line: str) -> str:
    l = line.lower()
    if kind == "clear":
        return "cleanup/clear path"
    if kind in {"status-assignment", "mode-assignment"} and any(w in field for w in ("paused", "waiting", "travelling", "deferred", "moving")):
        return "wait/travel/pause state set"
    if group == "reservations" and "release" in l:
        return "reservation release path"
    if group == "reservations" and "claim" in l:
        return "reservation claim path"
    if group == "lifecycle-recall-missing" and kind == "assignment":
        return "lifecycle pressure set"
    if group == "movement" and kind == "assignment":
        return "movement state/request set"
    if group in {"direct-acquisition", "emergency-craft", "logistics", "construction"} and kind == "assignment":
        return "executor phase/task set"
    if group == "order-queue" and kind == "assignment":
        return "order queue state set"
    if group == "pause-resume":
        return "pause/resume transition"
    return "transition review"

def scan(root: Path) -> List[Site]:
    out: List[Site] = []
    for path in iter_lua(root):
        rel = path.relative_to(root).as_posix()
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for idx, line in enumerate(lines, start=1):
            for group, field, kind in detect_sites(line):
                out.append(Site(rel, idx, group, field, kind, risk_hint(group, field, kind, line), line.strip()))
    out.sort(key=lambda s: (s.group, s.path.lower(), s.line, s.field, s.kind))
    return out

def counts_by(sites: Sequence[Site], attr: str) -> Dict[str, int]:
    out: Dict[str, int] = {}
    for site in sites:
        key = getattr(site, attr)
        out[key] = out.get(key, 0) + 1
    return dict(sorted(out.items(), key=lambda kv: (-kv[1], kv[0)))

def markdown(root: Path, sites: Sequence[Site]) -> str:
    lines: List[str] = []
    lines.append("# Stage 5 Dead-End Transition Site Report")
    lines.append("")
    lines.append("Generated by `tools/audit_dead_end_transition_sites.py`.")
    lines.append("")
    lines.append(f"- Source root: `{root.as_posix()}`")
    lines.append(f"- Transition sites: `{len(sites)}`")
    lines.append("")
    for title, attr in (("Counts by group", "group"), ("Counts by kind", "kind"), ("Counts by risk hint", "risk_hint"), ("Counts by file", "path")):
        lines.append(f"## {title}")
        lines.append("")
        lines.append("| Value | Count |")
        lines.append("|---|---:|")
        for key, count in counts_by(sites, attr).items():
            lines.append(f"| `{key}` | {count} |")
        lines.append("")
    lines.append("## Sites")
    lines.append("")
    lines.append("| Group | Field | File | Line | Kind | Risk hint | Source |")
    lines.append("|---|---|---|---:|---|---|---|")
    for site in sites:
        src = site.source.replace("|", "\\|")
        lines.append(f"| `{site.group}` | `{site.field}` | `{site.path}` | {site.line} | `{site.kind}` | `{site.risk_hint}` | `{src}` |")
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("This second-pass report filters the broad Stage 5 field inventory down to likely state transition sites. It still does not prove bugs. Use it to manually pair wait-state setters with cleanup paths, claims with releases, and pause states with unpause paths.")
    lines.append("")
    return "\n".join(lines)

def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Audit dead-end transition sites")
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--markdown", default=str(MD))
    parser.add_argument("--json", default=str(JSON_OUT))
    args = parser.parse_args(argv)

    root = Path(args.root)
    if not root.exists():
        raise SystemExit(f"missing source root: {root}")

    sites = scan(root)
    md = Path(args.markdown)
    js = Path(args.json)
    md.parent.mkdir(parents=True, exist_ok=True)
    js.parent.mkdir(parents=True, exist_ok=True)

    md.write_text(markdown(root, sites), encoding="utf-8")
    js.write_text(json.dumps({
        "source_root": root.as_posix(),
        "total_sites": len(sites),
        "counts_by_group": counts_by(sites, "group"),
        "counts_by_kind": counts_by(sites, "kind"),
        "counts_by_risk_hint": counts_by(sites, "risk_hint"),
        "counts_by_file": counts_by(sites, "path"),
        "sites": [asdict(site) for site in sites],
    }, indent=2, sort_keys=True), encoding="utf-8")

    if len(sites) <= 0:
        raise SystemExit("transition scan produced zero sites; refusing silent empty report")

    print(f"Scanned {root}; transition sites={len(sites)}")
    print(f"Wrote {md}")
    print(f"Wrote {js}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
