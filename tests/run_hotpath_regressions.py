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
    "bounded_planning_area_1507.lua",
    "force_planning_queue_1507.lua",
    "infrastructure_continuation_1507.lua",
    "drill_output_witness_1507.lua",
    "ordinary_placement_continuation_1507.lua",
    "owned_ghost_admission_1507.lua",
    "placement_metadata_witness_1507.lua",
    "placement_specialized_continuation_1507.lua",
    "planning_metadata_backpressure_1507.lua",
    "shortage_continuation_1507.lua",
    "traversable_crossings_1507.lua",
    "defense_planning_1507.lua",
    "runtime_profiler_truth.lua",
    "infrastructure_inspection_budget.lua",
    "master_infrastructure_survey_reads.lua",
    "planning_recipe_membership_0646.lua",
    "magos_retained_planning_membership.lua",
    "fixed_rank_armor_existing_authority.lua",
    "armor_profile_metadata_0297.lua",
    "development_audit_retired_owners.lua",
    "development_storage_audit_continuation.lua",
    "master_infrastructure_recipe_membership.lua",
    "master_infrastructure_bootstrap_assistance.lua",
    "master_infrastructure_broker_budget_1070.lua",
    "drill_output_receiver_reconciliation.lua",
    "construction_ghost_broker_budget_1070.lua",
    "bootstrap_ghost_master_plan_reuse_0645.lua",
    "consecration_retained_registry.lua",
    "bunker_technology_prototype_effects.lua",
    "broker_background_admission.lua",
    "proxy_ammo_discovery_0649.lua",
    "station_catalog_event_deferral_0634.lua",
    "catalog_dense_scan_continuation_1498.lua",
    "station_catalog_continuation_1498.lua",
    "station_catalog_retained_inventory_1497.lua",
    "emergency_facility_provider_snapshot_1072.lua",
    "emergency_craft_retained_inventory.lua",
    "storage_discovery_cache_0587.lua",
    "logistics_general_storage_custody.lua",
    "logistics_retained_sources_0527.lua",
    "quality_turret_dormant_service.lua",
    "locale_structure.lua",
    "combat_roster_quality_transfer.lua",
    "machine_spirit_quality_baseline.lua",
    "machine_spirit_doctrine_modules.lua",
    "machine_spirit_doctrine_waste.lua",
    "machine_spirit_module_refresh.lua",
    "machine_spirit_chaos_hazards.lua",
    "machine_spirit_chaos_hazard_handlers.lua",
    "machine_spirit_vehicle_operator.lua",
    "machine_spirit_clone_bridge.lua",
    "faction_factory_doctrine_slots.lua",
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
    "enemy_seed_config_cache_1498.lua",
    "broker_profiler_off_1499.lua",
    "reservation_key_lookup_1500.lua",
    "reservation_root_fast_1501.lua",
    "broker_pressure_cache_1502.lua",
    "repair_scan_cursor_1503.lua",
    "dispatcher_custody_probe_1504.lua",
    "route_classification_1505.lua",
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
    "enemy_planet_seeding_integration_1498.lua",
    "work_queue_reservation_key_1500.lua",
    "reservation_root_integration_1501.lua",
    "broker_pressure_integration_1502.lua",
    "repair_discovery_rotation_1503.lua",
    "route_governor_integration_1505.lua",
    "broker_telemetry_window_1506.lua",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="Run extended integration fixtures too")
    parser.add_argument("--lua", default="texlua", help="Executable to run Lua tests (default: texlua)")
    args = parser.parse_args()
    inventory_contract = subprocess.run(
        [sys.executable, str(ROOT / "tests/test_behavior_source_inventory.py")],
        cwd=ROOT, check=False,
    )
    if inventory_contract.returncode:
        print("[hotpath-regressions] FAIL: behavior inventory regression contract", file=sys.stderr)
        return 1
    # The maps are part of the behavior change contract. Regenerating the
    # inventory does not acknowledge review of the handwritten Mermaid maps.
    mapped = subprocess.run(
        [sys.executable, str(ROOT / "tools/audit_ups_hotspots_0743.py"),
         "--check-behavior-maps"], cwd=ROOT, check=False,
    )
    if mapped.returncode:
        print("[hotpath-regressions] FAIL: source/map coverage or review is stale", file=sys.stderr)
        return 1
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
