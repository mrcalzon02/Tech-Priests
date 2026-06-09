#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path("tech-priests_src")

# This checker is intentionally marker-based. It does not prove behavior correct,
# but it catches the exact regression class we are auditing: a movement-driven
# executor that requests movement but does not visibly gate task work behind a
# close-enough proximity check.
PROXIMITY_AUDIT = {
    ROOT / "scripts/core/direct_acquisition_executor_0513.lua": [
        "M.close_distance_sq",
        "if d2 > M.close_distance_sq then",
        "set_phase(pair, \"work-target\"",
    ],
    ROOT / "scripts/core/emergency_production_executor_0514.lua": [
        "M.station_close_distance_sq",
        "local function at_station(pair)",
        "if not at_station(pair) then",
    ],
    ROOT / "scripts/core/consecration_executor_0515.lua": [
        "PRIEST_CONSECRATION_REACH_DISTANCE_SQ",
        "if ds > reach then",
        "performing-consecration-rite",
    ],
    ROOT / "scripts/core/repair_executor_0516.lua": [
        "M.repair_range_sq",
        "if ds > M.repair_range_sq then",
        "pair.mode=\"repairing\"",
    ],
    ROOT / "scripts/core/combat_repair_doctrine_0517.lua": [
        "M.repair_range_sq",
        "Repair.service_pair",
        "combat-repair-0517",
    ],
    ROOT / "scripts/core/crafting_executor.lua": [
        "Craft.close_distance_sq",
        "local function at_station(pair)",
        "if not at_station(pair) then",
    ],
    ROOT / "scripts/core/construction_planner.lua": [
        "Build.close_distance_sq",
        "Build.station_close_distance_sq",
        "if d2 > Build.close_distance_sq then",
        "task.phase = \"placing\"",
    ],
    ROOT / "scripts/core/logistics_fetch_executor_0527.lua": [
        "M.pickup_radius_sq",
        "M.deposit_radius_sq",
        "moving-to-known-source",
        "moving-to-storage",
    ],
    ROOT / "scripts/core/logistics_machine_fulfillment_0528.lua": [
        "M.machine_reach_sq",
        "M.storage_reach_sq",
        "if dist_sq(pair.priest.position, machine.position) > M.machine_reach_sq then",
        "if dist_sq(pair.priest.position, box.position) > M.storage_reach_sq then",
    ],
    ROOT / "scripts/core/ground_item_hoover_0529.lua": [
        "M.pickup_radius_sq",
        "if dist_sq(pair.priest.position,src.position) > M.pickup_radius_sq then",
        "if dist_sq(pair.priest.position,box.position) > M.pickup_radius_sq then",
        "move-to-ground-item",
        "move-to-storage",
    ],
}

MOVEMENT_MARKERS = (
    "request_movement",
    "tech_priests_request_movement_0418",
    "request_move",
    "set_move",
    "return_to_station",
    "move_to_station",
)

PROXIMITY_MARKERS = (
    "dist_sq(",
    "at_station(",
    "close_distance_sq",
    "reach_sq",
    "reach_distance",
    "machine_reach_sq",
    "storage_reach_sq",
    "pickup_radius_sq",
    "deposit_radius_sq",
    "repair_range_sq",
)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def main() -> int:
    failures: list[str] = []
    print("Stage 5 proximity-gate audit checker")
    for path, markers in PROXIMITY_AUDIT.items():
        if not path.exists():
            failures.append(f"{path}: missing file")
            print(f"FAIL {path}: missing file")
            continue
        src = read(path)
        missing = [m for m in markers if m not in src]
        movement_seen = any(m in src for m in MOVEMENT_MARKERS)
        proximity_seen = any(m in src for m in PROXIMITY_MARKERS)
        if missing or (movement_seen and not proximity_seen):
            if missing:
                failures.append(f"{path}: missing markers: {', '.join(missing)}")
            if movement_seen and not proximity_seen:
                failures.append(f"{path}: movement marker present but no proximity marker found")
            print(f"FAIL {path}")
            for m in missing:
                print(f"  - missing marker: {m}")
            if movement_seen and not proximity_seen:
                print("  - movement marker present but no proximity marker found")
        else:
            print(f"OK   {path}")

    if failures:
        print("\nFAILED proximity-gate audit:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("\nAll audited movement-driven executors expose explicit proximity gates before work/deposit/placement phases.")
    print("This marker audit does not replace an in-game behavior test.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
