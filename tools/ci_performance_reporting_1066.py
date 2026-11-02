#!/usr/bin/env python3
"""Nonblocking, provenance-aware performance reports for existing Factorio CI.

Runs on BOTH successful and failed native save/reload attempts. This is strictly
diagnostic: no source/engine pass/fail or custody validation depends on a metric.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import pathlib
import tempfile
from typing import Callable

ROOT = pathlib.Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "tools" / "ci_performance_reference_1066.json"
LOGS = (
    "factorio-save-server.log",
    "factorio-stranded-server.log",
    "factorio-ore-carry-server.log",
    "factorio-stock-carry-server.log",
    "factorio-reload.log",
)
METRICS = (
    ("engine_benchmark_ups", "Whole-engine benchmark UPS", "UPS"),
    ("engine_update_average_ms_per_tick", "Mean engine update", "ms/tick"),
    ("broker_pulse_sample_count", "Sampled broker dispatches", "samples"),
    ("broker_pulse_average_ms_per_sample", "Mean broker dispatch", "ms/sample"),
    ("broker_pulse_p95_ms_per_sample", "p95 broker dispatch", "ms/sample"),
    ("script_average_ms_per_tick", "Whole-script time", "ms/tick"),
    ("script_p95_ms_per_tick", "Whole-script p95", "ms/tick"),
    ("delivered_ore_per_1000_ticks", "Ore delivery throughput", "ore/1000 ticks"),
    ("fixture_to_first_delivery_ticks", "Fixture to first delivery", "ticks"),
    ("movement_denials_per_1000_ticks", "Movement denials", "count/1000 ticks"),
    ("scan_calls_per_1000_ticks", "Scan calls", "count/1000 ticks"),
)
METRIC_KEYS = tuple(item[0] for item in METRICS)


def numeric(value: object) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def compare(observed: dict[str, object],
            reference: dict[str, object],
            functional_success: bool) -> dict[str, dict[str, object]]:
    """Compare only identical benchmark lengths. Never infer missing values."""
    settings = reference.get("provenance", {})
    if (observed.get("engine_benchmark_updates")
            != settings.get("benchmark_updates")):
        return {}
    base = reference.get("measurements", {})
    thresholds = reference.get("investigate_relative_change_percent", {})
    comparisons = {}
    for field, before in base.items():
        after = observed.get(field)
        if not (numeric(before) and numeric(after) and before > 0):
            continue
        delta = 100.0 * (after - before) / before
        threshold = thresholds.get(field)
        flag = (numeric(threshold) and
                (delta >= threshold if threshold >= 0 else delta <= threshold))
        comparisons[field] = {
            "reference": before,
            "current": after,
            "change_percent": round(delta, 2),
            # A failed functional fixture can skew the profile; warn only.
            "note": "investigate" if flag and functional_success
                    else "context-only" if flag else "within-reference-band",
            "diagnostic_only": True,
        }
    return comparisons


def build_markdown(report: dict[str, object]) -> str:
    primary = report["primary"]
    reference = report.get("reference", {})
    comparisons = report.get("comparisons", {})
    lines = [
        "### Tech Priests — native performance diagnostics",
        "",
        "These figures are **diagnostics**, not release or functional acceptance gates.",
        f"- Engine result: **{report['functional_status']}**; commit: `{report['commit']}`",
        f"- Reference: {reference.get('provenance', {}).get('run_url', 'unavailable')}; "
        "different runner load and scenarios can distort comparisons.",
        "",
        "| Metric | Current | Reference | Change | Assessment |",
        "|---|---:|---:|---:|---|",
    ]
    for key, label, unit in METRICS:
        value = primary.get(key)
        comp = comparisons.get(key)
        current = f"{value} {unit}" if numeric(value) else "not measured"
        ref = f"{comp['reference']} {unit}" if comp else "—"
        change = f"{comp['change_percent']:+.2f}%" if comp else "—"
        note = comp["note"] if comp else "unmeasured / not comparable"
        lines.append(f"| {label} | {current} | {ref} | {change} | {note} |")
    lines.extend([
        "",
        "Broker dispatch is not whole-script time. Whole-engine UPS is not an",
        "isolated five-priest UPS benchmark. Changes beyond the reference band",
        "merit investigation under matched seed, population and runner conditions;",
        "**they never block a functional release or test pass.**",
        "",
        f"Observed process logs: {len(report['stage_observations'])}/{len(LOGS)}",
        "",
    ])
    return "\n".join(lines)


def write_report(work_dir: pathlib.Path, artifact_dir: pathlib.Path,
                 parse: Callable[[str], dict[str, object]],
                 success: bool, commit: str = "unknown",
                 summary_file: pathlib.Path | None = None
                 ) -> dict[str, object]:
    """Retain diagnostics even when the fifth Factorio process fails early."""
    reference = json.loads(REFERENCE.read_text(encoding="utf-8"))
    stages = {}
    for name in LOGS:
        source = work_dir / name
        if not source.is_file():
            continue
        stages[name] = parse(source.read_text(
            encoding="utf-8", errors="replace"))
    # The only comparable 48,000-update benchmark is the final reload.
    primary = stages.get("factorio-reload.log", {})
    comparisons = compare(primary, reference, success)
    report = {
        "schema": "tech-priests-ci-performance-observation-1066-v1",
        "commit": commit,
        "functional_status": "pass" if success else "fail-or-incomplete",
        "primary_stage": "factorio-reload.log" if primary else None,
        "primary": primary,
        "stage_observations": stages,
        "reference": reference,
        "comparisons": comparisons,
        "performance_warnings": [
            field for field, result in comparisons.items()
            if result["note"] == "investigate"],
        "performance_is_release_blocking": False,
    }
    artifact_dir.mkdir(parents=True, exist_ok=True)
    (artifact_dir / "performance-observations.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    markdown = build_markdown(report)
    (artifact_dir / "performance-summary.md").write_text(
        markdown, encoding="utf-8")
    if summary_file:
        with summary_file.open("a", encoding="utf-8") as handle:
            handle.write("\n" + markdown + "\n")
    return report


def write_initial_engine_benchmark(source: pathlib.Path,
                                   artifacts: pathlib.Path,
                                   parse: Callable[[str], dict[str, object]],
                                   summary: pathlib.Path | None = None
                                   ) -> dict[str, object]:
    """Report the OTHER 123k-tick benchmark separately from 48k reload.

    Even a failed/missing game log produces a truthful unmeasured diagnostic.
    """
    content = source.read_text(encoding="utf-8", errors="replace") if source.is_file() else ""
    obs = parse(content)
    fields = ("engine_benchmark_updates", "engine_benchmark_ups",
              "engine_update_average_ms_per_tick", "engine_benchmark_wall_ms")
    measurement = {k: obs.get(k) for k in fields}
    report = {
        "schema": "tech-priests-ci-initial-benchmark-1066-v1",
        "commit": os.environ.get("GITHUB_SHA", "unknown"),
        "source_log_present": source.is_file(),
        "measurements": measurement,
        "reference_comparison": None,
        "reason": "123k initial world is not comparable to 48k reload reference",
        "performance_is_release_blocking": False,
    }
    artifacts.mkdir(parents=True, exist_ok=True)
    (artifacts / "performance-123k-benchmark.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    rows = ["### Tech Priests — 123k engine benchmark (diagnostic)",
            "", "Independent 123k industrial/combat scenario; do not compare "
            "directly with the 48k reload throughput baseline.",
            "", "| Measurement | Observed |", "|---|---:|"]
    for field in fields:
        value = measurement[field]
        rows.append(f"| {field} | {value if numeric(value) else 'not measured'} |")
    rows += ["", "This report does not affect functional test outcomes.", ""]
    markdown = "\n".join(rows)
    (artifacts / "performance-123k-benchmark.md").write_text(
        markdown, encoding="utf-8")
    if summary:
        with summary.open("a", encoding="utf-8") as handle:
            handle.write("\n" + markdown + "\n")
    return report


def self_test(parse: Callable[[str], dict[str, object]]) -> None:
    reference = json.loads(REFERENCE.read_text(encoding="utf-8"))
    test_log = ("  Performed 48000 updates in 480000.000 ms\n"
                "[TP-GROUND-RANK-TEST] PASS REVERSAL_ENGINE_FIVE_STATION_FIXTURE "
                "tick=1000 station_spares=0 original_priests=5\n"
                "[TP-GROUND-RANK-TEST] PASS REVERSAL_ENGINE_NATURAL_ORE_RETURN "
                "tick=2000 physical_hops=4 magos_inventory_delta=1 "
                "delivered_count=1 cargo_empty=true\n")
    with tempfile.TemporaryDirectory() as root:
        root = pathlib.Path(root)
        work = root / "work"
        work.mkdir()
        artifacts = root / "artifacts"
        summary = root / "summary.md"
        (work / "factorio-reload.log").write_text(test_log, encoding="utf-8")
        report = write_report(work, artifacts, parse, True,
                              "source-regression", summary)
        assert report["primary"]["engine_benchmark_updates"] == 48000
        assert report["comparisons"]["engine_benchmark_ups"]["note"] == "investigate"
        assert report["comparisons"]["engine_update_average_ms_per_tick"]["note"] == "investigate"
        assert report["performance_warnings"]
        assert "not measured" in summary.read_text(encoding="utf-8")
        assert json.loads((artifacts / "performance-observations.json").read_text(
            encoding="utf-8"))["functional_status"] == "pass"
        # An incomplete process must still retain truthful partial data.
        (work / "factorio-reload.log").unlink()
        (work / "factorio-save-server.log").write_text(
            "Factorio failed before benchmark\n", encoding="utf-8")
        incomplete = write_report(work, artifacts, parse, False)
        assert incomplete["primary_stage"] is None
        assert incomplete["functional_status"] == "fail-or-incomplete"
        assert incomplete["performance_warnings"] == []
        assert incomplete["stage_observations"]["factorio-save-server.log"]
        # Do not compare a different benchmark or invent unobserved script time.
        mismatched = parse(test_log.replace("48000 updates", "16000 updates"))
        assert compare(mismatched, reference, True) == {}
        assert compare({}, reference, True) == {}
        slow = parse(test_log)
        assert compare(slow, reference, False)["engine_benchmark_ups"]["note"] == "context-only"
        initial = work / "factorio-server.log"
        initial.write_text(
            "  Performed 123000 updates in 950000.000 ms" + chr(10),
            encoding="utf-8")
        benchmark = write_initial_engine_benchmark(initial, artifacts, parse, summary)
        assert benchmark["measurements"]["engine_benchmark_updates"] == 123000
        assert benchmark["reference_comparison"] is None
        assert (artifacts / "performance-123k-benchmark.md").is_file()
        initial.unlink()
        missing_benchmark = write_initial_engine_benchmark(initial, artifacts, parse)
        assert missing_benchmark["measurements"]["engine_benchmark_ups"] is None
        assert missing_benchmark["source_log_present"] is False
    print("[ci-performance-1066] PASS nonblocking successful/failed diagnostic reports")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--benchmark-log", required=True)
    parser.add_argument("--artifact-dir", required=True)
    args = parser.parse_args()
    # Running as a script from tools/ resolves this sibling import without
    # adding another dependency, scheduler or workflow.
    from run_factorio_save_reload_smoke import native_efficiency_observation_1062
    summary_name = os.environ.get("GITHUB_STEP_SUMMARY")
    result = write_initial_engine_benchmark(
        pathlib.Path(args.benchmark_log), pathlib.Path(args.artifact_dir),
        native_efficiency_observation_1062,
        pathlib.Path(summary_name) if summary_name else None)
    print("CI_BENCHMARK_1066 " + json.dumps(result, sort_keys=True))
