# GitHub File Manifest

Refreshed for the Stage 5 movement-failure, proximity-gate, and Void Priest movement-authority repair batch.

## Runtime movement authority files

- `tech-priests_src/scripts/core/movement_controller.lua` — canonical ground Tech-Priest movement controller and request/status surface.
- `tech-priests_src/scripts/core/movement_enforcement_0566.lua` — ground movement enforcement governor; rejects stale/far ground movement and now installs the Void movement authority after the ground wrapper exists.
- `tech-priests_src/scripts/core/void_movement_authority_0630.lua` — separate Void Priest same-surface collisionless movement authority, request/status/service loop, and Void-only movement global wrappers.

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
- `tools/check_void_movement_authority_0630.py` — marker check for the separate Void Movement Authority and its installation hook.
- `tools/check_stage5_smoke_bundle.py` — combined runner for the Stage 5 movement-failure, proximity-gate, and Void movement checkers.

## Smoke-test packaging rule

Do not bump `tech-priests_src/info.json` until the Stage 5 smoke-check bundle passes locally and the generated smoke package loads in Factorio.
