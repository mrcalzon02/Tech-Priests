# Tech Priests Runtime Script Organization

Current documentation baseline: `0.1.530`.

Runtime behavior is being moved out of `control.lua` into `scripts/core/` modules. New behavior should be added as a module, not as another long block in `control.lua`.

## Core modules

- `core/task_scheduler.lua` — scheduler/action-pipeline scaffold; owns intent vocabulary, not physical execution.
- `core/action_state_arbiter_0488.lua` — single visible-action arbiter; decides what family may visibly act now.
- `core/action_stack_contract_0507.lua` — authoritative action-stack contract and duplicate-claim diagnostics for legacy cleanup.

- `core/scheduler_contract_0512.lua` — stabilizes active order-queue intent with current-order leases, passive refresh blocking, same-family duplicate folding, strategic cascade cooldown, and `/tp-scheduler-0512` diagnostics.
- `core/movement_recovery_authority_0508.lua` — passive recovery / physical direct-acquisition movement lease authority; keeps valid priests travelling instead of being recalled by legacy ensure callers.
- `core/supply_resolver.lua` — legacy-preserving supply resolver shim.
- `core/combat_safety.lua` — canonical hostile-target/friendly-fire safety gate.
- `core/subordinate_scheduler.lua` — subordinate-aware assignment layer.
- `core/work_visuals.lua` — visible overhead task/progress feedback.
- `core/startup_provisioning.lua` — freeplay starter stations and startup player-awareness hooks.
- `core/inventory_target_safety.lua` — blocks direct player/character inventory scan targets.
- `core/resource_doctrine.lua` — fallback chain for known resources, mineables, recipes, and primitive sources.
- `core/station_catalog.lua` — radar catalog, ownership tags, known resources, catalog GUI.
- `core/emergency_cascade.lua` — senior-to-subordinate emergency cascade.
- `core/gui_bus.lua` — GUI event dispatch consolidation.
- `core/network_visuals.lua` — placement radius, hierarchy lines, known-resource markers, preview repinning.
- `core/radar_afterglow.lua` — radar sweep afterglow sprite.
- `core/chatter.lua` — background/direct priest chatter.
- `core/glow_boost.lua` — extra priest/Magos glow visuals.
- `core/acquisition_repair.lua` — acquisition kick/repair helpers.
- `core/acquisition_unstick.lua` — stuck-priest acquisition watchdog/commands.
- `core/acquisition_executor.lua` — direct mining/gathering executor.
- `core/crafting_executor.lua` — station-side crafting executor and progress feedback.
- `core/conversation_audit.lua` — technology/doctrine conversation diagnostics.
- `core/construction_planner.lua` — placeable inventory scanning and basic construction placement.
- `core/emergency_facility_doctrine.lua` — Martian emergency facility detection/tagging/use.
- `core/logistics_fetch_executor_0526.lua` — dispatcher-priority physical fetch executor for known storage items; priests must reach nearby containers/machines before the item is credited to station inventory.

## Legacy/support modules

- `planetary-magos-special-names.lua` — reserved Magos names and player-recognition lines.
- `annoyatron.lua` — Annoyatron aliases, nuisance items, messages.
- `idle_priest_conversations.lua` — legacy priest conversation pools.
- `idle_player_conversations.lua` — legacy player conversation pools.
- `magos_ratio_planning.lua` — Planetary Magos ratio planning.
- `magos_station_expansion.lua` — older Magos expansion behavior.
- `placement_safety_and_detritus.lua` — older placement/detritus support.
- `defense_perimeter.lua` — older defense perimeter behavior.
- `resource_expansion.lua` — older resource expansion behavior.

See `docs/technical-organization.md` for the current behavior map.


## 0.1.510 Dispatcher Migration

`scripts/core/single_dispatcher_0510.lua` is the first runtime owner for the new scheduler/action/executor chain. It currently owns direct acquisition and station-craft executor pulses, gates legacy `tick_pair` for those migrated action families, and exposes `/tp-dispatcher-0510` plus emergency diagnostics rows. Future behavior families should be migrated into this dispatcher model one at a time.

- `core/movement_bounds_contract_0511.lua` — bounds direct acquisition travel, decommissions the old 0.1.273 one-second direct-gather hard-kick, and walks overleashed priests home instead of letting commander units wander into the wilds.

## 0.1.513 direct acquisition executor

`scripts/core/direct_acquisition_executor_0513.lua` is the dispatcher-owned direct acquisition phase executor. It should be the only code family allowed to physically execute hand mining/scavenging once a direct acquisition task exists. It owns the visible phases `walk-to-target`, `work-target`, `return-for-craft`, and `complete`, and blocks legacy 0273/0312/0315 direct service functions while dispatcher-owned direct work is active.

Use `/tp-direct-acquisition-0513` and `PAIR-DUMP-0468 DIRECT-ACQUISITION-0513` when debugging this behavior family.
- `core/emergency_production_executor_0514.lua` — dispatcher-owned emergency production phase executor; checks station inventory, prefers Martian emergency facilities, collects machine output, blocks legacy desperation craft as a controller, and uses timed station fallback only after machine production cannot proceed.


## 0.1.515 consecration executor

`scripts/core/consecration_executor_0515.lua` owns Tech-Priest machine-spirit maintenance. It wraps the old legacy sanctify function, routes scheduler consecration claims into dispatcher-owned phases, consumes station-supplied consecration capsule items only after the priest is in range and the rite timer completes, and records priest/station source context through `tech_priests_0515_apply_consecration_from_source`.

- `core/repair_executor_0516.lua` — dispatcher-owned repair executor; target reservation, full repair, timed repair-pack use, and diagnostics.

## 0.1.517 combat repair doctrine

