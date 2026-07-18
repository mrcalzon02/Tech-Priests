#!/usr/bin/env python3
"""Static UPS and authority-surface audit for Tech Priests recovery.

This is a source-level regression gate, not runtime profiler evidence. It scans
periodic routes, risky entity scans, direct movement/command surfaces, and
shared pair-state rewrites. The recovery baseline is the last pre-recovery
whole-tree audit committed in docs/UPS_HOTSPOT_AUDIT_0743.md.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from collections import Counter
from dataclasses import asdict, dataclass

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "tech-priests_src"
BASELINE = {
    "periodic_route_count": 510,
    "frequent_route_count_le_30": 24,
    "active_frequent_route_count_le_30": 17,
    "scan_site_count": 127,
    "risky_scan_count": 68,
    "rewrite_site_count": 916,
    "direct-set-command": 72,
    "pair-mode-write": 352,
    "pair-target-write": 177,
}


@dataclass
class PeriodicRoute:
    path: str
    line: int
    kind: str
    interval: str
    numeric_interval: int | None
    name: str
    owner: str
    category: str
    budget: str
    priority: str


@dataclass
class ScanSite:
    path: str
    line: int
    risk: str
    snippet: str


@dataclass
class RewriteSite:
    path: str
    line: int
    kind: str
    text: str


def rel(path: pathlib.Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def compact(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip())


def iter_lua(root: pathlib.Path):
    for path in sorted(root.rglob("*.lua")):
        if ".git" not in path.parts and "__pycache__" not in path.parts:
            yield path


def block_from(lines: list[str], start: int, maximum: int = 24) -> str:
    out: list[str] = []
    balance = 0
    opened = False
    for index in range(start, min(len(lines), start + maximum)):
        line = lines[index]
        out.append(line.rstrip())
        balance += line.count("(") + line.count("{")
        balance -= line.count(")") + line.count("}")
        opened = opened or "(" in line or "{" in line
        if opened and index > start and balance <= 0:
            break
    return "\n".join(out)


def literal(block: str, field: str) -> str:
    for pattern in (
        rf"\b{re.escape(field)}\s*=\s*['\"]([^'\"]+)['\"]",
        rf"\b{re.escape(field)}\s*=\s*([A-Za-z0-9_\.]+)",
    ):
        match = re.search(pattern, block)
        if match:
            return match.group(1)
    return ""


def first_arg(line: str, call: str) -> str:
    position = line.find(call)
    if position < 0:
        return ""
    match = re.search(r"\(\s*([^,\)]+)", line[position + len(call) :])
    return compact(match.group(1)) if match else ""


def numeric_interval(value: str) -> int | None:
    value = compact(value)
    if re.fullmatch(r"\d+", value):
        return int(value)
    for pattern in (r"60\s*\*\s*(\d+)", r"(\d+)\s*\*\s*60"):
        match = re.fullmatch(pattern, value)
        if match:
            return 60 * int(match.group(1))
    return None


def scan_risk(block: str) -> str:
    flat = compact(block)
    if re.search(r"find_entities_filtered\s*\(\s*(filters|spec|opts)\s*\)", flat):
        return "dynamic-filter-helper"
    area = re.search(r"\barea\s*=", flat) is not None
    position_radius = (
        re.search(r"\bposition\s*=", flat) is not None
        and re.search(r"\bradius\s*=", flat) is not None
    )
    typed = re.search(r"\b(type|name)\s*=", flat) is not None
    forced = re.search(r"\bforce\s*=", flat) is not None
    limited = re.search(r"\blimit\s*=", flat) is not None
    bounded = area or position_radius
    if bounded and not (typed or forced):
        return "broad-area"
    if bounded and forced and not typed and not limited:
        return "wide-force-area"
    if bounded and not limited:
        return "unbounded-filtered"
    if not bounded and (typed or forced) and not limited:
        return "global-filtered"
    if not bounded and not limited:
        return "global-or-unbounded"
    return "bounded-or-filtered"


def audit_file(path: pathlib.Path):
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    routes: list[PeriodicRoute] = []
    scans: list[ScanSite] = []
    rewrites: list[RewriteSite] = []
    rpath = rel(path)
    rewrite_patterns = {
        "direct-set-command": r"\bset_command\s*\(",
        "movement-request": r"tech_priests_request_movement_0418\s*\(",
        "route-command": r"\broute_command\s*\(",
        "movement-request-state": r"\brequests\s*\[",
        "pair-mode-write": r"\bpair\.mode\s*=",
        "pair-target-write": r"\bpair\.target\s*=",
        "leaf-task-write": r"\bactive_leaf_task_0655\s*=",
        "actual-task-status-write": r"\bactual_task_status_0655\s*=",
        "movement-request-write": r"\bmovement_request_0418\s*=",
        "active-order-write": r"\bactive_order_",
        "direct-task-write": r"\bdirect_acquisition_task_",
        "emergency-craft-write": r"\bemergency_craft\s*=",
        "logistics-fetch-write": r"\blogistics_fetch_0527\s*=",
    }
    for index, raw in enumerate(lines):
        line = raw.strip()
        if line.startswith("--"):
            continue
        if "register_service" in line:
            block = block_from(lines, index)
            interval = literal(block, "interval")
            routes.append(
                PeriodicRoute(
                    rpath,
                    index + 1,
                    "broker",
                    interval or "?",
                    numeric_interval(interval),
                    literal(block, "name"),
                    "",
                    literal(block, "category"),
                    literal(block, "budget"),
                    literal(block, "priority"),
                )
            )
        if "on_nth_tick" in line:
            block = block_from(lines, index)
            if "script.on_nth_tick" in line:
                preceding = "\n".join(lines[max(0, index - 3) : index + 1])
                kind = "script-fallback" if re.search(r"\b(elseif|else)\b", preceding) else "script"
            else:
                kind = "registry"
            interval = first_arg(line, "on_nth_tick")
            routes.append(
                PeriodicRoute(
                    rpath,
                    index + 1,
                    kind,
                    interval or "?",
                    numeric_interval(interval),
                    "",
                    literal(block, "owner"),
                    literal(block, "category"),
                    "",
                    literal(block, "priority"),
                )
            )
        if "find_entities_filtered" in line:
            block = block_from(lines, index)
            scans.append(ScanSite(rpath, index + 1, scan_risk(block), compact(block)[:240]))
        for kind, pattern in rewrite_patterns.items():
            if re.search(pattern, line):
                rewrites.append(RewriteSite(rpath, index + 1, kind, compact(line)[:220]))
    return routes, scans, rewrites


def audit(root: pathlib.Path) -> dict[str, object]:
    routes: list[PeriodicRoute] = []
    scans: list[ScanSite] = []
    rewrites: list[RewriteSite] = []
    files = list(iter_lua(root))
    for path in files:
        file_routes, file_scans, file_rewrites = audit_file(path)
        routes.extend(file_routes)
        scans.extend(file_scans)
        rewrites.extend(file_rewrites)
    route_kinds = Counter(route.kind for route in routes)
    scan_risks = Counter(scan.risk for scan in scans)
    rewrite_kinds = Counter(site.kind for site in rewrites)
    rewrite_files = Counter(site.path for site in rewrites)
    frequent = [
        route
        for route in routes
        if route.numeric_interval is not None and route.numeric_interval <= 30
    ]
    active_frequent = [route for route in frequent if route.kind != "script-fallback"]
    risky_scans = [
        scan
        for scan in scans
        if scan.risk not in {"bounded-or-filtered", "dynamic-filter-helper"}
    ]
    summary = {
        "periodic_route_count": len(routes),
        "route_kinds": dict(route_kinds),
        "frequent_route_count_le_30": len(frequent),
        "active_frequent_route_count_le_30": len(active_frequent),
        "scan_site_count": len(scans),
        "scan_risks": dict(scan_risks),
        "risky_scan_count": len(risky_scans),
        "rewrite_site_count": len(rewrites),
        "rewrite_kinds": dict(rewrite_kinds),
        "top_rewrite_files": dict(rewrite_files.most_common(20)),
    }
    comparisons: dict[str, dict[str, int | str]] = {}
    for key, baseline in BASELINE.items():
        current = (
            int(rewrite_kinds.get(key, 0))
            if key in rewrite_kinds or key in {"direct-set-command", "pair-mode-write", "pair-target-write"}
            else int(summary.get(key, 0))
        )
        comparisons[key] = {
            "baseline": baseline,
            "current": current,
            "delta": current - baseline,
            "status": "improved" if current < baseline else "unchanged" if current == baseline else "regressed",
        }
    return {
        "source_root": rel(root),
        "files_scanned": len(files),
        "baseline": BASELINE,
        "comparisons": comparisons,
        "summary": summary,
        "periodic_routes": [asdict(route) for route in routes],
        "scan_sites": [asdict(scan) for scan in scans],
        "rewrite_sites": [asdict(site) for site in rewrites],
        "frequent_routes": [asdict(route) for route in sorted(frequent, key=lambda r: (r.numeric_interval or 999999, r.path, r.line))],
        "active_frequent_routes": [asdict(route) for route in sorted(active_frequent, key=lambda r: (r.numeric_interval or 999999, r.path, r.line))],
        "risky_scans": [asdict(scan) for scan in sorted(risky_scans, key=lambda s: (s.risk, s.path, s.line))],
    }


def table(headers: list[str], rows: list[list[object]]) -> list[str]:
    lines = ["| " + " | ".join(headers) + " |", "| " + " | ".join("---" for _ in headers) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(str(value).replace("|", "\\|") for value in row) + " |")
    return lines


def write_markdown(report: dict[str, object], path: pathlib.Path) -> None:
    summary = report["summary"]
    comparisons = report["comparisons"]
    assert isinstance(summary, dict) and isinstance(comparisons, dict)
    lines = [
        "# UPS Hotspot Audit 0743",
        "",
        "**Status:** static recovery regression audit; clean-world profiler evidence remains required",
        "",
        "## Recovery Baseline Comparison",
        "",
    ]
    lines.extend(
        table(
            ["metric", "baseline", "current", "delta", "status"],
            [
                [key, value["baseline"], value["current"], value["delta"], value["status"]]
                for key, value in comparisons.items()
            ],
        )
    )
    lines += ["", "## Current Summary", ""]
    for key in (
        "periodic_route_count",
        "frequent_route_count_le_30",
        "active_frequent_route_count_le_30",
        "scan_site_count",
        "risky_scan_count",
        "rewrite_site_count",
    ):
        lines.append(f"- `{key}`: {summary.get(key)}")
    lines += ["", "## Frequent Wake Routes", ""]
    lines.extend(
        table(
            ["interval", "kind", "authority", "category", "site"],
            [
                [route["interval"], route["kind"], route["name"] or route["owner"] or "?", route["category"] or "?", f"{route['path']}:{route['line']}"]
                for route in report["active_frequent_routes"][:50]
            ],
        )
    )
    lines += ["", "## Risky Scan Sites", ""]
    lines.extend(
        table(
            ["risk", "site", "snippet"],
            [[scan["risk"], f"{scan['path']}:{scan['line']}", scan["snippet"]] for scan in report["risky_scans"][:60]],
        )
    )
    lines += [
        "",
        "## Interpretation",
        "",
        "- A source-count improvement is evidence of graph simplification, not proof of runtime speed.",
        "- Any regression above the frozen baseline fails `--check-baseline`.",
        "- Clean-world profiler and high-count scenarios remain mandatory before performance acceptance.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(DEFAULT_SOURCE))
    parser.add_argument("--json")
    parser.add_argument("--markdown")
    parser.add_argument("--print-summary", action="store_true")
    parser.add_argument("--check-baseline", action="store_true")
    args = parser.parse_args(argv)
    source = pathlib.Path(args.root)
    if not source.is_absolute():
        source = ROOT / source
    report = audit(source)
    if args.json:
        output = pathlib.Path(args.json)
        if not output.is_absolute():
            output = ROOT / output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if args.markdown:
        output = pathlib.Path(args.markdown)
        if not output.is_absolute():
            output = ROOT / output
        output.parent.mkdir(parents=True, exist_ok=True)
        write_markdown(report, output)
    summary = report["summary"]
    comparisons = report["comparisons"]
    if args.print_summary or not (args.json or args.markdown):
        print("UPS hotspot audit 0743 recovery comparison")
        print(f"files_scanned={report['files_scanned']}")
        for key, value in comparisons.items():
            print(f"{key}: baseline={value['baseline']} current={value['current']} delta={value['delta']} status={value['status']}")
        print("scan_risks=" + json.dumps(summary.get("scan_risks", {}), sort_keys=True))
        print("rewrite_kinds=" + json.dumps(summary.get("rewrite_kinds", {}), sort_keys=True))
    regressions = [key for key, value in comparisons.items() if value["current"] > value["baseline"]]
    if args.check_baseline and regressions:
        print("UPS recovery baseline check failed:", file=sys.stderr)
        for key in regressions:
            value = comparisons[key]
            print(f"  - {key}: {value['current']} > {value['baseline']} (+{value['delta']})", file=sys.stderr)
        return 1
    if args.check_baseline:
        print("UPS recovery baseline check passed; no tracked source metric regressed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
