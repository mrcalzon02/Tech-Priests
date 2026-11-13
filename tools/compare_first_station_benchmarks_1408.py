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
import re
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
    # Verified Factorio 2.1.24 native output uses one real update CSV:
    # run 1:
    # tick,timestamp,wholeUpdate,scriptUpdate,...,
    # t0,0,123000,45600,...,
    # ...
    # t1999,...,
    # The trailing empty column and the "t" tick prefix are REQUIRED native
    # syntax, not invented/missing values. Fail on partial or corrupted rows.
    header: list[str] | None = None
    samples: dict[int, dict[str, float]] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        cells = [part.strip().strip('"') for part in next(csv.reader([line]))]
        # A native comma at the END of every row/header produces one empty
        # terminal field; remove exactly that known CSV sentinel only.
        if cells and cells[-1] == "":
            cells.pop()
        if "wholeUpdate" in cells and "scriptUpdate" in cells:
            if header is not None:
                raise ValueError(f"{case}: multiple native verbose headers")
            if len(set(cells)) != len(cells) or "tick" not in cells:
                raise ValueError(f"{case}: invalid native verbose field names")
            if any(key not in cells for key in FIELDS):
                raise ValueError(f"{case}: native benchmark missing requested metrics")
            header = cells
            continue
        if header is None:
            continue
        # Factorio starts an update row with "t<number>" rather than a
        # literal integer. Ignore ordinary engine status/log lines, not
        # malformed tick rows.
        tick = re.fullmatch(r"t(\d+)", cells[0])
        if not tick:
            continue
        if len(cells) != len(header):
            raise ValueError(f"{case}: malformed native row field count")
        index = int(tick.group(1))
        if index != len(samples):
            raise ValueError(
                f"{case}: duplicate/out-of-order/missing native tick {index}")
        row: dict[str, float] = {}
        for key in FIELDS:
            raw_value = cells[header.index(key)]
            try:
                value = float(raw_value)
            except ValueError as exc:
                raise ValueError(
                    f"{case}: invalid native {key} at tick {index}") from exc
            if not math.isfinite(value) or value < 0:
                raise ValueError(
                    f"{case}: unbounded native {key} at tick {index}")
            row[key] = value / 1e6  # native nanoseconds to milliseconds
        samples[index] = row
    if header is None:
        raise ValueError(
            f"{case}: missing Factorio 2.1.24 benchmark timing header")
    if len(samples) != 2000:
        raise ValueError(
            f"{case}: incomplete native benchmark {len(samples)}/2000 ticks")
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
