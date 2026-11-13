#!/usr/bin/env python3
"""Exact Factorio 2.1 native CSV grammar/continuity regression for 1408."""
from __future__ import annotations

import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))
from tools.compare_first_station_benchmarks_1408 import (  # noqa: E402
    compare, read_engine_log, summarize,
)

COLUMNS = [
    "tick", "timestamp", "wholeUpdate", "scriptUpdate", "pathFinder",
    "chartUpdate", "luaGarbageIncremental", "entityUpdate",
]


def materialize(path: pathlib.Path, case: str, *, spike: bool = False,
                bad_tick: int | None = None, nonfinite: int | None = None,
                duplicate: int | None = None, no_script: bool = False) -> None:
    header = [name for name in COLUMNS
              if not (no_script and name == "scriptUpdate")]
    rows = [
        "[TP-FIRST-STATION-BENCH-1408] "
        f"PASS case={case} native_first_station_wake="
        + ("false" if case == "baseline" else "true") + " tick=1800",
        "run 1:",
        ",".join(header) + ",",
    ]
    for tick in range(2000):
        if tick == bad_tick:
            continue
        ms = 30000000 if spike and tick == 600 else 100000
        data = {
            "tick": f"t{duplicate if tick == duplicate else tick}",
            "timestamp": str(tick * 1000000),
            "wholeUpdate": str(ms),
            "scriptUpdate": str(25000000 if spike and tick == 600 else 30000),
            "pathFinder": "0",
            "chartUpdate": "0",
            "luaGarbageIncremental": "1000",
            "entityUpdate": "5000",
        }
        if nonfinite == tick:
            data["scriptUpdate"] = "NaN"
        rows.append(",".join(data[name] for name in header) + ",")
    rows.append("Performed 2000 updates in 200.000 ms")
    path.write_text("\n".join(rows) + "\n", encoding="utf-8")


def reject(path: pathlib.Path, case: str, why: str) -> None:
    try:
        read_engine_log(path, case)
    except ValueError:
        return
    raise AssertionError("native parser incorrectly accepted " + why)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="tp-1408-csv-") as work:
        root = pathlib.Path(work)
        clean = root / "baseline.log"
        changed = root / "placement.log"
        materialize(clean, "baseline")
        materialize(changed, "placement-unprofiled", spike=True)
        base = read_engine_log(clean, "baseline")
        altered = read_engine_log(changed, "placement-unprofiled")
        assert base["sample_count"] == altered["sample_count"] == 2000
        assert base["timings_ms"][600]["wholeUpdate"] == 0.1
        assert altered["timings_ms"][600]["wholeUpdate"] == 30.0
        comparison = compare(summarize(base), summarize(altered))
        peak = comparison["placement_spike"]["wholeUpdate"]
        assert peak["delta_max_ms"] == 29.9
        assert peak["delta_mean_ms"] > 0
        assert comparison["pre_place"]["wholeUpdate"]["delta_mean_ms"] == 0
        assert comparison["settled"]["wholeUpdate"]["delta_max_ms"] == 0
        materialize(changed, "placement-unprofiled", bad_tick=601)
        reject(changed, "placement-unprofiled", "missing tick")
        materialize(changed, "placement-unprofiled", duplicate=601)
        reject(changed, "placement-unprofiled", "duplicate/out-of-order tick")
        materialize(changed, "placement-unprofiled", nonfinite=600)
        reject(changed, "placement-unprofiled", "NaN")
        materialize(changed, "placement-unprofiled", no_script=True)
        reject(changed, "placement-unprofiled", "missing scriptUpdate")
        materialize(changed, "baseline")
        reject(changed, "placement-unprofiled", "wrong native case PASS marker")
    print("[first-station-benchmark-parser-1408] PASS true t0..t1999 native grammar, 30ms placement spike, missing/duplicate/NaN/mislabel refusal")


if __name__ == "__main__":
    main()