`scripts/core/combat_repair_doctrine_0517.lua` is the dispatcher-recognized tactical repair layer for defended walls. It scans for damaged wall/gate clusters under enemy pressure, confirms active/loaded turret or priest cover, reserves clusters to spread priests along the line, and then calls `repair_executor_0516` as the physical repair leaf. It exposes `/tp-combat-repair-0517` and `PAIR-DUMP-0468 COMBAT-REPAIR-0517`.



## 0.1.518 Movement Cadence Contract

`scripts/core/movement_cadence_contract_0518.lua` wraps the existing movement request API. It holds lower-priority retarget churn behind active dispatcher-owned movement leases, preserves urgent combat/retreat/recovery interrupts, and exposes `/tp-movement-cadence-0518` plus pair-dump diagnostics. It is not a replacement movement controller.
- `core/logistics_construction_contract_0519.lua` — physical pickup/source-access gate and dispatcher-prioritized construction/expansion deferral contract.

## 0.1.520 portrait assignment

`scripts/core/portrait_assignment_0520.lua` owns persistent portrait IDs for Cogitator/Tech-Priest pairs. It is a UI identity/reporting module only. It should not submit orders or move/repair/consecrate/build/fight.


## 0.1.521 Work State tab cleanup

`station_work_inventory.lua` now renders Writ Queue, Forge Plan, and Command Tree as structured tables and registers `/tp-workstate-tabs-0521`. This is a read-only GUI organization pass.

## 0.1.522 Work-State diegetic polish

The fifth UI pass keeps the 0.1.521 structured tables intact and only polishes Work-State captions/buttons into consistent in-universe slate/reliquary wording. `/tp-workstate-polish-0522` opens the selected pair's polished Cogitator Work-State Reliquary. This pass is UI wording only and must not alter behavior ownership.


## 0.1.523 Machine-Spirit ledger traits

`scripts/core/consecration/machine_trait_taxonomy_0524.lua` provides the registry-driven, machine-type-aware trait/name taxonomy for sanctifiable machines only. `scripts/core/consecration/machine_traits_0523.lua` adds persistent machine-spirit traits, quirks, flaws, milestone rolls, positive/negative crafting-history space, and category-aware naming on consecration records. These modules are intentionally read/record/display oriented: they observe completed operation events from the consecration decay/history path and do not create work, alter recipes, or change priest behavior.

Diagnostic command:

```text
/tp-machine-spirit-ledger-0523
```

- `core/priest_identity_background_0525.lua` — expanded persistent Tech-Priest personal dossiers for Work-State UI identity. UI/lore state only; does not submit orders or alter behavior. Command: `/tp-priest-identity-0525`.


### 0.1.527 logistics fetch executor

`scripts/core/logistics_fetch_executor_0527.lua` is the dispatcher-priority universal fetch layer. It replaces the ammo-shaped 0.1.526 known-storage fetch path with exact-item physical pickup for any item requested by the current order or emergency/logistics state.

### 0.1.528 machine logistics fulfillment

`scripts/core/logistics_machine_fulfillment_0528.lua` is the dispatcher-priority machine-service layer for non-automated local assemblers and furnaces. It can clear machine outputs, route detritus/scrap toward internally tagged waste boxes, supply burner fuel, and supply item ingredients from station-known inventory. When a required ingredient is not in station stock, it expresses an exact item need so `logistics_fetch_executor_0527` can physically fetch the source before raw acquisition or emergency crafting. Command: `/tp-machine-logistics-0528`.

### 0.1.529 unified scan beams and ground hoover

`scripts/core/scan_beam_controller_0529.lua` is the final-loaded visual wrapper for old scan/mining/combat line calls. It centralizes beam colors and smoke behavior so direct mining, inventory scanning, combat firing, repair/consecration hints, and logistics scans no longer grow separate line systems. It exposes `/tp-scan-beams-0529` and `PAIR-DUMP-0468 SCAN-BEAMS-0529`.

`scripts/core/ground_item_hoover_0529.lua` is a dispatcher-owned loose-ground item cleanup executor. It physically walks priests to dropped item stacks, then routes the picked-up stack to station inventory or retention storage. If no storage exists and a chest item is available, it places a station-adjacent retention chest; otherwise it blocks without spilling items back to the ground. It exposes `/tp-ground-hoover-0529` and `PAIR-DUMP-0468 GROUND-HOOVER-0529`.

- `core/conversation_voice_0530.lua` — deterministic non-lexical voice-bark audio reporter for visible chatter/typewriter lines and technology-selection bark playback.


### 0.1.531 operational/mechanical sounds

- `scripts/core/operational_sounds_0531.lua` is an audio-only reporter for uploaded operational sound assets.
- It plays occasional deterministic gas-mask breathing on priests, mechanical UI click cues for Tech-Priest GUI interactions, and machine start/wind-down cues for custom emergency machines.
- It exposes `/tp-operational-sounds-0531` with status and sound-test subcommands.
- It must remain read-only with respect to behavior state; no orders, movement, work completion, inventory transfer, or dispatcher claims belong here.


### 0.1.533 placeholder audio integration

- `scripts/core/placeholder_audio_0533.lua` integrates the first functional placeholder audio manifest as an audio-only reporter.
- It routes meaningful transition cues through `sound_manager_0475`: repair, sanctification/oil, scan, emergency entry, station link established/broken, low sanctity warnings, detritus clogging, GUI panel open/close, tab changes, and portrait selection.
- It observes machine sanctity/detritus records and pair validity, but does not create work, alter orders, move priests, complete tasks, transfer inventory, or claim action families.
- Diagnostic command: `/tp-placeholder-audio-0533`.

- `core/stone_cache_filter_0534.lua` — runtime inventory steward for named stone-cache variants; ejects wrong item stacks without owning behavior or logistics work.
