#!/usr/bin/env python3
from __future__ import annotations

import argparse, json, re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence

ROOT = Path("tech-priests_src")
MD = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_TRANSITION_SITES.md")
JSON_OUT = Path("tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_TRANSITION_SITES.json")

FIELDS: Dict[str, Sequence[str]] = {
    "mode": ("mode",),
    "active-task": ("active_task", "active_task_0285", "active_order_0469", "dispatcher_action", "dispatcher_phase"),
    "order-queue": ("order_queue_0469", "pending_keys", "paused_tick", "pause_reason", "status", "current", "pending"),
    "direct-acquisition": ("direct_acquisition_task_0336", "active_acquisition_0333", "dispatcher_direct_0513", "direct_due_tick_0273", "direct_due_tick_0312", "direct_due_tick_0315", "direct_due_tick_0336", "next_direct_laser_tick_0315", "direct_last_visual_tick_0306"),
    "emergency-craft": ("emergency_craft", "station_crafting_task_0337", "active_craft_0479", "dispatcher_emergency_production_0514"),
    "movement": ("movement_request_0418", "movement_controller_state_0418", "movement_controller_reason_0418", "movement_lease", "movement_owner", "movement_request", "movement_target"),
    "lifecycle-recall-missing": ("recalling", "pending_recall", "force_recall", "recall_requested", "stuck_since", "last_stuck_tick", "stuck_recall_pending", "lost_priest_0490", "missing_priest_rescue_0490", "paused_by_missing_priest_0498", "paused_by_missing_priest_0500", "missing_since", "lifecycle_0503", "lifecycle_0506", "lifecycle_0508"),
    "reservations": ("target_claims", "cluster_reservations", "expires_tick", "reserved_by", "reservation", "reservations"),
    "repair": ("repair_executor_0516", "dispatcher_repair_0516", "repair_task", "repair_target"),
    "consecration": ("consecration_0515", "consecration_task", "sanctify", "target_claims"),
    "combat": ("combat_target", "combat_repair", "combat_repair_doctrine_0517", "cluster_reservations"),
    "construction": ("construction_task", "build_target"),
    "logistics": ("logistic_requested_item", "machine_logistics_0528", "logistics_fetch_0527"),
}

STATUS_WORDS = ("paused-missing-priest", "travelling-to-direct-acquisition", "travelling-to-dirt-scrape", "waiting-known-source-fetch", "move-to-storage", "move-to-machine", "moving-to-construction-source", "deferred-missing-station-item", "complete", "cancelled", "expired", "active", "pending", "paused", "failed")

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
    yield from (p for p in root.rglob("*.lua") if ".git" not in p.parts and "__pycache__" not in p.parts)


def detect(line: str) -> List[tuple[str, str, str]]:
    out: List[tuple[str, str, str]] = []
    text = line.strip()
    low = text.lower()
    for group, fields in FIELDS.items():
        for field in fields:
            if field not in text:
                continue
            esc = re.escape(field)
            if re.search(r"(?:\.|\b)" + esc + r"\s*=\s*nil\b", text):
                out.append((group, field, "clear"))
            elif re.search(r"(?:\.|\b)" + esc + r"\s*=", text):
                out.append((group, field, "assignment"))
            elif group == "reservations" and any(w in low for w in ("release", "cleanup", "expire", "claim")):
                out.append((group, field, "reservation-transition-reference"))
    if re.search(r"\.\s*status\s*=|\bstatus\s*=", text):
        out += [("status-transition", w, "status-assignment") for w in STATUS_WORDS if w in text]
    if re.search(r"\.\s*mode\s*=|\bmode\s*=", text):
        out += [("mode-transition", w, "mode-assignment") for w in STATUS_WORDS if w in text]
    if re.search(r"\.\s*(claim|release|cleanup_expired|is_claimed)\s*\(", text):
        out.append(("reservations", "reservation-api-call", "reservation-api-call"))
    if any(w in low for w in ("pause", "unpause", "resume")) and any(w in text for w in ("active_order_0469", "order_queue_0469", "paused", "paused_by_missing_priest")):
        out.append(("pause-resume", "pause-resume", "pause-resume-reference"))
    seen, dedup = set(), []
    for item in out:
        if item not in seen:
            seen.add(item); dedup.append(item)
    return dedup


