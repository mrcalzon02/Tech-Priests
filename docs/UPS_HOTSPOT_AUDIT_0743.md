# UPS Hotspot Audit 0743

**Status:** static source audit; requires clean-world profiler confirmation

## Summary

- `periodic_route_count`: 510
- `frequent_route_count_le_30`: 24
- `active_frequent_route_count_le_30`: 17
- `scan_site_count`: 127
- `risky_scan_count`: 68
- `rewrite_site_count`: 916

### Route Kinds
| kind | count |
| --- | --- |
| broker | 125 |
| registry | 199 |
| script | 38 |
| script-fallback | 148 |

### Scan Risk Kinds
| risk | count |
| --- | --- |
| bounded-or-filtered | 38 |
| broad-area | 18 |
| dynamic-filter-helper | 21 |
| global-filtered | 7 |
| global-or-unbounded | 1 |
| unbounded-filtered | 20 |
| wide-force-area | 22 |

### Rewrite Kinds
| kind | count |
| --- | --- |
| active-order-write | 86 |
| actual-task-status-write | 11 |
| direct-set-command | 72 |
| direct-task-write | 60 |
| emergency-craft-write | 58 |
| leaf-task-write | 13 |
| logistics-fetch-write | 4 |
| movement-request | 20 |
| movement-request-state | 28 |
| movement-request-write | 32 |
| pair-mode-write | 352 |
| pair-target-write | 177 |
| route-command | 3 |

## Frequent Wake Routes

| interval | kind | authority | category | budget | site |
| --- | --- | --- | --- | --- | --- |
| 1 | registry | ? | ? |  | tech-priests_src/scripts/generated/control_legacy_part_008.lua:1367 |
| 10 | registry | ? | ? |  | tech-priests_src/scripts/generated/control_legacy_part_004.lua:294 |
| 11 | registry | behavior_mutex_0466 | behavior |  | tech-priests_src/scripts/core/behavior_mutex_0466.lua:273 |
| 11 | script-fallback | ? | ? |  | tech-priests_src/scripts/core/behavior_mutex_0466.lua:275 |
| 13 | registry | combat_magos_movement_authority_0472 | combat |  | tech-priests_src/scripts/core/combat_magos_movement_authority_0472.lua:426 |
| 13 | script-fallback | ? | ? |  | tech-priests_src/scripts/core/combat_magos_movement_authority_0472.lua:428 |
| 17 | registry | crafting_executor | crafting |  | tech-priests_src/scripts/core/crafting_executor.lua:322 |
| 17 | script-fallback | ? | ? |  | tech-priests_src/scripts/core/crafting_executor.lua:324 |
| 17 | registry | overhead-text-authority-0473 | visuals |  | tech-priests_src/scripts/core/overhead_text_authority_0473.lua:187 |
| 17 | script-fallback | ? | ? |  | tech-priests_src/scripts/core/overhead_text_authority_0473.lua:189 |
| 17 | registry | ? | ? |  | tech-priests_src/scripts/generated/control_legacy_part_018.lua:1331 |
| 17 | registry | ? | ? |  | tech-priests_src/scripts/generated/control_legacy_part_018.lua:1372 |
| 17 | registry | ? | ? |  | tech-priests_src/scripts/generated/control_legacy_part_019.lua:142 |
| 23 | broker | item_family_logistics_0702 | machine-logistics | 8 | tech-priests_src/scripts/core/item_family_logistics_0702.lua:520 |
| 29 | broker | energy_family_logistics_0707 | machine-logistics | 8 | tech-priests_src/scripts/core/energy_family_logistics_0707.lua:857 |
| 29 | broker | energy_family_logistics_0707 | machine-logistics | 8 | tech-priests_src/scripts/core/energy_family_logistics_0707.lua:858 |
| 29 | registry | ? | ? |  | tech-priests_src/scripts/generated/control_legacy_part_018.lua:611 |
| 30 | registry | acquisition_executor | acquisition |  | tech-priests_src/scripts/core/acquisition_executor.lua:358 |
| 30 | script-fallback | ? | ? |  | tech-priests_src/scripts/core/acquisition_executor.lua:360 |
| 30 | registry | conclave_center_0559 | gui |  | tech-priests_src/scripts/core/conclave_center_0558.lua:1270 |
| 30 | registry | movement_cadence_contract_0518 | movement |  | tech-priests_src/scripts/core/movement_cadence_contract_0518.lua:317 |
| 30 | script-fallback | ? | ? |  | tech-priests_src/scripts/core/movement_cadence_contract_0518.lua:319 |
| 30 | registry | workstate_gui_radar_recovery_0465 | gui |  | tech-priests_src/scripts/core/workstate_gui_radar_recovery_0465.lua:93 |
| 30 | script-fallback | ? | ? |  | tech-priests_src/scripts/core/workstate_gui_radar_recovery_0465.lua:95 |

