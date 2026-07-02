#!/usr/bin/env python3
"""Static UPS hotspot audit for Tech Priests runtime authorities.

This is a source-level triage tool. It does not prove runtime cost; it catalogs
authorities that deserve attention in a clean-world profiler pass:

* periodic wake routes and their apparent cadence/budget,
* broad `find_entities_filtered` calls,
* movement command/request surfaces,
* pair task/status rewrite surfaces.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "tech-priests_src"


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
    snippet: str
    has_area: bool
    has_position_radius: bool
    has_type: bool
    has_name: bool
    has_force: bool
    has_limit: bool
    risk: str


@dataclass
class RewriteSite:
    path: str
    line: int
    kind: str
    text: str


def iter_lua(root: Path) -> Iterable[Path]:
    for path in sorted(root.rglob("*.lua")):
        parts = set(path.parts)
        if ".git" in parts or "__pycache__" in parts:
            continue
        yield path


def rel(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def compact(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip())


def block_from(lines: list[str], start: int, max_lines: int = 18) -> str:
    out: list[str] = []
    balance = 0
    seen_paren = False
    for idx in range(start, min(len(lines), start + max_lines)):
        line = lines[idx]
        out.append(line.rstrip())
        balance += line.count("(") + line.count("{")
        balance -= line.count(")") + line.count("}")
        if "(" in line:
            seen_paren = True
        if seen_paren and idx > start and balance <= 0:
            break
    return "\n".join(out)


def literal_field(block: str, field: str) -> str:
    patterns = [
        rf"\b{re.escape(field)}\s*=\s*['\"]([^'\"]+)['\"]",
        rf"\b{re.escape(field)}\s*=\s*([A-Za-z0-9_\.]+)",
    ]
    for pattern in patterns:
        match = re.search(pattern, block)
        if match:
            return match.group(1)
    return ""


def first_arg_after_call(line: str, call: str) -> str:
    pos = line.find(call)
    if pos < 0:
        return ""
    tail = line[pos + len(call) :]
    match = re.search(r"\(\s*([^,\)]+)", tail)
    return compact(match.group(1)) if match else ""


def numeric_interval(value: str) -> int | None:
    value = compact(value)
    if re.fullmatch(r"\d+", value):
        return int(value)
    match = re.fullmatch(r"60\s*\*\s*(\d+)", value)
    if match:
        return 60 * int(match.group(1))
    match = re.fullmatch(r"(\d+)\s*\*\s*60", value)
    if match:
        return int(match.group(1)) * 60
    return None


def classify_scan(block: str) -> tuple[bool, bool, bool, bool, bool, bool, str]:
    flat = compact(block)
    if re.search(r"find_entities_filtered\s*\(\s*(filters|spec|opts)\s*\)", flat):
        return False, False, False, False, False, False, "dynamic-filter-helper"
    has_area = re.search(r"\barea\s*=", flat) is not None
    has_position = re.search(r"\bposition\s*=", flat) is not None
    has_radius = re.search(r"\bradius\s*=", flat) is not None
    has_position_radius = has_position and has_radius
    has_type = re.search(r"\btype\s*=", flat) is not None
    has_name = re.search(r"\bname\s*=", flat) is not None
    has_force = re.search(r"\bforce\s*=", flat) is not None
    has_limit = re.search(r"\blimit\s*=", flat) is not None
    if (has_area or has_position_radius) and not (has_type or has_name or has_force):
        risk = "broad-area"
    elif (has_area or has_position_radius) and not has_limit and not (has_type or has_name):
        risk = "wide-force-area"
    elif (has_area or has_position_radius) and not has_limit:
        risk = "unbounded-filtered"
    elif not (has_area or has_position_radius) and (has_type or has_name or has_force) and not has_limit:
        risk = "global-filtered"
    elif not (has_area or has_position_radius) and not has_limit:
        risk = "global-or-unbounded"
    else:
        risk = "bounded-or-filtered"
    return has_area, has_position_radius, has_type, has_name, has_force, has_limit, risk


def audit_file(path: Path) -> tuple[list[PeriodicRoute], list[ScanSite], list[RewriteSite]]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    routes: list[PeriodicRoute] = []
    scans: list[ScanSite] = []
    rewrites: list[RewriteSite] = []
    rpath = rel(path)

    for idx, line in enumerate(lines):
        stripped = line.strip()
        block = ""

        if "register_service" in stripped:
            block = block_from(lines, idx)
            interval = literal_field(block, "interval")
            routes.append(
                PeriodicRoute(
                    path=rpath,
                    line=idx + 1,
                    kind="broker",
                    interval=interval or "?",
                    numeric_interval=numeric_interval(interval),
                    name=literal_field(block, "name"),
                    owner="",
                    category=literal_field(block, "category"),
                    budget=literal_field(block, "budget"),
                    priority=literal_field(block, "priority"),
                )
            )

        if "on_nth_tick" in stripped:
            block = block or block_from(lines, idx)
            if "script.on_nth_tick" in stripped:
                prev = "\n".join(lines[max(0, idx - 3):idx + 1])
                call_kind = "script-fallback" if re.search(r"\belseif\b|\belse\b", prev) else "script"
            else:
                call_kind = "registry"
            interval = first_arg_after_call(stripped, "on_nth_tick")
            routes.append(
                PeriodicRoute(
                    path=rpath,
                    line=idx + 1,
                    kind=call_kind,
                    interval=interval or "?",
                    numeric_interval=numeric_interval(interval),
                    name="",
                    owner=literal_field(block, "owner"),
                    category=literal_field(block, "category"),
                    budget="",
                    priority=literal_field(block, "priority"),
                )
            )

        if "find_entities_filtered" in stripped:
            if stripped.startswith("--"):
                continue
            block = block_from(lines, idx, max_lines=24)
            has_area, has_position_radius, has_type, has_name, has_force, has_limit, risk = classify_scan(block)
            scans.append(
                ScanSite(
                    path=rpath,
                    line=idx + 1,
                    snippet=compact(block)[:240],
                    has_area=has_area,
                    has_position_radius=has_position_radius,
                    has_type=has_type,
                    has_name=has_name,
                    has_force=has_force,
                    has_limit=has_limit,
                    risk=risk,
                )
            )

        rewrite_patterns = [
            ("direct-set-command", r"\bset_command\s*\("),
            ("movement-request", r"tech_priests_request_movement_0418\s*\("),
            ("route-command", r"\broute_command\s*\("),
            ("movement-request-state", r"\brequests\s*\["),
            ("pair-mode-write", r"\bpair\.mode\s*="),
            ("pair-target-write", r"\bpair\.target\s*="),
            ("leaf-task-write", r"\bactive_leaf_task_0655\s*="),
            ("actual-task-status-write", r"\bactual_task_status_0655\s*="),
            ("movement-request-write", r"\bmovement_request_0418\s*="),
            ("active-order-write", r"\bactive_order_"),
            ("direct-task-write", r"\bdirect_acquisition_task_"),
            ("emergency-craft-write", r"\bemergency_craft\s*="),
            ("logistics-fetch-write", r"\blogistics_fetch_0527\s*="),
        ]
        for kind, pattern in rewrite_patterns:
            if re.search(pattern, stripped):
                rewrites.append(RewriteSite(rpath, idx + 1, kind, compact(stripped)[:220]))

    return routes, scans, rewrites


def audit(root: Path) -> dict[str, object]:
    routes: list[PeriodicRoute] = []
    scans: list[ScanSite] = []
    rewrites: list[RewriteSite] = []
    files = list(iter_lua(root))
    for path in files:
        r, s, w = audit_file(path)
        routes.extend(r)
        scans.extend(s)
        rewrites.extend(w)

    route_kinds = Counter(route.kind for route in routes)
    route_categories = Counter(route.category or "?" for route in routes)
    scan_risks = Counter(scan.risk for scan in scans)
    rewrite_kinds = Counter(site.kind for site in rewrites)
    rewrite_files = Counter(site.path for site in rewrites)

    frequent = [
        route for route in routes
        if route.numeric_interval is not None and route.numeric_interval <= 30
    ]
    frequent.sort(key=lambda r: (r.numeric_interval or 999999, r.path, r.line))
    active_frequent = [route for route in frequent if route.kind != "script-fallback"]
    risky_scans = [scan for scan in scans if scan.risk not in {"bounded-or-filtered", "dynamic-filter-helper"}]
    risky_scans.sort(key=lambda s: (s.risk, s.path, s.line))

    return {
        "source_root": rel(root),
        "files_scanned": len(files),
        "periodic_routes": [asdict(route) for route in routes],
        "scan_sites": [asdict(scan) for scan in scans],
        "rewrite_sites": [asdict(site) for site in rewrites],
        "summary": {
            "periodic_route_count": len(routes),
            "route_kinds": dict(route_kinds),
            "route_categories": dict(route_categories),
            "frequent_route_count_le_30": len(frequent),
            "active_frequent_route_count_le_30": len(active_frequent),
            "scan_site_count": len(scans),
            "scan_risks": dict(scan_risks),
            "risky_scan_count": len(risky_scans),
            "rewrite_site_count": len(rewrites),
            "rewrite_kinds": dict(rewrite_kinds),
            "top_rewrite_files": dict(rewrite_files.most_common(20)),
        },
        "frequent_routes": [asdict(route) for route in frequent],
        "active_frequent_routes": [asdict(route) for route in active_frequent],
        "risky_scans": [asdict(scan) for scan in risky_scans],
    }


def md_table(headers: list[str], rows: list[list[object]]) -> list[str]:
    lines = ["| " + " | ".join(headers) + " |", "| " + " | ".join("---" for _ in headers) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(str(v).replace("|", "\\|") for v in row) + " |")
    return lines


def write_markdown(report: dict[str, object], path: Path) -> None:
    summary = report["summary"]
    assert isinstance(summary, dict)
    frequent = report["frequent_routes"]
    risky_scans = report["risky_scans"]
    rewrites = report["rewrite_sites"]
    assert isinstance(frequent, list)
    assert isinstance(risky_scans, list)
    assert isinstance(rewrites, list)

    lines: list[str] = []
    lines.append("# UPS Hotspot Audit 0743")
    lines.append("")
    lines.append("**Status:** static source audit; requires clean-world profiler confirmation")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    for key in [
        "periodic_route_count",
        "frequent_route_count_le_30",
        "active_frequent_route_count_le_30",
        "scan_site_count",
        "risky_scan_count",
        "rewrite_site_count",
    ]:
        lines.append(f"- `{key}`: {summary.get(key)}")
    lines.append("")
    lines.append("### Route Kinds")
    lines.extend(md_table(["kind", "count"], [[k, v] for k, v in sorted(summary.get("route_kinds", {}).items())]))
    lines.append("")
    lines.append("### Scan Risk Kinds")
    lines.extend(md_table(["risk", "count"], [[k, v] for k, v in sorted(summary.get("scan_risks", {}).items())]))
    lines.append("")
    lines.append("### Rewrite Kinds")
    lines.extend(md_table(["kind", "count"], [[k, v] for k, v in sorted(summary.get("rewrite_kinds", {}).items())]))
    lines.append("")
    lines.append("## Frequent Wake Routes")
    lines.append("")
    rows = []
    for route in frequent[:40]:
        rows.append([
            route.get("interval"),
            route.get("kind"),
            route.get("name") or route.get("owner") or "?",
            route.get("category") or "?",
            route.get("budget") or "",
            f"{route.get('path')}:{route.get('line')}",
        ])
    lines.extend(md_table(["interval", "kind", "authority", "category", "budget", "site"], rows))
    lines.append("")
    lines.append("## Risky Scan Sites")
    lines.append("")
    rows = []
    for scan in risky_scans[:50]:
        rows.append([
            scan.get("risk"),
            "yes" if scan.get("has_type") else "no",
            "yes" if scan.get("has_name") else "no",
            "yes" if scan.get("has_force") else "no",
            "yes" if scan.get("has_limit") else "no",
            f"{scan.get('path')}:{scan.get('line')}",
        ])
    lines.extend(md_table(["risk", "type", "name", "force", "limit", "site"], rows))
    lines.append("")
    lines.append("## Top Movement/Task Rewrite Files")
    lines.append("")
    top_files = summary.get("top_rewrite_files", {})
    lines.extend(md_table(["file", "rewrite sites"], [[k, v] for k, v in top_files.items()]))
    lines.append("")
    lines.append("## Interpretation")
    lines.append("")
    lines.append("- Treat frequent routes as wake-pressure suspects, not proven bottlenecks.")
    lines.append("- Treat broad-area and global-or-unbounded scans as first-class UPS risks.")
    lines.append("- Treat files with many movement/task rewrites as churn-risk authorities that must agree with leaf-truth and movement-controller ownership.")
    lines.append("- Confirm all suspected costs with `tech-priests-debug-mode=profiler` and `/tp-runtime-report` in a clean new-world save.")
    lines.append("")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(DEFAULT_SOURCE), help="Source root to scan.")
    parser.add_argument("--json", default=None, help="Optional JSON report path.")
    parser.add_argument("--markdown", default=None, help="Optional Markdown report path.")
    parser.add_argument("--print-summary", action="store_true", help="Print concise text summary.")
    args = parser.parse_args(argv)

    root = Path(args.root)
    if not root.is_absolute():
        root = ROOT / root
    report = audit(root)

    if args.json:
        out = Path(args.json)
        if not out.is_absolute():
            out = ROOT / out
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if args.markdown:
        out = Path(args.markdown)
        if not out.is_absolute():
            out = ROOT / out
        out.parent.mkdir(parents=True, exist_ok=True)
        write_markdown(report, out)
    if args.print_summary or not (args.json or args.markdown):
        summary = report["summary"]
        assert isinstance(summary, dict)
        print("UPS hotspot audit 0743")
        print(f"files_scanned={report['files_scanned']}")
        for key in [
            "periodic_route_count",
            "frequent_route_count_le_30",
            "active_frequent_route_count_le_30",
            "scan_site_count",
            "risky_scan_count",
            "rewrite_site_count",
        ]:
            print(f"{key}={summary.get(key)}")
        print("scan_risks=" + json.dumps(summary.get("scan_risks", {}), sort_keys=True))
        print("rewrite_kinds=" + json.dumps(summary.get("rewrite_kinds", {}), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
