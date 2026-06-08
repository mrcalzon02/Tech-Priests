#!/usr/bin/env python3
"""
Scan the Tech Priests source tree for Factorio event/tick authority patterns.

Run from the repository root:

    python tools/audit_event_authority.py

Optional:

    python tools/audit_event_authority.py --root tech-priests_src --markdown tech-priests_src/docs/CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.md --json tech-priests_src/docs/CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.json

This tool is intentionally read-only. It does not edit Lua files and does not
attempt to decide final architecture. It creates an inventory so Stage 2 can
classify direct event/tick registration, registry ownership, broker service
registration, and fallback patterns from source rather than memory.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


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

GUI_HINTS = (
    "on_gui_",
    "gui_",
    "/gui/",
    "gui.lua",
    "history_gui",
    "workstate_gui",
    "station_work_inventory",
    "station_catalog",
    "task_auspex",
    "conclave_center",
    "doctrine_argument",
)

BEHAVIOR_CRITICAL_HINTS = (
    "movement",
    "dispatcher",
    "order_queue",
    "scheduler",
    "acquisition",
    "crafting_executor",
    "construction",
    "combat",
    "emergency",
    "lifecycle",
    "vanish",
    "recovery",
    "direct_mining",
    "mobility",
    "authority_corridor",
    "behavior_",
    "task_lifecycle",
    "task_pair",
    "action_state",
    "command_hierarchy",
    "magos_planning",
    "inventory_steward",
)

PRESENTATION_HINTS = (
    "chatter",
    "sound",
    "voice",
    "visual",
    "overlay",
    "status",
    "portrait",
    "placeholder_audio",
    "network_visuals",
    "doctrine_argument",
)

ECONOMY_HINTS = (
    "efficiency_economy",
    "cache",
    "dirty",
    "prune",
    "cleanup",
    "housekeeping",
)

CONFIG_PROFILER_HINTS = (
    "runtime_config",
    "profiler",
    "runtime_mod_setting_changed",
    "setting_changed",
    "diagnostics",
    "runtime-report",
)

BOOTSTRAP_HINTS = (
    "bootstrap_runtime",
    "generated/control_legacy",
)

STARTUP_HINTS = (
    "startup_provisioning",
    "on_player_created",
    "on_player_joined_game",
    "on_init",
    "on_configuration_changed",
)


@dataclass
class Hit:
    path: str
    line: int
    kind: str
    text: str
    context_before: List[str] = field(default_factory=list)
    context_after: List[str] = field(default_factory=list)
    provisional_classification: str = "unclassified"
    risk_group: str = "uncategorized"
    recommended_action: str = "manual review"


def iter_lua_files(root: Path) -> Iterable[Path]:
    ignore_dirs = {".git", "__pycache__", ".venv", "venv", "node_modules"}
    for path in root.rglob("*.lua"):
        if any(part in ignore_dirs for part in path.parts):
            continue
        yield path


def contains_any(text: str, needles: Sequence[str]) -> bool:
    return any(n in text for n in needles)


def normalized_path(path: str) -> str:
    return path.replace("\\", "/").lower()


def classify_family(path: str, kind: str, blob: str) -> str:
    p = normalized_path(path)
    combined = f"{p}\n{blob}"

    if contains_any(combined, BOOTSTRAP_HINTS):
        return "legacy-bootstrap"
    if contains_any(combined, GUI_HINTS):
        return "gui"
    if contains_any(combined, CONFIG_PROFILER_HINTS):
        return "config-profiler-telemetry"
    if contains_any(combined, BEHAVIOR_CRITICAL_HINTS):
        return "behavior-critical"
    if contains_any(combined, PRESENTATION_HINTS):
        return "presentation-diagnostic"
    if contains_any(combined, ECONOMY_HINTS):
        return "economy-housekeeping"
    if contains_any(combined, STARTUP_HINTS):
        return "startup-lifecycle"
    if kind in REGISTRY_KINDS:
        return "registry"
    if kind == "broker_register_service":
        return "broker-service"
    return "uncategorized"


def detect_fallback_shape(blob: str) -> Optional[str]:
    b = blob.lower()
    has_direct = "script.on_event" in b or "script.on_nth_tick" in b or "script.on_init" in b or "script.on_configuration_changed" in b
    if not has_direct:
        return None

    broker_words = ("runtime_tick_broker", "techpriestsruntimetickbroker", "register_service")
    registry_words = ("runtime_event_registry", "techpriestsruntimeeventregistry", ".on_event", ".on_nth_tick")
    require_registry = "require" in b and "scripts.core.runtime_event_registry" in b
    require_broker = "require" in b and "scripts.core.runtime_tick_broker" in b

    if any(w in b for w in broker_words) and any(w in b for w in registry_words):
        return "broker-registry-direct-fallback"
    if any(w in b for w in broker_words):
        return "broker-first-direct-fallback"
    if require_registry:
        return "require-registry-direct-fallback"
    if any(w in b for w in registry_words):
        return "registry-first-direct-fallback"
    if "fallback" in b or "unavailable" in b or "else" in b or "elseif" in b:
        return "direct-compatibility-fallback"
    return None


def recommendation_for(classification: str, risk_group: str, kind: str) -> str:
    if classification == "canonical-registry-internal":
        return "leave alone; this is the central dispatcher surface"
    if classification == "early-raw-nth-tick-monkeypatch":
        return "leave until all raw nth-tick routes are migrated or proven safe"
    if classification in {"registry-owned", "broker-service-registration"}:
        return "preserve metadata; not a direct registration problem"
    if "fallback" in classification:
        if risk_group == "behavior-critical":
            return "do not migrate first; verify owner in Stage 3/4 before changing"
        return "consider require-first hardening; keep direct fallback as last resort"
    if classification == "raw-direct-gui-owner":
        return "map through gui_router/gui_bus; avoid double-dispatch"
    if classification == "raw-direct-behavior-critical-timing":
        return "hold for Stage 3/4 ownership audit; behavior-critical"
    if classification == "raw-direct-presentation-diagnostic-timing":
        return "later broker migration candidate"
    if classification == "raw-direct-economy-housekeeping":
        return "later broker migration candidate; preserve cadence/budget semantics"
    if classification == "raw-direct-config-profiler-route":
        return "prefer registry require-first fallback; low behavior risk"
    if classification == "raw-direct-legacy-bootstrap":
        return "document order requirements before migration"
    if classification == "registry-global-reference":
        return "check whether require-first discovery is needed"
    if kind in DIRECT_KINDS:
        return "manual review; classify owner and migration risk"
    return "manual review"


def classify_hit(path: str, kind: str, text: str, before: List[str], after: List[str]) -> Tuple[str, str, str]:
    blob = "\n".join(before + [text] + after).lower()
    p = normalized_path(path)
    risk_group = classify_family(path, kind, blob)

    if p.endswith("scripts/core/runtime_event_registry.lua") and kind in DIRECT_KINDS:
        classification = "canonical-registry-internal"
    elif p.endswith("scripts/core/efficiency_economy_0596.lua") and kind == "direct_script_on_nth_tick":
        classification = "early-raw-nth-tick-monkeypatch"
    elif kind in REGISTRY_KINDS:
        classification = "registry-owned"
    elif kind == "broker_register_service":
        classification = "broker-service-registration"
    elif kind == "registry_global_read":
        classification = "registry-global-reference"
    elif kind == "registry_require":
        classification = "registry-require"
    elif kind == "tick_broker_require":
        classification = "tick-broker-require"
    elif kind in DIRECT_KINDS:
        fallback = detect_fallback_shape(blob)
        if fallback:
            classification = fallback
        elif risk_group == "gui":
            classification = "raw-direct-gui-owner"
        elif risk_group == "behavior-critical":
            classification = "raw-direct-behavior-critical-timing"
        elif risk_group == "presentation-diagnostic":
            classification = "raw-direct-presentation-diagnostic-timing"
        elif risk_group == "economy-housekeeping":
            classification = "raw-direct-economy-housekeeping"
        elif risk_group == "config-profiler-telemetry":
            classification = "raw-direct-config-profiler-route"
        elif risk_group == "legacy-bootstrap":
            classification = "raw-direct-legacy-bootstrap"
        elif risk_group == "startup-lifecycle":
            classification = "raw-direct-startup-lifecycle"
        else:
            classification = "direct-registration-review-required"
    else:
        classification = "unclassified"

    return classification, risk_group, recommendation_for(classification, risk_group, kind)


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
                classification, risk_group, recommendation = classify_hit(rel, kind, line, before, after)
                hits.append(Hit(
                    path=rel,
                    line=index,
                    kind=kind,
                    text=line.strip(),
                    context_before=[s.rstrip() for s in before],
                    context_after=[s.rstrip() for s in after],
                    provisional_classification=classification,
                    risk_group=risk_group,
                    recommended_action=recommendation,
                ))
    return hits


def scan(root: Path, context: int) -> List[Hit]:
    hits: List[Hit] = []
    for path in iter_lua_files(root):
        hits.extend(scan_file(path, root, context))
    hits.sort(key=lambda h: (h.path.lower(), h.line, h.kind))
    return hits


def counts_by(items: Iterable[Hit], attr: str) -> Dict[str, int]:
    counts: Dict[str, int] = {}
    for item in items:
        key = getattr(item, attr)
        counts[key] = counts.get(key, 0) + 1
    return dict(sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])))


def markdown_count_table(title: str, counts: Dict[str, int]) -> List[str]:
    lines = [title, "", "| Value | Count |", "|---|---:|"]
    for key, count in counts.items():
        lines.append(f"| `{key}` | {count} |")
    lines.append("")
    return lines


def markdown_hit_table(title: str, hits: List[Hit], include_recommendation: bool = True) -> List[str]:
    lines = [title, ""]
    if not hits:
        lines.append("No hits found.")
        lines.append("")
        return lines
    if include_recommendation:
        lines.append("| File | Line | Kind | Classification | Risk group | Recommended action | Source |")
        lines.append("|---|---:|---|---|---|---|---|")
        for h in hits:
            source = h.text.replace("|", "\\|")
            rec = h.recommended_action.replace("|", "\\|")
            lines.append(f"| `{h.path}` | {h.line} | `{h.kind}` | `{h.provisional_classification}` | `{h.risk_group}` | {rec} | `{source}` |")
    else:
        lines.append("| File | Line | Kind | Classification | Risk group | Source |")
        lines.append("|---|---:|---|---|---|---|")
        for h in hits:
            source = h.text.replace("|", "\\|")
            lines.append(f"| `{h.path}` | {h.line} | `{h.kind}` | `{h.provisional_classification}` | `{h.risk_group}` | `{source}` |")
    lines.append("")
    return lines


def markdown_report(root: Path, hits: List[Hit]) -> str:
    direct = [h for h in hits if h.kind in DIRECT_KINDS]
    registry = [h for h in hits if h.kind in REGISTRY_KINDS]
    true_raw = [h for h in direct if h.provisional_classification.startswith("raw-direct") or h.provisional_classification == "direct-registration-review-required"]
    fallback = [h for h in direct if "fallback" in h.provisional_classification]
    gui = [h for h in direct if h.risk_group == "gui"]
    behavior = [h for h in direct if h.risk_group == "behavior-critical"]

    lines: List[str] = []
    lines.append("# Stage 2 Event Authority Scanner Report")
    lines.append("")
    lines.append("Generated by `tools/audit_event_authority.py`.")
    lines.append("")
    lines.append(f"- Source root: `{root.as_posix()}`")
    lines.append(f"- Total hits: `{len(hits)}`")
    lines.append(f"- Direct `script.*` registration hits: `{len(direct)}`")
    lines.append(f"- Registry route hits: `{len(registry)}`")
    lines.append(f"- Direct fallback-shaped hits: `{len(fallback)}`")
    lines.append(f"- True/raw direct review hits: `{len(true_raw)}`")
    lines.append(f"- Direct GUI-family hits: `{len(gui)}`")
    lines.append(f"- Direct behavior-critical-family hits: `{len(behavior)}`")
    lines.append("")

    lines.extend(markdown_count_table("## Counts by kind", counts_by(hits, "kind")))
    lines.extend(markdown_count_table("## Counts by provisional classification", counts_by(hits, "provisional_classification")))
    lines.extend(markdown_count_table("## Counts by risk group", counts_by(hits, "risk_group")))

    lines.extend(markdown_hit_table("## Direct registration hits", direct))
    lines.extend(markdown_hit_table("## True/raw direct review shortlist", true_raw))
    lines.extend(markdown_hit_table("## Direct fallback-shaped hits", fallback))

    other = [h for h in hits if h.kind not in DIRECT_KINDS]
    lines.extend(markdown_hit_table("## Registry/broker/global hits", other, include_recommendation=False))

    lines.append("## Notes")
    lines.append("")
    lines.append("This scanner is still conservative, but it now attempts to separate direct fallback branches from true raw direct registrations and groups hits by likely risk family. The classification is an audit aid, not final architectural truth. Behavior-critical timing routes should still wait for Stage 3/4 ownership confirmation before code migration.")
    lines.append("")
    return "\n".join(lines)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Audit Tech Priests event/tick authority patterns.")
    parser.add_argument("--root", default=None, help="Source root to scan. Defaults to tech-priests_src if present, else current directory.")
    parser.add_argument("--markdown", default="tech-priests_src/docs/CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.md", help="Markdown report output path.")
    parser.add_argument("--json", default="tech-priests_src/docs/CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.json", help="JSON report output path.")
    parser.add_argument("--context", type=int, default=8, help="Context lines to store in JSON around each hit and use for fallback classification.")
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
        "counts_by_risk_group": counts_by(hits, "risk_group"),
        "hits": [asdict(h) for h in hits],
    }, indent=2, sort_keys=True), encoding="utf-8")

    direct_count = sum(1 for h in hits if h.kind in DIRECT_KINDS)
    fallback_count = sum(1 for h in hits if h.kind in DIRECT_KINDS and "fallback" in h.provisional_classification)
    raw_count = sum(1 for h in hits if h.kind in DIRECT_KINDS and (h.provisional_classification.startswith("raw-direct") or h.provisional_classification == "direct-registration-review-required"))
    print(f"Scanned {root}; hits={len(hits)} direct={direct_count} fallback={fallback_count} raw_review={raw_count}")
    print(f"Wrote {md_path}")
    print(f"Wrote {json_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