## Risky Scan Sites

| risk | type | name | force | limit | site |
| --- | --- | --- | --- | --- | --- |
| broad-area | no | no | no | no | tech-priests_src/scripts/core/conclave_center_0558.lua:1063 |
| broad-area | no | no | no | no | tech-priests_src/scripts/core/emergency_facility_doctrine.lua:219 |
| broad-area | no | no | no | no | tech-priests_src/scripts/core/fluid_connection_planner_0691.lua:237 |
| broad-area | no | no | no | no | tech-priests_src/scripts/core/fluid_output_connection_planner_0696.lua:123 |
| broad-area | no | no | no | no | tech-priests_src/scripts/core/fluid_turret_connection_planner_0719.lua:267 |
| broad-area | no | no | no | no | tech-priests_src/scripts/core/infrastructure_first_governor_0640.lua:232 |
| broad-area | no | no | no | yes | tech-priests_src/scripts/core/station_catalog.lua:585 |
| broad-area | no | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_003.lua:780 |
| broad-area | no | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_010.lua:1299 |
| broad-area | no | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_011.lua:331 |
| broad-area | no | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_012.lua:514 |
| broad-area | no | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_014.lua:114 |
| broad-area | no | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_017.lua:156 |
| broad-area | no | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_019.lua:254 |
| broad-area | no | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_019.lua:531 |
| broad-area | no | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_020.lua:1083 |
| broad-area | no | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_020.lua:1134 |
| broad-area | no | no | no | no | tech-priests_src/scripts/placement_safety_and_detritus.lua:115 |
| global-filtered | no | yes | no | no | tech-priests_src/scripts/core/consecration/registry.lua:154 |
| global-filtered | yes | no | no | no | tech-priests_src/scripts/core/consecration/registry.lua:160 |
| global-filtered | no | yes | no | no | tech-priests_src/scripts/core/stone_cache_filter_0534.lua:62 |
| global-filtered | no | yes | no | no | tech-priests_src/scripts/generated/control_legacy_part_002.lua:367 |
| global-filtered | no | yes | no | no | tech-priests_src/scripts/generated/control_legacy_part_002.lua:522 |
| global-filtered | no | yes | no | no | tech-priests_src/scripts/generated/control_legacy_part_003.lua:174 |
| global-filtered | no | yes | no | no | tech-priests_src/scripts/generated/control_legacy_part_013.lua:1318 |
| global-or-unbounded | no | no | no | no | tech-priests_src/scripts/core/stone_cache_filter_0534.lua:59 |
| unbounded-filtered | no | yes | yes | no | tech-priests_src/scripts/core/consecration_executor_0515.lua:287 |
| unbounded-filtered | no | yes | yes | no | tech-priests_src/scripts/core/construction_bootstrap_ghost_planner_0645.lua:72 |
| unbounded-filtered | yes | no | yes | no | tech-priests_src/scripts/core/emergency_supply_reserve_0497.lua:229 |
| unbounded-filtered | yes | no | no | no | tech-priests_src/scripts/core/infrastructure_first_governor_0640.lua:194 |
| unbounded-filtered | yes | no | yes | no | tech-priests_src/scripts/core/inventory_deposit_safety_0638.lua:108 |
| unbounded-filtered | yes | no | yes | no | tech-priests_src/scripts/core/inventory_steward.lua:206 |
| unbounded-filtered | yes | yes | no | no | tech-priests_src/scripts/core/master_infrastructure_plan_0644.lua:62 |
| unbounded-filtered | no | yes | yes | no | tech-priests_src/scripts/core/pair_link_hardening_0495.lua:113 |
| unbounded-filtered | no | yes | yes | no | tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua:155 |
| unbounded-filtered | no | yes | yes | no | tech-priests_src/scripts/core/proxy_turret_alignment.lua:116 |
| unbounded-filtered | yes | no | yes | no | tech-priests_src/scripts/defense_perimeter.lua:590 |
| unbounded-filtered | yes | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_002.lua:489 |
| unbounded-filtered | yes | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_003.lua:767 |
| unbounded-filtered | no | yes | yes | no | tech-priests_src/scripts/generated/control_legacy_part_003.lua:1074 |
| unbounded-filtered | no | yes | yes | no | tech-priests_src/scripts/generated/control_legacy_part_004.lua:368 |
| unbounded-filtered | yes | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_005.lua:477 |
| unbounded-filtered | yes | no | yes | no | tech-priests_src/scripts/generated/control_legacy_part_014.lua:829 |
| unbounded-filtered | yes | no | no | no | tech-priests_src/scripts/generated/control_legacy_part_018.lua:951 |
| unbounded-filtered | no | yes | yes | no | tech-priests_src/scripts/magos_ratio_planning.lua:274 |
| unbounded-filtered | no | yes | yes | no | tech-priests_src/scripts/magos_ratio_planning.lua:289 |
| wide-force-area | no | no | yes | no | tech-priests_src/scripts/core/bootstrap_runtime.lua:418 |
| wide-force-area | no | no | yes | no | tech-priests_src/scripts/core/conclave_center_0558.lua:448 |
| wide-force-area | no | no | yes | no | tech-priests_src/scripts/core/master_infrastructure_plan_0644.lua:77 |
| wide-force-area | no | no | yes | no | tech-priests_src/scripts/core/work_queue_authority.lua:393 |

