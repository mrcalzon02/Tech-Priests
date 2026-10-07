# GitHub File Manifest

Refreshed for the Stage 5 movement-failure, proximity-gate, and Void Priest movement-authority repair batch.

## Runtime movement authority files

- `tech-priests_src/scripts/core/movement_controller.lua` — canonical public movement request/status owner, ground movement controller, ground-envelope enforcement owner, and delegator for Void pairs.
- `tech-priests_src/scripts/core/void_movement_authority_0630.lua` — broker-only specialized Void Priest same-surface movement backend delegated by `movement_controller`; it does not own the public movement wrappers.
- `tech-priests_src/scripts/core/movement_enforcement_0566.lua` — inert source-preserved retirement marker; enforcement authority moved into `movement_controller`.

## Stage 5 movement-failure repair targets

- `tech-priests_src/scripts/core/direct_acquisition_executor_0513.lua` — direct acquisition travel, deposit, and return movement failure handling.
- `tech-priests_src/scripts/core/emergency_production_executor_0514.lua` — emergency production fallback return movement failure handling.
- `tech-priests_src/scripts/core/consecration_executor_0515.lua` — consecration walk-to-target failure handling and claim release.
- `tech-priests_src/scripts/core/repair_executor_0516.lua` — repair walk-to-target failure handling and reservation release.
- `tech-priests_src/scripts/core/combat_repair_doctrine_0517.lua` — combat repair cluster cleanup on repair executor failure.
- `tech-priests_src/scripts/core/crafting_executor.lua` — return-to-station crafting movement failure handling.
- `tech-priests_src/scripts/core/construction_planner.lua` — construction return-to-station and move-to-site failure handling.
- `tech-priests_src/scripts/core/logistics_fetch_executor_0527.lua` — known-source logistics movement failure handling.
- `tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua` — machine logistics movement failure handling and known-source fetch timeout.
- `tech-priests_src/scripts/core/ground_item_hoover_0529.lua` — ground-item pickup/storage movement failure handling.

## Stage 5 audit/check tools

- `tools/check_stage5_movement_failure_batch.py` — marker and balance check for movement-failure repairs.
- `tools/check_stage5_proximity_gates.py` — marker check that movement-driven executors retain close-enough range gates before work/deposit/placement phases.
- `tools/check_movement_enforcement_void_boundary_0765.py` — canonical boundary check proving `movement_controller` owns public/ground enforcement, `0630` is broker-only, and `0566` remains inert.
- `tools/check_stage5_smoke_bundle.py` — combined runner for the Stage 5 movement-failure, proximity-gate, canonical movement/Void boundary, and package-readiness checks.

## Smoke-test packaging rule

Keep `tech-priests_src/info.json` at the protected `0.1.672` baseline during Stage 5 smoke validation. The smoke-check bundle and a local Factorio smoke load are narrow validation evidence only; neither authorizes a version bump, release-candidate classification, or publication.