def hint(group: str, field: str, kind: str, source: str) -> str:
    low = source.lower()
    if kind == "clear": return "cleanup/clear path"
    if kind in ("status-assignment", "mode-assignment") and any(w in field for w in ("paused", "waiting", "travelling", "deferred", "moving")): return "wait/travel/pause state set"
    if group == "reservations" and "release" in low: return "reservation release path"
    if group == "reservations" and "claim" in low: return "reservation claim path"
    if group == "lifecycle-recall-missing" and kind == "assignment": return "lifecycle pressure set"
    if group == "movement" and kind == "assignment": return "movement state/request set"
    if group in ("direct-acquisition", "emergency-craft", "logistics", "construction") and kind == "assignment": return "executor phase/task set"
    if group == "order-queue" and kind == "assignment": return "order queue state set"
    if group == "pause-resume": return "pause/resume transition"
    return "transition review"


def scan(root: Path) -> List[Site]:
    hits: List[Site] = []
    for path in iter_lua(root):
        rel = path.relative_to(root).as_posix()
        for num, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            for group, field, kind in detect(line):
                hits.append(Site(rel, num, group, field, kind, hint(group, field, kind, line), line.strip()))
    return sorted(hits, key=lambda s: (s.group, s.path.lower(), s.line, s.field, s.kind))


def counts_by(sites: Sequence[Site], attr: str) -> Dict[str, int]:
    counts: Dict[str, int] = {}
    for site in sites:
        key = str(getattr(site, attr))
        counts[key] = counts.get(key, 0) + 1
    return dict(sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])))


def make_md(root: Path, sites: Sequence[Site]) -> str:
    lines = ["# Stage 5 Dead-End Transition Site Report", "", "Generated by `tools/audit_dead_end_transition_sites_v2.py`.", "", f"- Source root: `{root.as_posix()}`", f"- Transition sites: `{len(sites)}`", ""]
    for title, attr in (("Counts by group", "group"), ("Counts by kind", "kind"), ("Counts by risk hint", "risk_hint"), ("Counts by file", "path")):
        lines += [f"## {title}", "", "| Value | Count |", "|---|---:|"]
        lines += [f"| `{k}` | {v} |" for k, v in counts_by(sites, attr).items()]
        lines.append("")
    lines += ["## Sites", "", "| Group | Field | File | Line | Kind | Risk hint | Source |", "|---|---|---|---:|---|---|---|"]
    for site in sites:
        src = site.source.replace("|", "\\|")
        lines.append(f"| `{site.group}` | `{site.field}` | `{site.path}` | {site.line} | `{site.kind}` | `{site.risk_hint}` | `{src}` |")
    lines += ["", "## Notes", "", "This second-pass report filters the broad Stage 5 field inventory down to likely state transition sites. It still does not prove bugs. Use it to manually pair wait-state setters with cleanup paths, claims with releases, and pause states with unpause paths.", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--markdown", default=str(MD))
    parser.add_argument("--json", default=str(JSON_OUT))
    args = parser.parse_args()
    root = Path(args.root)
    if not root.exists():
        raise SystemExit(f"missing source root: {root}")
    sites = scan(root)
    if not sites:
        raise SystemExit("transition scan produced zero sites; refusing silent empty report")
    md, js = Path(args.markdown), Path(args.json)
    md.parent.mkdir(parents=True, exist_ok=True); js.parent.mkdir(parents=True, exist_ok=True)
    md.write_text(make_md(root, sites), encoding="utf-8")
    js.write_text(json.dumps({"source_root": root.as_posix(), "total_sites": len(sites), "counts_by_group": counts_by(sites, "group"), "counts_by_kind": counts_by(sites, "kind"), "counts_by_risk_hint": counts_by(sites, "risk_hint"), "counts_by_file": counts_by(sites, "path"), "sites": [asdict(s) for s in sites]}, indent=2, sort_keys=True), encoding="utf-8")
    print(f"Scanned {root}; transition sites={len(sites)}")
    print(f"Wrote {md}")
    print(f"Wrote {js}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
