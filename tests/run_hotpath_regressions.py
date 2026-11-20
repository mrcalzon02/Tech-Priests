#!/usr/bin/env python3
"""Cross-platform, manual Tech Priests hot-path Lua regression runner.

No GitHub Actions triggers, mod launches, packaging, or network calls.
Usage:
  python tests/run_hotpath_regressions.py           # bounded source-level smoke
  python tests/run_hotpath_regressions.py --all     # include unverified integrations
  python tests/run_hotpath_regressions.py --lua texlua
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path
from time import perf_counter

ROOT = Path(__file__).resolve().parent.parent
SMOKE = (
    "pair_bucket_forced_index_1472.lua",
    "catalog_dense_scan_1478.lua",
    "catalog_noise_prefilter_1482.lua",
    "entity_identity_1481.lua",
    "catalog_gui_layout_1483.lua",
    "station_catalog_reuse_guard_1484.lua",
    "station_cache_completeness_1476.lua",
    "catalog_expanded_cache_1480.lua",
    "spatial_index_bounds_1485.lua",
    "uncertified_scan_preserves_cache_1486.lua",
    "runtime_name_memo_1487.lua",
    "scan_negative_bounded_1488.lua",
    "spatial_cache_effectiveness_1489.lua",
    "work_queue_duplicate_wake_1490.lua",
    "idle_invalidation_epoch_1491.lua",
    "idle_activity_classification_1492.lua",
    "indexed_entity_sort_1494.lua",
    "catalog_owner_index_1496.lua",
    "idle_player_observation_1497.lua",
)
EXTENDED = (
    "economy_route_fairness_cache_1470.lua",
    "event_registry_hot_path_1473.lua",
    "dispatcher_roster_cache_1475.lua",
    "station_catalog_dense_integration_1479.lua",
    "identity_catalog_index_integration_1481.lua",
    "work_queue_duplicate_integration_1490.lua",
    "idle_world_event_integration_1491.lua",
    "station_catalog_scan_context_1493.lua",
    "catalog_owner_cleanup_1496.lua",
    "idle_adaptive_observation_integration_1497.lua",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="Run extended integration fixtures too")
    parser.add_argument("--lua", default="texlua", help="Executable to run Lua tests (default: texlua)")
    args = parser.parse_args()
    lua = shutil.which(args.lua)
    if lua is None:
        print(f"[hotpath-regressions] FAIL: Lua interpreter not found: {args.lua}", file=sys.stderr)
        return 2
    files = SMOKE + (EXTENDED if args.all else ())
    failed = []
    started = perf_counter()
    for name in files:
        relative = Path("tests") / "unit" / name
        if not (ROOT / relative).is_file():
            print(f"[hotpath-regressions] MISSING {relative}", flush=True)
            failed.append(str(relative))
            continue
        result = subprocess.run([lua, str(relative)], cwd=ROOT, text=True, capture_output=True, check=False)
        if result.stdout:
            print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
        if result.stderr:
            print(result.stderr, file=sys.stderr, end="" if result.stderr.endswith("\n") else "\n")
        print(f"[hotpath-regressions] {'PASS' if result.returncode == 0 else 'FAIL'} {name} (exit={result.returncode})", flush=True)
        if result.returncode:
            failed.append(name)
    print(f"[hotpath-regressions] suite={'all' if args.all else 'smoke'} "
          f"passed={len(files)-len(failed)}/{len(files)} duration={perf_counter()-started:.2f}s")
    if failed:
        print("[hotpath-regressions] failures: " + ", ".join(failed), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
