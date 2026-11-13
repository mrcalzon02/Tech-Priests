#!/usr/bin/env python3
"""Compare native Factorio 2.1.24 cold-start timings, never invent samples.

All three benchmark logs must come from the SAME source SHA, Factorio binary,
hardware and map seed: baseline, first placement (unprofiled), and optional
first placement with opt-in LuaProfiler attribution.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import pathlib
import statistics

WINDOWS = {
    "pre_place": (100, 540),
    "placement_spike": (590, 630),
    "cold_wake": (630, 780),
    "after_wake": (780, 1200),
    "settled": (1200, 1900),
}
FIELDS = ("wholeUpdate", "scriptUpdate", "pathFinder", "chartUpdate",
          "luaGarbageIncremental", "entityUpdate")
PREFIX = "[TP-FIRST-STATION-BENCH-1408] "


def read_engine_log(path: pathlib.Path, case: str) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    if PREFIX + "FAIL " in text:
        raise ValueError(f"{case}: Factorio fixture reports FAIL")
    expected = (PREFIX + f"PASS case={case} native_first_station_wake="
                + ("false" if case == "baseline" else "true"))
    if expected not in text:
        raise ValueError(f"{case}: missing actual native fixture PASS")
    # Factorio --benchmark-verbose all uses nanoseconds for its per-update
    # metric columns. Require a recognized header and numeric rows, not
    # free-form guesses from log messages or from game.create_profiler text.
    header = None
    samples: dict[int, dict[str, float]] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        cells = next(csv.reader([line]))
        normalized = [cell.strip().strip('"') for cell in cells]
        if "wholeUpdate" in normalized and "scriptUpdate" in normalized:
            header = normalized
            continue
        if not header or len(normalized) != len(header):
            continue
        if any(not v for v in normalized):
            continue
        try:
            data = {k: float(v) for k, v in zip(header, normalized)}
        except ValueError:
            continue
        if not all(math.isfinite(v) and v >= 0 for v in data.values()):
            continue
        tick_key = next((k for k in ("tick", "Tick", "ticks")
                         if k in data), None)
        # When benchmark CSV omits the tick column, rows are consecutive
        # per-tick records beginning with the save's first benchmark update.
        index = int(data[tick_key]) if tick_key else len(samples) + 1
        if not 0 <= index <= 1000000:
            continue
        samples[index] = {key: data[key] / 1e6
                          for key in FIELDS if key in data}
    if not samples:
        raise ValueError(
            f"{case}: no parseable native --benchmark-verbose all timing CSV; "
            "retain raw log and inspect its actual header instead of inventing UPS")
    return {
        "case": case,
        "timings_ms": samples,
        "sample_count": len(samples),
        "native_profiler_events": text.count("[TP-FIRST-STATION-1406]"),
    }


def pct(numbers: list[float], frac: float) -> float:
    ordered = sorted(numbers)
    position = math.ceil(frac * len(ordered)) - 1
    return ordered[max(0, position)]


def summarize(run: dict) -> dict:
    samples = run["timings_ms"]
    out = {"case": run["case"], "total_native_ticks": len(samples),
           "native_profiler_events": run["native_profiler_events"],
           "windows": {}}
    for label, (a, b) in WINDOWS.items():
        section = [row for index, row in samples.items() if a <= index < b]
        metrics = {}
        for key in FIELDS:
            numbers = [row[key] for row in section if key in row]
            if numbers:
                metrics[key] = {
                    "n": len(numbers),
                    "mean_ms": round(statistics.fmean(numbers), 5),
                    "p95_ms": round(pct(numbers, .95), 5),
                    "max_ms": round(max(numbers), 5),
                }
        out["windows"][label] = metrics
    if not all(out["windows"][name].get("wholeUpdate")
               for name in ("pre_place", "placement_spike", "cold_wake", "settled")):
        raise ValueError(run["case"] + ": too few native ticks to compare windows")
    return out


def compare(baseline: dict, placed: dict) -> dict:
    out = {}
    for label in WINDOWS:
        left = baseline["windows"][label]
        right = placed["windows"][label]
        if "wholeUpdate" not in left or "wholeUpdate" not in right:
            raise ValueError(label + ": missing paired engine wholeUpdate")
        row = {}
        for name in FIELDS:
            if name in left and name in right:
                row[name] = {
                    "baseline_max_ms": left[name]["max_ms"],
                    "placement_max_ms": right[name]["max_ms"],
                    "delta_max_ms": round(right[name]["max_ms"]
                                          - left[name]["max_ms"], 5),
                    "baseline_mean_ms": left[name]["mean_ms"],
                    "placement_mean_ms": right[name]["mean_ms"],
                    "delta_mean_ms": round(right[name]["mean_ms"]
                                           - left[name]["mean_ms"], 5),
                }
        out[label] = row
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output-dir", required=True, type=pathlib.Path,
                    help="Parent directory of isolated-service benchmark cases")
    ap.add_argument("--source-sha", required=True,
                    help="Exact identical tested main source SHA for all three runs")
    args = ap.parse_args()
    if len(args.source_sha) != 40 or any(
            ch not in "0123456789abcdef" for ch in args.source_sha.lower()):
        ap.error("--source-sha requires exact 40-character Git commit SHA")
    cases = ("baseline", "placement-unprofiled", "placement")
    reports = {}
    for case in cases:
        folder = args.output_dir / {
            "baseline": "first-station-baseline-1408",
            "placement-unprofiled":
                "first-station-placement-unprofiled-1408",
            "placement": "first-station-placement-1408",
        }[case]
        report = read_engine_log(folder / "benchmark.log", case)
        reports[case] = summarize(report)
    comparison = compare(reports["baseline"], reports["placement-unprofiled"])
    result = {
        "source_sha": args.source_sha,
        "measurement": "actual-factorio-benchmark-verbose-nanoseconds",
        "windows": {name: list(bounds) for name, bounds in WINDOWS.items()},
        "native_cases": reports,
        "unprofiled_vs_baseline": comparison,
        "limitation": "Headless cannot measure GUI/overlay FPS; instrumented run "
                      "is diagnostic only and is excluded from timing A/B.",
        "performance_release_gate": "diagnostic-until-real-run-or-launch-failure",
    }
    path = args.output_dir / "first-station-performance-comparison-1408.json"
    path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")
    print("Native first-station timing comparison: " + str(path))
    for label in WINDOWS:
        metrics = comparison[label]
        print(label + ": wholeUpdate delta_max_ms="
              + str(metrics["wholeUpdate"]["delta_max_ms"])
              + " delta_mean_ms="
              + str(metrics["wholeUpdate"]["delta_mean_ms"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