## Top Movement/Task Rewrite Files

| file | rewrite sites |
| --- | --- |
| tech-priests_src/scripts/generated/control_legacy_part_003.lua | 59 |
| tech-priests_src/scripts/generated/control_legacy_part_005.lua | 44 |
| tech-priests_src/scripts/generated/control_legacy_part_016.lua | 32 |
| tech-priests_src/scripts/core/direct_acquisition_executor_0513.lua | 31 |
| tech-priests_src/scripts/generated/control_legacy_part_018.lua | 31 |
| tech-priests_src/scripts/generated/control_legacy_part_004.lua | 29 |
| tech-priests_src/scripts/core/movement_controller.lua | 27 |
| tech-priests_src/scripts/generated/control_legacy_part_015.lua | 25 |
| tech-priests_src/scripts/generated/control_legacy_part_009.lua | 23 |
| tech-priests_src/scripts/generated/control_legacy_part_019.lua | 20 |
| tech-priests_src/scripts/generated/control_legacy_part_008.lua | 19 |
| tech-priests_src/scripts/core/repair_executor_integrity_0673.lua | 18 |
| tech-priests_src/scripts/core/repair_executor_0516.lua | 17 |
| tech-priests_src/scripts/core/machine_logistics_integrity_0682.lua | 16 |
| tech-priests_src/scripts/core/priest_vanish_guard_0502.lua | 15 |
| tech-priests_src/scripts/core/consecration_executor_0515.lua | 14 |
| tech-priests_src/scripts/core/order_queue_0469.lua | 14 |
| tech-priests_src/scripts/core/acquisition_executor.lua | 13 |
| tech-priests_src/scripts/core/behavior_execution_doctrine_0505.lua | 12 |
| tech-priests_src/scripts/core/logistics_fetch_executor_0527.lua | 12 |

## Interpretation

- Treat frequent routes as wake-pressure suspects, not proven bottlenecks.
- Treat broad-area and global-or-unbounded scans as first-class UPS risks.
- Treat files with many movement/task rewrites as churn-risk authorities that must agree with leaf-truth and movement-controller ownership.
- Confirm all suspected costs with `tech-priests-debug-mode=profiler` and `/tp-runtime-report` in a clean new-world save.

