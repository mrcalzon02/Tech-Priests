## 0.1.530 — Conversation Voice Bark Audio

## 0.1.531 — Operational/mechanical sound pass

- Imported the uploaded machine/UI/respirator sound set and converted MP3 assets to OGG under `sound/operation/0531/`.
- Registered machine start/running/wind-down, cathonk, clak, key-clatter, clicker, gas-mask breathing, snap, and typing sound prototypes.
- Added `scripts/core/operational_sounds_0531.lua`, an audio-only reporter for occasional deterministic Tech-Priest respirator barks, custom emergency-machine placement/removal cues, and Tech-Priest GUI click sounds.
- Added prototype-side working sounds to Martian emergency machines so the custom machine running sound can be heard while the machines operate.
- Updated BIOS boot sound candidates to prefer uploaded key-clatter/typing/machine-start sounds before fallback base-game utility sounds.
- Routed new cues through `sound_manager_0475` where possible and added sound-manager candidates for repair, consecration, deployment, inventory transfer, conversation, and idle scan cues.
- Added `/tp-operational-sounds-0531` diagnostics and tests.


- Imported the supplied Tech-Priest `blahblah` voice clips and converted them from MP3 to OGG for Factorio sound loading.
- Added `scripts/core/conversation_voice_0530.lua` as an audio reporter that plays deterministic non-lexical barks when visible conversation/typewriter lines begin.
- Added a dedicated technology-selection bark using the supplied `Blahblahtech` clip via `on_research_started` when available, with a low-cadence current-research poll as fallback.
- Registered voice sounds in `prototypes/sound.lua` with deterministic slow/normal/fast prototype variants and routed playback through the existing 0.1.475 sound manager when possible.
- Added `/tp-conversation-voice-0530` diagnostics and test commands.
- This pass is audio-only and does not alter behavior, scheduler, dispatcher, movement, logistics, scan-beam, repair, consecration, construction, or combat authority.

## 0.1.529 — Unified Scan Beams / Ground Hoover / Cogitator Inventory Space

- Added `scripts/core/scan_beam_controller_0529.lua` as the final-loaded visual authority for old emergency scan lines and direct-mining/combat laser calls. The wrapper centralizes beam colors by action family, preserves action-arbiter safety checks, and emits smoke for resource/tree/boulder mining or world-damage targets.
- Added `scripts/core/ground_item_hoover_0529.lua` as a dispatcher-owned loose-ground item cleanup executor. Priests physically walk to dropped item stacks, pick them up, and route them to station or retention storage; if no storage is available, the carried stack is held/blocked rather than dumped back onto the ground.
- Added station-adjacent retention-box placement support when the station has a chest item available and no remembered/open retention storage can accept the carried item.
- Increased Cogitator Station inventories by +2 working slots: Junior 4, Intermediate 5, Senior 6, Planetary Magos 7, Void 7.
- Added diagnostics `/tp-scan-beams-0529` and `/tp-ground-hoover-0529`.

## 0.1.528 — Machine Logistics Fulfillment

- Added `scripts/core/logistics_machine_fulfillment_0528.lua` as a dispatcher-priority logistics executor for non-automated local assemblers and furnaces.
- The module checks unautomated machines inside the station service radius for output clearing, detritus/waste removal, low fuel, and missing item ingredients.
- Machine output is removed only after the priest reaches the machine; carried output is then physically moved to station/retention storage, while `mechanical-detritus`/scrap are routed toward an internally tagged waste box when available.
- Fuel and ingredient supply are physical machine-service actions: station inventory is consumed only as the priest services the target machine.
- If a recipe ingredient is missing from station stock, 0.1.528 expresses an exact item need so `logistics_fetch_executor_0527` can fetch it from known cataloged sources before raw mining or emergency crafting.
- Adjacent inserter/loader/belt/pipe/pump arrangements mark a machine as automated; those machines are skipped by default so Tech-Priests do not fight an existing production line.
- Added `/tp-machine-logistics-0528` diagnostics and pair-dump rows.

## 0.1.527 — Universal Known-Resource Fetch

- Added `scripts/core/logistics_fetch_executor_0527.lua`.
- Upgraded the 0.1.526 known-storage fetch path from ammo-shaped logistics into universal requested-item fetch.
- The dispatcher now checks cataloged source inventories and loose ground stacks for any current requested item before falling through to raw direct acquisition, primitive fallback, or emergency crafting.
- Added request-count handling so a station with partial stock can still send the priest to fetch the remainder.
- Added `/tp-logistics-fetch-0527` diagnostics.
- This pass preserves the physical-access doctrine: items do not enter Cogitator Station inventory until the priest reaches the source.

# 0.1.526 — UI Logistics Polish / Physical Known-Storage Fetch

This pass fixed several UI and logistics issues observed after the identity/background and Machine-Spirit ledger work. The Cogitator Work-State Identity Reliquary now uses wrapped key/value rows so expanded priest dossiers do not overrun the right side of the panel. The boot sequence now includes generated green skull-gear spinner frames in an upper-right signum panel. The Auspex Ledger and Doctrine Web tabs received another structural pass so they present summary plaques and tables rather than long text blocks.

Machine-Spirit State Ledger now appends the machine-spirit name and sacred machine ID at the beginning/header of the ledger and presents its data through internal tabs: Spirit Seal, Traits / Flaws, and Rite History. The panel remains a separate screen GUI opened by the machine GUI event rather than an actual injected vanilla GUI tab.

Runtime logistics received `scripts/core/logistics_fetch_executor_0526.lua`. Known nearby storage sources from the station catalog now take priority before raw direct acquisition: if the station needs ammunition and a scanned nearby container has ammunition, the priest should walk to that container and withdraw/deposit it physically before mining resources or crafting ammunition. Emergency reserve balancing no longer silently pulls directly from loose nearby containers; those containers are treated as physical fetch sources.

No standalone audit document was added.

# 0.1.524 — Machine-Spirit Trait Taxonomy


## 0.1.525 — Tech-Priest Background Variety Pass

- Added `scripts/core/priest_identity_background_0525.lua` as a UI/lore identity module for persistent Tech-Priest personal dossiers.
- Replaced the old tiny repeated background pools with much wider deterministic pools for forge/planet origin, world type, induction path, former assignment, service theater, current status, augmentation, likes, dislikes, quirks, biography, plan, and goal.
- Existing profiles are upgraded in place through the same persistent `priest_profile_0367` memory slot for compatibility, while the generator records `identity_background_version_0525`.
- Added `/tp-priest-identity-0525` with selected/all inspection and selected/all reroll support.
- Updated the Work-State Identity Reliquary and Tech-Priest personal dossier to surface the richer identity fields.
- Behavior-neutral pass: no dispatcher, scheduler, movement, repair, combat, consecration, construction, logistics, portrait, or machine-spirit behavior changes.

- Added `scripts/core/consecration/machine_trait_taxonomy_0524.lua` as a registry-driven machine-spirit trait taxonomy.
- The taxonomy uses the existing `is_consecration_target(entity)` gate before classifying machines, so belts, inserters, pipes, walls, and other non-sanctifiable entities do not receive marks or names.
- Added exact-name and entity-type classification for sanctifiable machines: crafting machines, fluid/chemical machines, furnaces, mining drills, labs, rocket silos, boilers, generators, reactors, roboports, vehicles, spider vehicles, locomotives, and a generic sanctifiable fallback.
- Replaced the generic 0.1.523 milestone pools with machine-category-aware trait, quirk, flaw, and name pools while keeping all effects lore-only until a future authority-specific gameplay pass deliberately wires them.
- Updated the Machine-Spirit State Ledger to show machine caste/category and each mark's implementation status.
- Added `/tp-machine-trait-taxonomy-0524` for selected-machine eligibility/category diagnostics.
- This pass is ledger/state taxonomy only. It does not change sanctity decay math, priest movement, dispatcher ownership, scheduler behavior, repair, consecration application, construction, logistics, combat, or emergency production.

# 0.1.523 — Machine-Spirit State Ledger / Trait Scaffold

- Added `scripts/core/consecration/machine_traits_0523.lua` as a machine-ledger-only module. It watches completed operation milestones and annotates the existing consecration record with persistent virtues, quirks, flaws, and positive/negative/neutral crafting-history marks.
- Added milestone rolls at powers of ten: 1, 10, 100, 1,000, 10,000, 100,000, and 1,000,000 completed operations.
- Added placeholder machine naming: once a machine has two total marks, it gains the placeholder name `Machine` until a future name-table generator is implemented.
- Expanded the consecration history GUI into the **Machine-Spirit State Ledger**, including a **Machine-Spirit Character Ledger** with sections for virtues/auspicious quirks, flaws/complaints, and neutral temperament marks.
- Added `/tp-machine-spirit-ledger-0523` for inspecting selected machine trait/flaw state.
- This pass is ledger/state scaffolding only. It does not change sanctity decay math, priest movement, dispatcher ownership, scheduler behavior, repair, construction, logistics, combat, or emergency production.

# 0.1.521 — Work State Deep Tab Cleanup

## 0.1.522 — Fifth-pass diegetic Work-State polish

- Replaced the remaining plain Work State frame/tab/button captions with consistent in-universe Work-State Reliquary, slate, auspex, writ, forge, and command-lattice language.
- Polished the Known Resources/Auspex Ledger, Writ Reliquary, Forge Slate, Command Lattice, and Machine-Spirit Sanctity Reliquary captions.
- Added `/tp-workstate-polish-0522` as a lightweight command to open the selected pair's polished Work-State Reliquary.
- Preserved the structured table organization from 0.1.521 and made no dispatcher, scheduler, movement, combat, repair, consecration, construction, logistics, portrait, or emergency-production behavior changes.


Fourth pass UI cleanup for the Cogitator Work State panel. Writ Queue, Forge Plan, and Command Tree now use structured tables instead of prose-heavy diagnostic lists. Writ Queue separates current, pending, and recent writ seals with columns for seal, rite, tithe, state, priority, age/lease, and mandate. Forge Plan now has structured current/pending/history tables plus explicit technology-gate and placement-doctrine rows. Command Tree now separates self/superior chain, direct subordinates, and peer communion into tables with socket, current-writ, and priest-signal columns.

Added `/tp-workstate-tabs-0521` to inspect the selected station's structured tab data and open the Work State panel directly to Writ Queue. This pass is UI/data organization only and should not change dispatcher, scheduler, movement, construction, combat, repair, consecration, or logistics behavior.


## 0.1.520 — Portrait assignment pass

- Added `prototypes/portrait_cells_0520.lua` to expose cropped GUI sprite cells from the existing portrait sheets.
- Added `scripts/core/portrait_assignment_0520.lua` to bind persistent portrait IDs to Cogitator/Tech-Priest pairs by station unit.
- Updated the Work State Identity Reliquary to display the assigned portrait cell, portrait seal, and source sheet/cell.
- Added `/tp-portrait-assignment-0520` diagnostics and `PAIR-DUMP-0468 PORTRAIT-ASSIGNMENT-0520` output.
- This is a UI/identity pass only and does not change dispatcher behavior.


## 0.1.519 — Logistics / Construction Physical-Access Contract

Added `scripts/core/logistics_construction_contract_0519.lua`. The new layer makes loose-item pickup and scavenge withdrawal physical: a Tech-Priest must walk to the ground stack, container, machine, or other source before legacy withdrawal/deposit helpers may move the item into Cogitator Station work inventory. Construction is now dispatcher-prioritized when a placeable item already exists in station-known inventory, and construction tasks create a ghost marker before the priest physically places the item.

The station-expansion ghost planner is wrapped so it defers range-expansion ghosts when the required lower-tier Cogitator Station item is neither present in station-known inventory nor producible by currently unlocked recipes. This prevents planning structures the current resource/production chain cannot actually supply. Added `/tp-logistics-construction-0519` and `PAIR-DUMP-0468 LOGISTICS-CONSTRUCTION-0519` diagnostics.

# Development History

## 0.1.518 — Movement Cadence / Task-Churn Contract

- Added `scripts/core/movement_cadence_contract_0518.lua`.
- Added a movement lease wrapper around the existing 0.1.418/0.1.452 movement controller so dispatcher-owned long walks are not constantly replaced by lower-priority scheduler, GUI, legacy, or no-item refreshes.
- Tuned movement-controller retarget holding and command cadence without creating a new movement authority. The 0.1.518 module preserves urgent combat, retreat, and recovery interrupts.
- Raised non-void Tech-Priest movement speeds modestly in prototype and data-final-fixes hardening so real physical repair/consecration/acquisition phases are observable instead of painfully slow.
- Added local consecration travel bounds by priest tier and a no-consecration-item retry cooldown to reduce consecration task churn while the station lacks oil/litany/appeasement supplies.
- Added `/tp-movement-cadence-0518` and `PAIR-DUMP-0468 MOVEMENT-CADENCE-0518` diagnostics.
- Updated current testing goals, behavior order documentation, authority-refactor continuity notes, script README, changelog, and package version.

## 0.1.517 — Combat Repair Doctrine

- Added `scripts/core/combat_repair_doctrine_0517.lua`.
- Added dispatcher pre-classification for the `combat-repair` action family so defended wall repair can be chosen before ordinary combat fire when the tactical situation supports it.
- Combat repair only selects damaged wall/gate targets under enemy pressure when loaded/active turrets or nearby combat-active priests provide cover.
- Tactical repair routes through `repair_executor_0516` as the physical leaf executor, preserving full-repair behavior, timed repair-pack use, and target movement while adding combat-specific wall-cluster reservations.
- Added cover-loss abort behavior so if turret/priest cover disappears, the priest stops combat repair instead of continuing ordinary repair while exposed.
- Added `/tp-combat-repair-0517` and `PAIR-DUMP-0468 COMBAT-REPAIR-0517` diagnostics.
- Updated dispatcher diagnostics, current testing goals, behavior order documentation, authority-refactor continuity notes, script README, changelog, and package version.

## 0.1.516 — Repair Executor Migration

- Added `scripts/core/repair_executor_0516.lua`.
- Migrated repair into dispatcher-owned phase execution: choose damaged target, reserve target, walk to repair range, spend timed repair ticks, consume repair packs, and continue until full repair.
- Removed the old repair-pack efficiency behavior from the active priest repair path; priests should no longer refuse to repair small damage just because a repair pack would not be fully efficient.
- Added target reservations and cooldowns so multiple priests should spread across damaged structures instead of dogpiling one wall section.
- Wrapped legacy `repair_target` and `Scheduler.try_repair` so old callers adopt the 0.1.516 executor rather than directly controlling repair.
- Updated the single dispatcher to own the repair action family when 0.1.516 is enabled.
- Added `/tp-repair-executor-0516` diagnostics and `PAIR-DUMP-0468 REPAIR-EXECUTOR-0516`.

# 0.1.515 — Consecration Executor Migration

- Added `scripts/core/consecration_executor_0515.lua` as the dispatcher-owned Tech-Priest consecration executor.
- Legacy `sanctify_target_with_priest` is now wrapped so old callers adopt the new phase executor instead of directly consuming station inventory and instantly raising sanctity.
- The task scheduler consecration hook is wrapped so it submits/assigns consecration work instead of executing the old station rite directly.
- Updated `single_dispatcher_0510` so the consecration action family is now dispatcher-owned and calls the 0.1.515 executor.
- Added a shared `tech_priests_0515_apply_consecration_from_source` API that restores sanctity without a player object and records priest/station/source context in the machine ledger.
- The machine ledger now stores `last_consecration_priest_unit_0515`, `last_consecration_station_unit_0515`, `last_consecration_station_label_0515`, `last_consecration_method_0515`, and `last_consecration_order_0515` fields for priest-performed rites.
- The history GUI now shows priest/station/method/order source details when a priest rite has restored a machine.
- Consecration now uses visible phases: target selection, walk-to-target, prepare capsule rite, throw/apply capsule, cooldown, and complete.
- Added per-priest and per-machine cooldowns and ratio thresholds so priests do not endlessly top off one favorite machine when other behavior should proceed.
- Added `/tp-consecration-executor-0515` and `PAIR-DUMP-0468 CONSECRATION-EXECUTOR-0515` diagnostics.
- Updated current testing goals, behavior-order documentation, authority-refactor continuity notes, script README, changelog, and package version.

# 0.1.513 - Direct acquisition executor migration

## 0.1.514 — Emergency Production Executor Migration

- Added `scripts/core/emergency_production_executor_0514.lua`.
- Emergency production is now dispatcher-owned for station-craft/emergency-craft work.
- The executor checks station inventory, collects output from owned Martian emergency facilities, calls emergency facility doctrine only as a dispatcher leaf helper, waits for machine production, and only then uses timed station fallback crafting if materials are ready and machine production is unavailable.
- Wrapped `emergency_facility_doctrine.service_pair/service_all` so periodic facility pulses are suppressed unless the call is dispatcher/manual/command-owned.
- Wrapped legacy `handle_emergency_desperation_craft` and `finish_emergency_desperation_craft` so dispatcher-owned emergency production is not silently completed by older desperation craft controllers.
- Updated `single_dispatcher_0510` so station-craft family first attempts the 0.1.514 emergency production executor before falling back to the older crafting executor.
- Added `/tp-emergency-production-0514` and `PAIR-DUMP-0468 EMERGENCY-PRODUCTION-0514` diagnostics.
- Updated current testing goals and authority-refactor continuity notes.


- Added `scripts/core/direct_acquisition_executor_0513.lua` as the dispatcher-owned direct acquisition executor.
- Direct acquisition now has explicit phases: no task, need target, walk to target, work target, return for craft, return to station, and complete.
- The dispatcher now prefers the 0.1.513 executor before falling back to the older acquisition executor.
- Legacy direct service functions `tech_priests_0273_service_direct_current`, `tech_priests_0312_service_direct_current`, and `tech_priests_0315_service_direct_current` are blocked while dispatcher-owned direct work is active.
- Independent acquisition executor calls are wrapped so they route through the 0.1.513 phase machine when enabled.
- The 0.1.510 legacy gate now gates direct acquisition only when a real direct task exists, allowing unrelated acquisition/scavenge legacy helpers to continue until their own executor pass.
- Added `/tp-direct-acquisition-0513` and `PAIR-DUMP-0468 DIRECT-ACQUISITION-0513` diagnostics.
- Updated current testing goals, behavior order documentation, authority-refactor continuity notes, script README, changelog, and package version.

# 0.1.512 - Scheduler contract / stable intent pass

- Added `scripts/core/scheduler_contract_0512.lua` to stabilize order-queue intent after the dispatcher and movement-bounds migration.
- Active orders now receive a short lease so visible travel/acquisition/station-craft work is not cleared by passive refresh churn while the dispatcher/executor chain is still working.
- Same-family duplicate submissions fold into or hold behind the current order instead of creating repeated active/pending churn.
- Passive mouse-over, radar, overview, and Work State refreshes are blocked while active work exists.
- Planetary Magos emergency cascade/planning pulses are cooldown-gated while the leader is already working.
- Added `/tp-scheduler-0512` and `PAIR-DUMP-0468 SCHEDULER-CONTRACT-0512` diagnostics.
- Updated current testing goals, behavior order documentation, authority-refactor continuity notes, script README, changelog, and package version.

# 0.1.510 - First dispatcher migration / authority refactor kickoff

## 0.1.511 - Movement bounds contract / direct-gather hard-kick retirement

Live 0.1.510 testing showed the dispatcher migration improving overall behavior, but a Planetary Magos could still run far from the station while in emergency gather/direct acquisition state. Diagnostics showed `tech-priests 0.1.510` loaded, a Planetary Magos at roughly 47 tiles from its station during `emergency-gathering`, and continued legacy `assignment worker active` / `direct gather target` pressure from the old 0.1.273 direct-gather stack.

Added `scripts/core/movement_bounds_contract_0511.lua`. The new layer bounds direct acquisition target selection and movement requests by rank/tier, with a conservative Planetary Magos direct-acquisition radius and hard leash. Far direct targets are rejected before travel, current direct pointers are cleared when they violate the contract, and overleashed priests are ordered to walk back toward their Cogitator Station rather than being teleported.

The old generated 0.1.273 one-second direct-gather hard-kick route in `control_legacy_part_016.lua` is decommissioned through the runtime event registry so it cannot keep selecting or servicing direct targets behind the dispatcher. This is part of converting legacy direct acquisition from a controller into leaf/helper behavior.

Added `/tp-movement-bounds-0511` and `PAIR-DUMP-0468 MOVEMENT-BOUNDS-0511` diagnostics showing station-to-priest distance, direct radius, hard leash, current direct target, target distance, rejected targets, overleash returns, and whether the old 61-tick direct-gather route was removed. Updated current testing goals for the movement bounds pass. No standalone build-history document was added.


Started the legacy behavior cleanup as a controlled architecture migration rather than a destructive generated-fragment removal. Added `scripts/core/single_dispatcher_0510.lua` as the first per-pair dispatcher that runs the intended sequence: lifecycle identity repair, `order_queue_0469` intent tick, `action_state_arbiter_0488` classification, and one executor call. For this first pass the dispatcher owns physical direct acquisition and timed station craft.

Direct acquisition now routes through the dispatcher to `acquisition_executor.service_pair`; independent acquisition executor pulses are suppressed unless called manually or by the dispatcher. Timed station craft now routes through the dispatcher to `crafting_executor.before_legacy_handle`; independent craft pulses are likewise suppressed. Legacy `tick_pair` is gated only for dispatcher-owned direct-acquisition/station-craft families so those old fragments cannot keep reasserting competing behavior while the new executor owns the priest. Combat, repair, consecration, construction, and emergency-machine production remain future migration targets and are not yet fully dispatcher-owned.

Added `docs/AUTHORITY_REFACTOR_CONTINUITY.md` as the stable refactor plan requested by the user. Updated `docs/STANDARDS_AND_PRACTICES.md` with an explicit authority-refactor continuity rule, because the user requested continuity instructions for future chains of changes. Updated the behavior order document and current testing goals for 0.1.510. Added `/tp-dispatcher-0510` and `PAIR-DUMP-0468 SINGLE-DISPATCHER-0510` diagnostics.

# 0.1.509 - Unit survival and behavior-stack cleanup pass two

- Confirmed from the 0.1.508 live log that `tech-priests 0.1.508` loaded, but a Senior Tech-Priest pair entered a repeated invalid/respawn conveyor: `missing-priest-recovery-0503` and `rescue-respawn-created-0503` repeatedly replaced priests while the paired station/order stayed valid.
- Hardened every Tech-Priest unit prototype with explicit `ai_settings.destroy_when_commands_fail = false`, `allow_try_return_to_spawner = false`, `do_separation = false`, and `join_attacks = false` in both `prototypes/entity.lua` and `data-final-fixes.lua`. This prevents inherited biter/compilatron AI settings from deleting scripted worker units after repeated failed movement commands.
- Added `scripts/core/behavior_stack_cleanup_0509.lua`, loaded after 0.1.508, to decommission the old 0.1.502/0.1.504 station-side direct-acquisition executor as an executor while retaining its diagnostics.
- Updated `scripts/core/priest_vanish_guard_0502.lua` so station-side direct acquisition, far-movement suppression, and priest tethering default off and fall through to the original physical executor when disabled.
- Reasserted the physical direct-acquisition chain: if the priest is not adjacent, request/hold movement; if the priest is adjacent, allow the original physical executor to mine/work over time. No remote station-side deposit should occur.
- Added UI/order refresh debounce for mouse-over, radar scan, and overview-style refreshes while active work is already leased, so debug observation does not reset scan/craft due ticks and cause task churn.
- Added `/tp-behavior-cleanup-0509` plus `PAIR-DUMP-0468 BEHAVIOR-STACK-CLEANUP-0509` diagnostics.

# 0.1.507 - Legacy behavior ownership cleanup, pass one

- Began the transition from stacked legacy behavior fragments toward one coherent action stack.
- Clarified the runtime distinction between scheduler intent, single-action arbitration, movement, executor completion, and visual/audio reporting.
- Added `scripts/core/action_stack_contract_0507.lua`, `/tp-action-stack-0507`, and `PAIR-DUMP-0468 ACTION-STACK-0507` diagnostics.
- Made `acquisition_executor.lua`, `acquisition_repair.lua`, `acquisition_unstick.lua`, and `crafting_executor.lua` single-install runtime-registry services instead of repeatedly replacing or stacking raw `script.on_nth_tick` handlers.
- Removed the duplicate acquisition executor pulse from `workstate_gui_radar_recovery_0465.lua`; Work State now owns GUI/BIOS refresh only, while direct acquisition belongs to `acquisition_executor.lua`.
- Added lightweight 0.1.507 action-claim diagnostics so future passes can find behavior families that still claim the same priest in the same tick.

# 0.1.505 - behavior execution doctrine clamp
## 0.1.506 - Mobility/recovery contract

- Live logs after the recovery restoration showed repeated `recovery-teleport-0503 ... ok=false` calls while a valid priest existed. This meant the recovery layer was still treating ordinary outbound work as a recall fault.
- Added `scripts/core/mobility_recovery_contract_0506.lua`, loaded after 0.1.505, to suppress recovery teleports for valid same-surface priests and clear stale recall pressure instead of yanking priests home.
- Replaced station-side direct acquisition/tether behavior with physical direct travel: the priest must walk to the target, and direct mining/smoke/damage/deposit can proceed only once adjacent.
- Soft-disabled 0.1.502 station-side tether/direct acquisition and the 0.1.505 remote blocker by default; 0.1.505 facility-first/timed-craft rules remain active.
- Added `/tp-mobility-0506` and `PAIR-DUMP-0468 MOBILITY-RECOVERY-0506` diagnostics.


- Added `scripts/core/behavior_execution_doctrine_0505.lua`, loaded last after the 0.1.502-0.1.504 vanish/recovery guards.
- Added `docs/BEHAVIOR_ORDER_OF_OPERATIONS.md` as the stable behavior contract requested during the behavior-tree review.
- Blocks far-away direct world mining: rocks, trees, and resources may not smoke, take mining damage, lose amount, or deposit output unless the visible priest is physically adjacent or a built emergency facility owns the work.
- Keeps far native-unit emergency acquisition movement quarantined while preventing the quarantine path from becoming remote mining-by-station.
- Gates ordinary emergency hand-crafting behind facility doctrine. Emergency-device bootstrap items may still be timed station-crafted so the Martian facility chain can start, but normal gears/plates/ammo/repair packs are routed toward inventory, scavenge, and emergency machines first.
- Raises fallback craft timing to a visible minimum and adds per-task 0.1.505 timed station craft state.
- Throttles repeated failed recovery teleport calls so collision/blocked-anchor failures do not become their own log/task storm.
- Adds `/tp-behavior-0505` and `PAIR-DUMP-0468 BEHAVIOR-EXECUTION-0505` diagnostics.

# 0.1.504 - emergency anti-slam throttle for station-side acquisition quarantine

- Live testing of 0.1.503 showed a total freeze after placing a Senior Cogitator Station. The pasted Factorio log was saturated by repeated `far-acquisition-movement-suppressed-0502` and `station-side-direct-working-0502` messages for station 133/priest 134 against the same copper-ore target in the same timestamp range.
- Root cause: the 0.1.502 station-side quarantine performed station-side work directly from the movement suppression hook. After 0.1.503 restored watchdog/recovery callers, multiple authority layers could ask for the same far acquisition movement in one tick, causing repeated station-side work, visuals, target softening, and logging.
- Updated `scripts/core/priest_vanish_guard_0502.lua` for 0.1.504 with a hard per-station service throttle, no station-side work from the movement hook, default-off noisy station-side/movement logs, and circuit-breaker counters for suppression storms.
- Kept the actual vanish-prevention doctrine unchanged: far native-unit emergency acquisition movement remains quarantined and station-side direct acquisition remains the safe diagnostic path.

# 0.1.503 - recovery safety restoration after station-side vanish fix

- Kept the 0.1.502 station-side direct acquisition quarantine active because live testing indicated it stopped the visible Tech-Priest vanish loop.
- Added `scripts/core/priest_recovery_safety_0503.lua` to reopen legitimate safety systems without reopening arbitrary priest destruction.
- Restored missing-priest rescue/rebind/respawn, recall teleports, pair-link rescue, direct-mining safety rescue, and watchdog roots disabled by the 0.1.499/0.1.500 quarantine passes.
- Re-enabled authorized belt-immunity mobility replacement by swapping the old priest prototype to the belt-immune prototype only when the force has the belt-immunity rite, while preserving station cleanup/destruction discipline.
- Increased baseline Tech-Priest movement speed from 0.026 to 0.055 and belt-immune movement speed from 0.032 to 0.065 so non-immune priests can overpower ordinary belt drift and immune priests feel properly upgraded.
- Added `/tp-priest-recovery-0503` and a `PAIR-DUMP-0468 PRIEST-RECOVERY-SAFETY-0503` diagnostic block.

# Tech Priests Development History — 0.1.481

## 0.1.502 - Station-side emergency acquisition tether

- The 0.1.501 live test still produced visible priest vanishing during early emergency direct acquisition. The new logs showed a valid station and repeated controlled respawn/rebind attempts for priest units 91, 256, 261, 267, and 268, while no authorized priest-destruction path fired. The final dump had a valid replacement priest, but the current order was still `paused-missing-priest`.
- Added `scripts/core/priest_vanish_guard_0502.lua`, loaded after 0.1.501. This pass treats the direct emergency gather/mining loop as the active fault zone and stops sending the visible native unit far from its Cogitator Station for tree/rock/resource targets.
- Wrapped the direct acquisition executor plus the legacy 0273/0312/0315 direct-current services so direct emergency acquisition is performed station-side for this diagnostic build. The priest remains tethered near the station while the source is worked/deposited through the station inventory path.
- Wrapped movement requests after 0.1.501 so far-away non-combat acquisition/direct-gather movement is suppressed and converted into station-side service instead of issuing native unit travel commands.
- Added recovery cleanup for `paused-missing-priest`: when a valid priest exists again, the 0498 quarantine marker and current order pause state are cleared, and the current order is restored to active.
- Added `/tp-priest-vanish-0502` plus emergency diagnostics rows under `PAIR-DUMP-0468 PRIEST-VANISH-GUARD-0502` to expose station-side, movement-suppression, deposit, missing, and unpause counters.

## 0.1.501 - Priest vanish guard and late direct-mining seal

- Added `scripts/core/priest_vanish_guard_0501.lua`, loaded after the 0.1.500 lifecycle seal. The 0.1.500 test log showed a valid station/pair with an invalid priest, but no lifecycle-seal authorized/blocked destroy record and no removal event. This means the next pass must protect late direct-mining/action paths and keep the pair recoverable for live testing.
- Wrapped the late 0273/0312/0315 direct-mining service stack with a final protected-target gate. Direct current/candidate state is cleared if it ever points at a Tech-Priest, Cogitator Station, character/unit, hidden proxy/cache, or same-force owned simple entity. Direct mining outputs are normalized to the actual world source rather than allowing transmutation.
- Neutralized non-combat movement distraction for acquisition/direct-gather movement requests so ordinary work orders use `defines.distraction.none` instead of allowing native unit AI to side-track the priest during resource recovery.
- Re-enabled only controlled missing-priest recovery after logging. The previous 0.1.500 seal intentionally held missing priests for diagnosis; 0.1.501 now first attempts nearby orphan rebind, then controlled respawn through the lower pre-0499 chain, then a minimal station-local spawn if necessary. Priest destruction remains blocked except for Cogitator Station cleanup.
- Added `/tp-priest-vanish-0501` and emergency diagnostics dump lines under `PAIR-DUMP-0468 PRIEST-VANISH-GUARD-0501` for the next live test.

This file replaces the previous spread of audit, rebase, testing, standards, overlay, and archive documents. It is a compact index of the historical material that was removed from the public package during the 0.1.481 cleanup pass.
## Cleanup decision
The public mod package should carry active runtime assets and a small number of useful planning notes, not every intermediate audit and recovery artifact generated during development. Old patch overlays, local build helpers, experimental font packaging notes, archived Lua fragments, repeated audit JSON, and redundant testing folders were removed.
## Historical document index
- `ALT_WRIT_VISUAL_STABILITY_0.1.474.md` — Tech Priests 0.1.474 — Alt-Writ and Visual Stability Pass
- `BEHAVIOR_DECISION_PATH_0.1.419.md` — Behavior Decision Path — 0.1.419
- `BEHAVIOR_FLOW_MAP_0.1.432.md` — Active Behavior Flow Map 0.1.432
- `BEHAVIOR_FLOW_MAP_0.1.435.md` — Active Behavior Flow Map 0.1.432
- `COMBAT_AND_MAGOS_AUTHORITY_0.1.472.md` — Tech Priests 0.1.472 — Combat and Magos Authority Pass
- `COMMAND_HIERARCHY_0.1.480.md` — Tech Priests 0.1.480 Command Hierarchy Pass
- `CONSECRATION_DETRITUS_POINTER_AUDIT_0.1.417.md` — Consecration / Mechanical Detritus Pointer Audit — 0.1.417
- `CONSECRATION_HISTORY_GUI_0.1.422.md` — Consecration History GUI — 0.1.422
- `CONSECRATION_SETTINGS_ATTACHMENT_AND_DECAY_VISIBILITY_0.1.447.md` — Tech Priests 0.1.447 Consecration Settings Attachment and Decay Visibility Pass
- `CONSECRATION_TRACKER_REPAIR_AUDIT_0.1.446.md` — Tech Priests 0.1.446 Consecration Tracker Repair Audit
- `CONTROL_CLEANUP_REPORT_0.1.421.md` — Control Cleanup Report — 0.1.421
- `CONTROL_DELETION_ROADMAP_0.1.431.md` — Control Cleanup Deletion Roadmap — 0.1.431
- `CONTROL_DELETION_VERIFICATION_PASS_0.1.436.md` — Final Deletion Verification Pass — 0.1.436
- `CONTROL_DUPLICATE_AUTHORITY_MAP_0.1.428.md` — Control Duplicate Authority Map — 0.1.428
- `CONTROL_DUPLICATE_BEHAVIOR_PURGE_0.1.428.md` — Control Duplicate Behavior Family Purge — 0.1.428
- `CONTROL_EFFICIENCY_AND_LOGIC_AUDIT_0.1.435.md` — Control Efficiency and Logic Audit — Tech Priests 0.1.435
- `CONTROL_EVENT_MAP_0.1.424.md` — Tech Priests Runtime Event Map 0.1.424
- `CONTROL_EVENT_MAP_0.1.425.md` — Control Event Map — 0.1.425
- `CONTROL_EVENT_SWITCHBOARD_0.1.425.md` — Control Event Switchboard — 0.1.425
- `CONTROL_FULL_DELETION_AUDIT_0.1.431.md` — Control Full Deletion Audit — 0.1.431
- `CONTROL_FUNCTION_MAP_0.1.435.md` — Control.lua Residual Authority Audit 0.1.432
- `CONTROL_GUI_AUTHORITY_MAP_0.1.427.md` — Control GUI Authority Map — 0.1.427
- `CONTROL_LIFECYCLE_AUTHORITY_MAP_0.1.426.md` — Control Lifecycle Authority Map — 0.1.426
- `CONTROL_LOCAL_LIMIT_RELIEF_0.1.437.md` — Control.lua Local-Limit Relief — 0.1.437
- `CONTROL_LUA_DANGER_MAP_0.1.421.md` — control.lua Danger Map — 0.1.421
- `CONTROL_REFACTOR_ROADMAP_0.1.424.md` — Control Refactor Roadmap — 0.1.424 onward
- `CONTROL_RELOCATION_CLEANUP_0.1.432.md` — Control Relocation Cleanup 0.1.432
- `CONTROL_RESIDUAL_AUTHORITY_AUDIT_0.1.432.md` — Control.lua Residual Authority Audit 0.1.432
- `CONTROL_SPLIT_LOCAL_LIMIT_RELIEF_0.1.438.md` — Control Lua Split / Local Limit Relief 0.1.438
- `CONTROL_SWITCHBOARD_CLEANUP_0.1.424.md` — Control Switchboard Cleanup — 0.1.424
- `CONTROL_WRAPPER_DELETION_LEDGER_0.1.436.md` — Control Wrapper Deletion Ledger — Tech Priests 0.1.436
- `CONTROL_WRAPPER_DELETION_LEDGER_0.1.437.md` — Control Wrapper Deletion Ledger Continuation — 0.1.437
- `CURRENT_TESTING_GOALS.md` — 0.1.475 unified sound manager verification
- `DEBUG_COMMAND_MAP_0.1.424.md` — Tech Priests Debug Command Map 0.1.424
- `DEVELOPMENT_STANDARDS_AND_BEST_PRACTICES.md` — Tech Priests — Development Standards and Best Practices
- `ENTROPIC_EXTRACTOR_ANIMATION_EXPANSION_0.1.450.md` — Entropic Extractor Animation Expansion — 0.1.450
- `FILE_INDEX.md` — 0.1.436 Added Files
- `GRAPHICS_REINTEGRATION_0.1.449.md` — Tech Priests 0.1.449 Graphics Reintegration Pass
- `GUI_ROUTER_EXTRACTION_0.1.427.md` — GUI Router Extraction — 0.1.427
- `HOVER_LINK_RADIUS_MOVEMENT_PASS_0.1.444.md` — Hover Link, Radius, and Movement Pass — 0.1.444
- `LIFECYCLE_AND_POINT_BLANK_COMBAT_0.1.423.md` — Lifecycle and Point-Blank Combat Repair — 0.1.423
- `LOAD_AND_RUNTIME_STABILITY_0.1.452.md` — Tech Priests 0.1.452 — load blocker and runtime stability pass
- `LOAD_VISUAL_GEOMETRY_CONSECRATION_PASS_0.1.453.md` — Tech Priests 0.1.453 — Load, Visual Geometry, and Consecration Pass
- `LOCALE_SECTION_MERGE_0.1.456.md` — Locale Section Merge — 0.1.456
- `MASTER_BEHAVIOR_TREE.md` — Tech Priests Master Behavior Tree
- `MODULE_BREAKUP_PLAN_0.1.420.md` — Module Break-Up Plan — 0.1.420
- `MOVEMENT_CONTROLLER_AUDIT_0.1.417.md` — Ground Tech-Priest Movement Audit — 0.1.417
- `MOVEMENT_CONTROLLER_AUDIT_0.1.418.md` — Tech Priests 0.1.418 Movement Controller Audit
- `MOVEMENT_CONTROLLER_AUDIT_0.1.419.md` — Movement Controller Audit — 0.1.419
- `MOVEMENT_POSITION_AUTHORITY_SCAN_0.1.444.md` — Movement and Position Authority Scan — 0.1.444
- `ORDER_QUEUE_RESOURCE_WRITS_0.1.469.md` — Tech Priests 0.1.469 — Order Queue and Resource Writ Pass
- `ORPHAN_DEAD_END_CANDIDATES_0.1.432.md` — Orphan / Dead-End Candidate Report 0.1.432
- `ORPHAN_DEAD_END_CANDIDATES_0.1.435.md` — Orphan / Dead-End Candidate Report 0.1.435
- `PACKAGING_ROOT_FIX_0.1.458.md` — Tech Priests 0.1.458 - Packaging Root Fix
- `PAIRDUMP_WRITE_FILE_HOTFIX_0.1.462.md` — Tech Priests 0.1.462 - Pair Dump Write File Hotfix
- `PAIR_DUMP_AND_BIOS_STABILITY_0.1.460.md` — Tech Priests 0.1.460 - Pair Dump and BIOS Stability Pass
- `PAIR_DUMP_COMMAND_EXECUTIVE_FIX_0.1.457.md` — Tech Priests 0.1.457 - Pair Dump Command Executive Fix
- `PAIR_LIFECYCLE_EXTRACTION_0.1.426.md` — Pair Lifecycle Extraction — 0.1.426
- `PATCH_HISTORY_ERROR_FIX_SUMMARY.md` — 0.1.436 Wrapper Deletion Verification
- `PERSISTENT_LINK_AND_MOVEMENT_GOVERNOR_0.1.443.md` — Tech Priests 0.1.443 Persistent Link and Movement Governor Pass
- `PLATFORM_PROXY_MOVEMENT_AUTHORITY_0.1.430.md` — Platform / Proxy Movement Authority — 0.1.430
- `RADAR_BOOT_CONCLAVE_PAIRDUMP_PASS_0.1.461.md` — Tech Priests 0.1.461 - Radar / Boot / Conclave / Pair Dump Pass
- `RADAR_WORKSTATE_RESTORE_0.1.465.md` — Tech Priests 0.1.465 Work State / radar art restoration
- `RADIUS_OVERLAY_KILL_SWITCH_0.1.463.md` — Radius Overlay Kill Switch - 0.1.463
- `RADIUS_OVERLAY_RESTORE_SCOPE_0.1.464.md` — Tech Priests 0.1.464 radius overlay scope correction
- `RUNTIME_GUI_AND_PAIR_SHAPE_FIX_0.1.441.md` — Tech Priests 0.1.441 - Forward Runtime Stability and GUI Legibility Pass
- `RUNTIME_MOVEMENT_AND_WORKSTATE_FIX_0.1.442.md` — Runtime Movement and Workstate Fix — 0.1.442
- `RUNTIME_PROTOTYPE_ACCESS_FIX_0.1.440.md` — Runtime Prototype Access Fix — 0.1.440
- `SCHEDULER_OWNERSHIP_MAP.md` — Scheduler Ownership Map
- `SCRIPT_FUNCTION_REVIEW_0.1.420.md` — Tech Priests Script Function Review — 0.1.420
- `TASK_TRANSITION_GOVERNOR_0.1.445.md` — Tech Priests 0.1.445 — Task Transition Governor
- `THRUSTER_GEOMETRY_AND_FUTURE_ROADMAP_0.1.451.md` — Tech Priests 0.1.451 — Thruster Geometry and Future Roadmap Notes
- `THRUSTER_PERFORMANCE_BALANCE_0.1.455.md` — Tech Priests 0.1.455 - Thruster Performance Balance
- `THRUSTER_PIPE_VISUAL_GATE_FIX_0.1.439.md` — Tech Priests 0.1.439 — Thruster Pipe Visual Gate Fix
- `THRUSTER_SPLIT_AND_HYDROGEN_GEOMETRY_0.1.454.md` — Tech Priests 0.1.454 - Thruster Split and Hydrogen Geometry Correction
- `VISUAL_DOCTRINE_MOVEMENT_CONSECRATION_REPAIR_0.1.448.md` — Tech Priests 0.1.448 Visual / Doctrine / Movement / Consecration Repair Pass
- `VOID_SEALED_CARGO_GACHA_DOCTRINE_0.1.415.md` — Void-Sealed Cargo Gacha Doctrine — 0.1.415
- `WORKSTATE_BOOT_AND_STATUS_DISPLAY_0.1.459.md` — Tech Priests 0.1.459 - Work State Boot Display and Status Authority
- `WORKSTATE_TABS_AND_TASK_LIFECYCLE_0.1.478.md` — Tech Priests 0.1.478 — Work State panes, consecration source ledger, and task lifecycle authority
- `archive/lifecycle_reimprint_guard_0.1.426.lua.txt` — -- scripts/core/lifecycle_reimprint_guard.lua
- `archive/movement_hammer_0.1.417.lua.txt` — -- scripts/core/movement_hammer.lua
- `audit/combat_movement_leftovers_0.1.429.md` — Combat and Movement Leftovers Audit — 0.1.429
- `audit/control_deletion_candidates_0.1.432.md` — Control Deletion Candidate Audit
- `audit/control_deletion_candidates_0.1.435.md` — Control Deletion Candidate Audit
- `audit/control_deletion_candidates_after_0.1.431.md` — Control Deletion Candidate Audit
- `audit/duplicate_behavior_families_0.1.428.md` — Duplicate Behavior Family Audit — 0.1.428
- `audit/duplicate_behavior_families_0.1.431.md` — Duplicate Behavior Family Audit — 0.1.428
- `audit/duplicate_behavior_families_0.1.432.md` — Duplicate Behavior Family Audit — 0.1.428
- `audit/duplicate_behavior_families_0.1.435.md` — Duplicate Behavior Family Audit — 0.1.435
- `audit/lua_script_audit.md` — Tech Priests Lua Script Audit
- `audit/special_movement_authority_0.1.430.md` — Special Movement Authority Audit — 0.1.430
- `audit_0.1.461/lua_script_audit.md` — Tech Priests Lua Script Audit
- `graphics-asset-mapping.md` — Tech Priests Graphics Asset Mapping — 0.1.435
- `rebase/CONTROL_LUA_CONSECRATION_MODULARIZATION_MAP_0.1.347.md` — Control.lua Consecration Modularization Map — 0.1.347
- `rebase/FRESH_CONVERSATION_REBASE_PROMPT.md` — Fresh Conversation Prompt — Tech Priests Current Development
- `rebase/README_START_HERE.txt` — Tech Priests Current Handoff / Rebase Notes
- `rebase/REBASE_EVALUATION_CURRENT.md` — Tech Priests — Rebase Document Evaluation
- `standards/README.md` — Standards Folder
- `state-of-mod-master-plan.md` — Tech Priests Master Plan — 0.1.471 Diegetic GUI Doctrine and Consecration Ledger Repair
- `technical-organization.md` — Technical Organization — 0.1.436 Wrapper Deletion Gate
- `testing/CURRENT_TESTING_GOALS.md` — Current Testing Goals - Tech Priests 0.1.466

## Preserved planning extracts


---

## state-of-mod-master-plan.md

# Tech Priests Master Plan — 0.1.471 Diegetic GUI Doctrine and Consecration Ledger Repair

0.1.471 is a focused interface-trust pass after the order-queue/writ authority work. The immediate defect was raw rich-text bracket markup escaping into the Machine-Spirit Consecration Ledger purity bar. The larger design correction is that Tech Priests GUI text should read as an in-world Cogitator/reliquary display, not as developer patch notes or placeholder menu scaffolding.

## 0.1.471 deliverables

- Replaced the consecration ledger rich-text bar string with styled GUI bar segments so invalid color tags cannot surface as literal text.
- Moved the ledger away from auto-center behavior and toward side docking based on the inspected machine's position relative to the player.
- Converted the ledger controls and labels into diegetic phrasing: Rite of Re-Inspection, Seal Reliquary, Sacred designation, Machine-spirit purity, corruption/scarring language, and Consecration augury.
- Started cleaning visible non-diegetic GUI copy from Conclave and task-memory screens, especially wording such as folded into, placeholder, deferred, and display/social state.

## Standing diegetic GUI doctrine

All player-facing Tech Priests menus should be treated as diegetic instruments: Cogitator screens, consecration reliquaries, auspex slates, command lecterns, noospheric ledgers, or doctrinal cartographs. GUI copy should not describe itself as a placeholder, a merged tab, a folded view, a social menu, or an unfinished developer feature. When a system is not yet fully built, the visible text should phrase that absence as an in-world limitation, unsanctioned rite, missing cartograph, unawakened ledger, pending senior mandate, or awaiting consecration.

## Future custom GUI backing roadmap

A later visual pass should create custom diegetic backing art and reusable GUI skins for major Tech Priests interfaces: Cogitator Dictator Work State, Known Resources, Conclave Auspex, Machine-Spirit Consecration Ledger, pair/order queue diagnostics, and future doctrine cartographs. These should eventually look like actual Mechanicus screens rather than plain Factorio panels: dark cogitator glass, scanline/CRT or phosphor effects, brass/iron borders, warning glyph strips, subtle static, and screen-specific background plates.

---

# Tech Priests Master Plan — 0.1.461 Radar / Boot / Conclave / Pair Dump Recovery

0.1.461 is a narrow visual and diagnostic recovery pass before returning to behavior-tree work. The live test showed that pair creation was alive, but the radar hover display, BIOS boot text, chatter timing, and Doctrine Heat Map/Conclave split were creating noise during validation.

## 0.1.461 deliverables

- Softened the radar hover overlay and sweep so the radius behaves like gentle illumination rather than a solid green flickering disk.
- Removed rich-text markup from the Cogitator BIOS boot stream so `[color]` and `[font]` tags cannot surface as literal boot text.
- Increased BIOS checkpoint sound volume and slowed refresh/stage timing for calmer presentation.
- Moved chatter chat-log output behind the visible typewriter completion point.
- Added pair-dump fallbacks for opened inventory-like objects and recently opened Work State panels.
- Folded doctrine population/certainty heat bars into Conclave Statistics.
- Removed the active separate Doctrine Heat Map GUI path for now; legacy command redirects to Conclave Statistics.

## Deferred roadmap note

The literal local doctrine-adherence heat map/gradient overlay remains desirable, but it is deferred until behavior trees are working again. The next major development pass should return to a clear behavior authority stack: attack enemies in station range first, repair damaged entities second, then sanctify/logistics work third.

---

# Tech Priests Master Plan — 0.1.436 Wrapper Deletion Verification

0.1.436 begins the final verification pass for deleting old `control.lua` wrapper-chain bodies. This revision does not remove runtime behavior. It converts the older authority maps into a function-by-function deletion ledger so future cleanup patches can distinguish live captured bodies from truly obsolete overwritten wrappers.

## 0.1.436 deliverables

- Added `tools/audit_wrapper_deletion_ledger.py`.
- Added `docs/CONTROL_WRAPPER_DELETION_LEDGER_0.1.436.md`.
- Added `docs/audit/control_wrapper_deletion_ledger_0.1.436.json`.
- Confirmed the current audit still sees 158 duplicate function-name families and 488 participating definitions.
- Confirmed 62 active legacy captures still exist and must not be deleted blindly.

## 0.1.436 next validation

Run the full load test first. Then use the ledger to inspect only the four probable small delegate candidates. Leave scheduler, lifecycle, acquisition, movement, and emergency-operation bodies intact until live behavior tests prove the named authority modules own those behaviors completely.

---

# Tech Priests Master Plan — 0.1.435 Entropic Fuel Isolation and Cleanup Audit

0.1.435 is a conservative pre-testing cleanup pass. It fixes the Entropic Extractor fuel-category boundary before the first live behavior tests of the recent restructuring, and it refreshes the static code maps so the next deletion/refactor decisions are based on the actual current package rather than stale wrapper assumptions.

## 0.1.435 deliverables

- Changed the Blackstone fuel category to `entropic-extractor-blackstone` so raw Blackstone cannot be burned by ordinary fuel consumers.
- Kept the Entropic Extractor output behavior from 0.1.434: platform-only burner-generator, one fuel slot, `1PJ` chunks, and capped `2MW` output.
- Removed a harmless duplicate-key block in the emergency planetside entity set.
- Re-ran the mod-wide Lua script audit, behavior-flow map, duplicate behavior family audit, orphan/dead-end candidate report, and control deletion candidate audit.
- Added `docs/CONTROL_EFFICIENCY_AND_LOGIC_AUDIT_0.1.435.md` as the current review standard for the upcoming live tests.

## 0.1.435 next validation

Test fuel isolation first, then behavior authority. Confirm the Entropic Extractor accepts only Blackstone chunks and that no ordinary burner accepts them. After that, place stations by rank and exercise the scheduler, movement, acquisition, station-pair recovery, repair, consecration, combat fallback, GUI routing, and platform-specific movement before deleting any wrapper family from `control.lua`.

---

# Tech Priests Master Plan — 0.1.433 Conservative Graphics Integration

0.1.433 performs a graphics-only integration pass for the supplied Tech Priests asset bundle. The purpose is to mechanically assign the clearest assets to existing icons/entities while leaving uncertain or mechanically risky assignments staged rather than forcing them into live prototypes. Runtime behavior, scheduler authority, movement, combat, acquisition, lifecycle, and consecration code are not intended to change in this revision.

## 0.1.433 deliverables

- Replaced clear item/fluid icons across the ritual maintenance chain, Blackstone chain, orbital propellant chain, las-carbine/hot-shot cell, and void cargo chain.
- Added item-specific Blackstone icons for asteroid chunks, fragments, and slabs.
- Routed Citadel Manufactureo through a simple idle/active assembling-machine graphics set.
- Routed Entropic Extractor through active lightning SpriteVariations while staging its idle sprite for future prototype conversion.
- Added Hydrogen, Thetazine, and Void-Fusion thruster sheets through Factorio's thruster graphics set animation/idle-animation path.
- Added `docs/graphics-asset-mapping.md` as the current conservative mapping note.
- Explicitly excluded `gothic_mechanical_engine_in_isolation.png` and `hydrogen_thruster_idle_v1.png` from all mapping paths.

## 0.1.433 next validation

The immediate validation priority is visual loading and platform placement with Space Age enabled. If any thruster art is misaligned, correct scale/shift/dimensions first; do not alter fluid boxes, performance, scheduler behavior, or platform movement as part of the graphics repair.

---

# Tech Priests Master Plan — 0.1.432 Behavior Flow Mapping and Control Relocation Cleanup

0.1.432 establishes a fresh map of the mod's actual runtime behavior flow after the control cleanup sequence from 0.1.421 through 0.1.431. This pass does not attempt a broad destructive purge. It verifies what is currently reachable, records the domains and authority patterns still present, and removes old in-file refactor tombstones from `control.lua` now that dedicated support structures exist.

## 0.1.432 deliverables

- `tools/audit_behavior_flow.py` maps runtime/data Lua files, require reachability, domain ownership, duplicate functions, orphan candidates, authority-pattern leftovers, and require cycles.
- `docs/BEHAVIOR_FLOW_MAP_0.1.432.md` records the active behavior flow as the package currently exists.
- `docs/audit/behavior_flow_map_0.1.432.json` contains machine-readable audit output for follow-up passes.
- `docs/CONTROL_RESIDUAL_AUTHORITY_AUDIT_0.1.432.md` identifies remaining `control.lua` authority hits and their intended module owners.
- `docs/ORPHAN_DEAD_END_CANDIDATES_0.1.432.md` lists static orphan/dead-end candidates for review.
- `docs/CONTROL_RELOCATION_CLEANUP_0.1.432.md` records the removal of old 0.1.317 relocation/tombstone comments from `control.lua`.

## Current behavior authority doctrine

`control.lua` is being reduced to a switchboard. The intended flow remains:

```text
control.lua
  -> debug command registry
  -> runtime event registry
  -> GUI router
  -> bootstrap runtime installer

runtime event registry
  -> lifecycle modules
  -> scheduler/task modules
  -> movement controller
  -> consecration modules
  -> GUI router
  -> diagnostics

task scheduler
  -> selects current pair task
  -> executor modules perform work
  -> movement controller owns visible ground-priest movement
```

## 0.1.432 audit snapshot

- Lua files scanned: 96.
- Function definitions detected: 3,123.
- Duplicate function-name families detected across the project: 290.
- Static script orphan candidates: 0. The old `scripts/core/lifecycle_reimprint_guard.lua` shim was archived to `docs/archive/lifecycle_reimprint_guard_0.1.426.lua.txt` after `pair_lifecycle.lua` became the active lifecycle authority.
- Require cycles detected: 0.
- `control.lua` line count after tombstone cleanup: 30,485.
- `control.lua` duplicate mechanical deletion candidates after 0.1.431 purge: 0.

## Current high-risk areas

The highest-risk runtime file is still `control.lua`, because it retains live behavior bodies and authority writes. It should now be cleaned by moving behavior into already named modules, not by blind deletion.

Remaining major cleanup zones:

- lifecycle duplicate retirement,
- GUI body extraction,
- acquisition/scavenge wrapper-chain flattening,
- scheduler/tick-pair authority cleanup,
- final movement/combat residual audit.

## Next staged cleanup path

- `0.1.433`: lifecycle duplicate retirement now that the old re-imprint shim has been archived.
- `0.1.434`: GUI body extraction from control.lua into dedicated `scripts/gui/*` modules.
- `0.1.435`: acquisition/scavenge wrapper-chain flattening and executor authority cleanup.
- `0.1.436`: scheduler/tick-pair current-task authority hardening.
- `0.1.437`: final movement/combat residual audit after live movement tests.

## Standing packaging/testing doctrine

- Keep only `docs/testing/CURRENT_TESTING_GOALS.md` as the active testing-goals document.
- Use short package filenames: `tech-priests_0.1.xxx.zip`, overlay, and diff.
- Prefer full package tests for versions that delete, relocate, or archive runtime files.

### 0.1.434 Entropic Extractor / Thruster Graphics Note
The Entropic Extractor now uses the supplemental four-state lightning art and is implemented as a Space Age platform-only `burner-generator` consuming only raw Blackstone asteroid chunks. The Hydrogen Thruster run sheet now contains seven frames, with the newest blue full-burn thruster art appended as the final burn state.

## 0.1.437 — Runtime Parse Fix and Cleanup Path

The first post-restructuring live test hit Factorio's Lua main-chunk local variable limit in `control.lua`. This patch relieves local-slot pressure by converting top-level `local function` declarations into versioned global functions while preserving bodies and wrapper behavior. This is now the required load gate before surgical wrapper deletion can continue.



## 0.1.445 Task-transition governor

Ordinary low-priority task switching now has a visible cogitation delay. This is intended to reduce Speedy-Gonzales behavior caused by rapid scheduler/resource/mouse-over/subordinate churn. The governor lives in `scripts/core/task_transition_governor.lua`, is surfaced in Work State, and cooperates with `movement_controller.lua`. Combat, emergency, death, respawn, and recovery remain immediate.


## 0.1.446 Consecration tracker repair

Reasserted Machine-Spirit Consecration registration after the control.lua split. The system now tracks machines by explicit name and operational entity type, assigns stable TP-M#### machine IDs, refreshes overhead sanctity bars before their render TTL expires, and exposes `/tp-consecration-0446` for rescan/status diagnostics. This is intended to restore visible sanctity meters and per-operation decay/Detritus auditing before deeper balance work resumes.


## 0.1.447 Consecration settings attachment and visible decay

The settings layer now has a static attachment audit at `docs/audit/consecration_settings_attachment_audit_0.1.447.json`. All 64 defined runtime settings have a detected runtime attachment and the audit reports zero undefined setting accesses. Consecration operation decay now applies bounded random jitter and can show `-X sanctity` floating text to make live operation hooks visible during testing. The task-transition status display now reads its runtime setting instead of using a hardcoded hourglass string.


### 0.1.450

Expanded Entropic Extractor animation coverage using additional cleaned variations while keeping gameplay logic unchanged.

## 0.1.451 — Custom thruster geometry and future visual-logistics roadmap

Hydrogen Thruster placement now begins moving away from vanilla thruster assumptions. The current target is a 3x5 tall chemical thruster with left/right upper pipe inputs: liquid hydrogen on the left and liquid oxygen on the right, one tile down from the upper edge. Void-Fusion Thruster visible pipe ports are hidden because the entity is intended to behave more like a script-serviced electric/ritual drive.

Future roadmap note: develop irregular embedded logistics containers later. These should include strange shapes/configurations such as recessed storage vaults, maintenance corridors, embedded cargo holds, tubes, passageways, and passive containers built into ground or space-platform structure. The goal is to make Tech Priests logistics construction visually and spatially interesting rather than just another set of rectangular chests.

Future roadmap note: develop a diegetic video-monitor portrait system for Cogitator stations later. The station could show its paired Tech-Priest as a small monitor portrait with static overlay, blink/breathing/look-direction variants, and eventual mix-and-match facial features or appearance components.



## 0.1.454
- Restored thin one-by-nine Void-Fusion Thruster and added separate Large Void-Fusion Thruster.
- Corrected Hydrogen Thruster to 4x4 edge-hanging footprint and reduced visual scale slightly.


## 0.1.455 Thruster performance balance

Custom Space Age thrusters now use absolute vanilla-based effectivity scales: Hydrogen 25%, Thetazine 45%, thin Void-Fusion 10%, and Large Void-Fusion 35%. Thetazine and Void-Fusion variants clone from vanilla before final scaling to prevent inherited multiplier chains and runaway platform speed.

## 0.1.471 Overhead status governor and Magos strategic planning queue

0.1.471 treats visible priest overhead text as a single governed state slot instead of a pile of independent render calls. Emergency status snippets, task-force snippets, work visual labels, inventory steward acknowledgements, and acquisition notices now route through a canonical overhead-state governor. The intended player-facing behavior is simple: one Tech-Priest should show one current task state. If he is conversing, the state is conversing. If he is acquiring materials, the state is acquisition. If he is fighting, the state is battle. Low-level bookkeeping such as reliquary indexing, virtual-signal calculating text, and repeated assignment snippets belongs in diagnostics, not as stacked overhead clutter.

This pass also creates a separate Planetary Magos strategic planning queue. The Magos should not treat every ratio or construction desire as an immediate personal movement order. Strategic construction intent now has its own queue where repeated plans can be de-duplicated before being lowered into ordinary immediate work orders. The ordinary per-priest order queue remains responsible for the live work: gather, repair, consecrate, fight, construct, return, and idle. The strategic queue is for “what should this cell build next?” The immediate queue is for “what is this priest doing right now?”

Near-future construction planning should add spline/path planners for belts, pipes, and electrical pylons/poles. These should not be random one-off placements. They should be planned as routed construction writs, checked against available materials, then assigned through the Magos strategic queue and the existing subordinate/immediate order systems.


## 0.1.479 Emergency repair-pack rite, overhead timer cleanup, and later network roadmap

Repair packs are now available through a deliberately inefficient Martian emergency recipe: four copper plates plus seven iron plates, six seconds, start-unlocked, under the Tech-Priest emergency industry subgroup. The intent is not to replace the vanilla repair-pack chain, but to ensure repair-pack demands can be satisfied during stranded or degraded Tech-Priest bootstrap testing.

The visible priest overhead system should expose active crafting as a real countdown state through the canonical one-slot overhead governor. Old configurable status-symbol settings are retired from the active settings list because the visible task line is now governed by current behavior state, not freeform rich-text glyph strings.

Future localization cleanup: all remaining hardcoded player-facing strings across runtime modules, GUI screens, commands, recipes, diagnostics where appropriate, and diegetic displays should migrate into `locale/en/base.cfg` or equivalent locale files so the mod can eventually be localized cleanly.

Future noospheric network concept: investigate a Noospheric Extender station that links remote Tech-Priest station networks without requiring direct station-radius overlap. It should discover connected Tech-Priest networks and connect only the highest-ranking members of each network through the extender, allowing the networks to exchange resource needs and construction plans without turning every station into a global omniscient node. This belongs after the core behavior trees are stable.


0.1.479 detail: the emergency assembler explicitly prefers this recipe when a repair-pack demand is active, so a Tech-Priest repair-pack writ has a primitive fallback even before electronics production is healthy.

## 0.1.480 Strict noospheric command hierarchy

The station network now needs to stop acting like a loose crowd of available helpers and start acting like a command tree. The intended direct-subordinate limits are Planetary Magos 2, Senior 4, Intermediate 8, and Junior peer-communion only. This should reduce oddities where multiple superior stations try to reason over the same lower-rank priest or where a Planetary Magos treats too many lower stations as 

---

## MASTER_BEHAVIOR_TREE.md

# Tech Priests Master Behavior Tree

Version: 0.1.361

This document is the current source-of-truth behavior order for the Tech Priests scheduler cleanup. It describes intended priority and module ownership. It does not mean every behavior has been fully migrated into one executor yet.

## Doctrine

The Cogitator Station is the inventory, memory, command authority, facility owner, and task owner. The Tech-Priest is the mobile actuator and temporary carrier. Priest inventory is not active storage.

## Master priority tree

1. **Validate pair state** — station/priest existence, respawn, reimprint, name retention, station ownership.
2. **Combat and immediate safety** — only after combat safety rejects friendlies, allies, cease-fire, neutral, player, and station-owned targets.
3. **Repair service** — damaged friendly machinery, station, or priest, if repair supplies exist.
4. **Active work continuation** — if a real executor phase is already underway, continue or replan it before inventing a new task.
5. **Station-bound inventory cleanup** — evacuate accidental priest cargo, avoid output spilling, use station/stash/facility storage, build chest before floor cram.
6. **Emergency facility doctrine** — place/use Martian miner, smelter, assembler, lab, power equipment before complaining about raw materials forever.
7. **Acquisition doctrine** — station inventory, station stash, facility inventory, known catalog, mineable result, recipe dependency, primitive fallback, true desperation.
8. **Construction doctrine** — station-bound buildables are placed physically using construction site planning and immediate station tagging.
9. **Consecration service** — machine sanctity state belongs to the consecration modules; priests only service it.
10. **Arterial planning** — Planetary Magos / senior planning, recipe demand tree, ghost placement one element at a time.
11. **Station catalog refresh** — radar-memory snapshot of stable local resources, entities, storage, claimed facilities.
12. **Background chatter** — task-aware, non-mutating, never interrupts real work.
13. **Idle flavor** — only after no higher-priority behavior is active or blocked.

## Failure rule

Every behavior must have a visible blocker. A priest should not merely say `need iron` if the actual blocker is `no smelter`, `no fuel`, `no build site`, `no storage`, `no path`, or `task owned by wrong module`.


## 0.1.362 Pair Ledger Note

`station_pair_state.lua` is now the shared runtime dossier for pair state. It should appear beside every major scheduler phase as the state/reporting ledger, but it is not the decision owner and not the executor. Future behavior modules should report concise blocker/fallback/status data into this ledger or expose it for the ledger to read.


## Recovery preflight — added 0.1.363

Before scheduler priority is trusted, a pair may be audited by `station_pair_recovery.lua`. This is a preflight repair layer only. If the pair ledger, station/priest mapping, station inventory support state, or priest unit mapping is invalid, the recovery module reinitializes state and emits a diagnostic chat line. After recovery, the ordinary scheduler behavior tree resumes.

## 0.1.444 Movement Authority Clarification

Normal visible ground Tech-Priest movement belongs to `scripts/core/movement_controller.lua`. Selection/radar observation must not become a scheduler hammer. Mouse-over order refreshes are now throttled by `scripts/core/hover_movement_stability.lua` before they can churn movement requests every tick.

Permitted non-controller position exceptions remain narrow: lifecycle respawn/recreation for missing/dead priests, Space Age platform hover translation for platform pairs, invisible proxy turret alignment, and invisible support/cache alignment. These exceptions are documented in `docs/MOVEMENT_POSITION_AUTHORITY_SCAN_0.1.444.md` and should not be expanded without a matching audit entry.

## 0.1.475 audio authority doctrine

All new behavior systems should treat sound as an emitted event rather than playing sounds directly. The preferred route is `TECH_PRIESTS_SOUND_MANAGER_0475.emit(pair, event, opts)`. Cogitator Station task changes, priest-issued writs, combat laser usage, mining/acquisition laser work, emergency crafting, repair, consecration, logistics transfer, conversation, deploy, recall, and watchdog cues should pass through the manager so cooldowns, volume settings, source positions, and fallback sound paths remain consistent.

The intended diegetic split is: the station announces a changed rite/order, while the priest vocalizes or signals the writ it is personally issuing. Action sounds should come from the body doing the work unless the work is purely station-owned.


---

## CURRENT_TESTING_GOALS.md

## 0.1.475 unified sound manager verification

- Confirm Cogitator Stations emit a short local cue when their active order/writ changes.
- Confirm a Tech-Priest emits a brief writ call when a new non-duplicate resource/logistics/construction writ is accepted into the order queue.
- Confirm duplicate writ suppression does not repeatedly play the writ siren for the same active/pending order.
- Confirm mining/acquisition actions sound like laser/mining work when accepted by the running Factorio sound library; otherwise confirm the utility fallback is quiet and non-crashing.
- Confirm combat laser events do not create a point-blank sound spam loop.
- Confirm `/tp-sound-manager-0475 test-writ`, `test-switch`, `test-mining`, and `test-combat` play or safely fall back without crashing.
- Use `/tp-sound-manager-0475 off`, `on`, and `auto` if the audio authority needs to be isolated during behavior testing.


## 0.1.473 overhead/Bios verification

- Confirm each Tech-Priest has only one overhead task line.
- Confirm legacy survival bootstrap strings such as `☼ [item=firearm-magazine] survival ammo` no longer render as a second label.
- Confirm `Inventory Reliquary indexed`, task-force snippets, and assignment glyph text do not stack above priests.
- Confirm Cogitator BIOS boot speed setting defaults to 50 and that 25 resembles the prior slow debug cadence.
- Use `/tp-overhead-authority-0473` and `/tp-bios-boot-speed-0473` for live inspection.

# Current Testing Goals - Tech Priests 0.1.471

## Primary live verification

1. Load Factorio with `tech-priests 0.1.471` selected as the highest package.
2. Use the existing active save where priests are visibly moving, quarrying boulders/resources, and producing dropped resources.
3. Watch each visible Tech-Priest for at least one minute.
4. Confirm each priest has only one governed overhead task line at a time.
5. Confirm stale bookkeeping labels such as `Inventory Reliquary indexed`, virtual signal calculating text, survival-ammo chatter, and stacked item assignment snippets do not pile above the same priest.
6. Confirm a priest frozen by player/priest conversation shows `Conversing` in the overhead task slot rather than a stale inventory/acquisition state.
7. Confirm ordinary speech/typewriter lines still appear when conversations happen, but do not create repeated task-state spam.
8. Select a priest or Cogitator Station and run `/tp-overhead-status-0471` to force-refresh and print the governed overhead state.
9. Select the Planetary Magos cell and run `/tp-magos-planning-0471` to inspect its strategic planning queue.
10. Continue the prior behavior testing: resource acquisition, boulder quarrying, combat/acquisition visual mutex, and order queue duplicate suppression.

## Expected results

- One priest = one overhead task-state slot.
- Strategic Magos planning should be separate from immediate personal work orders.
- Repeated ratio/construction planning needs should become de-duplicated planning writs, not constant visible task churn.
- The ordinary order queue should still carry immediate work such as acquire, repair, consecrate, combat, and return.
- The Work State GUI, Known Resources tab, radar visuals, and Machine-Spirit Consecration Ledger should remain available from the previous recovery passes.

## Near roadmap carried forward

- Implement dedicated spline/path construction planners for belts, pipes, and electrical pylons/poles.
- Route those spline plans through the Planetary Magos strategic planning queue first, then emit bounded subordinate/immediate construction writs.
- Continue replacing plain utility GUI panels with custom diegetic Cogitator/reliquary display backings.

## 0.1.474 visual stability / Alt-writ validation

- Enable Alt-mode and confirm the active Cogitator writ icon appears over the station, not over the priest.
- Confirm the priest still shows only one overhead task/status line.
- Select/hover a Cogitator Station and confirm radius rings, interstation links, and the station-priest link remain solid rather than strobing.
- Hold a Cogitator Station item and confirm faint outline-only radius previews appear around existing stations.
- Confirm no filled green radius disk or full-radius station-light effect returns.


## 0.1.480 strict command hierarchy test

Confirm the noospheric command tree obeys the intended direct-subordinate limits: Planetary Magos 2 Senior subordinates, Senior 4 Intermediate subordinates, Intermediate 8 Junior subordinates, and Junior peer communion only. Use `/tp-command-hierarchy-0480 all` and the Cogitator Dictator Work State Command Tree pane to verify that subordinate scheduling only delegates to direct subordinate seals rather than every lower-rank station in range.


---

## COMMAND_HIERARCHY_0.1.480.md

# Tech Priests 0.1.480 Command Hierarchy Pass

This pass introduces a strict command hierarchy for Tech-Priest station networks.

Direct command sockets:

- Planetary Magos: 2 Senior subordinates
- Senior: 4 Intermediate subordinates
- Intermediate: 8 Junior subordinates
- Junior: no lower-rank subordinates; limited peer communion only

The goal is to reduce behavior oddities caused by loose rank discovery, where multiple higher-rank stations could treat the same lower station as available or where a high-rank station could reason across too many lower-rank stations at once. The hierarchy slate stamps one superior seal onto each direct subordinate, and subordinate scheduling now reads that slate.

The Cogitator Dictator Work State now has a Command Tree pane showing the station rank seal, superior seal, subordinate sockets, and junior peer echoes.

Diagnostic command:

```text
/tp-command-hierarchy-0480
/tp-command-hierarchy-0480 all
/tp-command-hierarchy-0480 rebuild
```


---

## WORKSTATE_TABS_AND_TASK_LIFECYCLE_0.1.478.md

# Tech Priests 0.1.478 — Work State panes, consecration source ledger, and task lifecycle authority

This pass expands the Cogitator Dictator Work State into a more useful diegetic inspection console.

New Work State panes:

- **Vox Archive** — recent conversation memory, temperament after discourse, last exchange, and whether the priest is currently reserved by conversation.
- **Writ Queue** — current order, pending orders, recent completed/failed/promoted orders, duplicate blocks, and executor re-arm state.
- **Forge Plan** — Planetary Magos construction-planning queue, current strategic augury, pending plans, and recent construction seals.

The consecration ledger now records source marks whenever purity is restored. A restoration entry should include the source rite, item, celebrant, restored amount, and tick. This applies to hand-applied rites, capsule-use rites, area rites, incense/cloud calls where the source is available, and Tech-Priest station rites.

Task lifecycle authority was added to address incomplete behavior trees where a priest could hold a mining or logistics task title but not actually walk toward the target, or could fire a mining beam from near the station. Non-hostile mining/acquisition beams now require the priest to be close to the work target. Distant quarry/resource work must issue movement first. If a current writ's requested item is already present in the station reliquary, the writ can complete instead of repeatedly chanting the same need.

Future Forge Plan work should build spline/arterial construction planners for belts, pipes, and electrical pylons/poles.


---

## ORDER_QUEUE_RESOURCE_WRITS_0.1.469.md

# Tech Priests 0.1.469 — Order Queue and Resource Writ Pass

This pass converts the live behavior-stabilization idea into a runtime authority layer. The goal is to stop priests from repeatedly discovering the same resource need and reassigning it every few ticks.

Each station/priest pair now has `pair.order_queue_0469` with a single `current` order and a bounded pending queue. Orders are keyed by station, surface, item, task family, and target/role where appropriate. If the same order key already exists in the current order or pending queue, the duplicate request is blocked and counted rather than stacked.

Combat, repair, and consecration remain higher-priority behavior bands. They may preempt acquisition, scavenge, logistics, and emergency-craft orders. The lower-priority order is paused and put back at the front of the queue, so combat can interrupt without erasing the copper/stone/wood writ that the priest was already executing.

The queue wraps the canonical task assignment function, emergency acquire path, supply-scavenge path, logistics scavenge scan starter, and the resource-doctrine direct/handle-no-source functions. This is intentionally a late authority overlay, not a full rewrite of the legacy behavior stack.

Diagnostics are exposed through `/tp-order-queue-0469 status|all|write|on|off|clear`. The existing emergency diagnostics pair dump is extended with `ORDER-QUEUE-0469` rows.

## Forward notes

- Move remaining player-facing strings into `locale/en/base.cfg` over time.
- Future Machine-Spirit Ascension should first track high-consecration operations before attempting quality upgrades.
- Future Noospheric Extender should link remote command networks through their highest-ranking available members.
- Future custom GUI backing art should provide diegetic Cogitator and reliquary displays without external font dependencies.


## 0.1.484

Imported an additional alternate human / augmented portrait sheet and registered it for later Cogitator Work State portrait assignment.

### 0.1.485 Duplicate Portrait Cleanup
Removed duplicate augmented portrait sheet B after confirming it matched sheet A exactly. Removed sprite registrations and runtime references to the duplicate asset.



## 0.1.486 Planetary Magos Portrait Registry

Added a dedicated Planetary Magos portrait reference sheet as a registered GUI sprite and runtime registry entry. Individual cell slicing and persistent Work State portrait binding remain deferred.


## 0.1.487

Rejected and removed the ornate GUI frame-kit experiment. Kept small utility GUI controls and portrait sheets. Added strict visual lease cleanup for station radius/connection overlays after hover/selection/placement context ends.


## 0.1.488 Single-action arbiter

Added `scripts/core/action_state_arbiter_0488.lua` to reconcile current queue action, lower executor surfaces, overhead text, scan lines, and laser beams. This pass specifically targets the observed condition where a priest could display a crafting countdown while also mining/scanning rocks or resources and emitting a combat-colored laser.


## 0.1.489 - Own-station scan and visual lease hardening

Blocked scan/mining/laser visuals that target a Tech-Priest's paired Cogitator Station. The home station is treated as already-known inventory/command authority, not as a resource or external inventory target. Also removed stale selected-pair fallback from the stable visual overlay authority so radius circles, interstation links, and priest-station links decay after selection or placement context ends.


## 0.1.490 Direct Mining Safety / No-Spill Storage

Added a late direct-mining safety authority after live testing showed priests could vanish while mining and ammunition could spill onto the ground. The legacy direct-gather path now rejects protected entities, deposits literal gathered materials only, routes deposits through the inventory steward, and can create a primitive Martian Stone Cache from stone. Missing priests without a re-imprinting rite are logged and rescued.

# 0.1.493 Documentation Standards Consolidation

Per the documentation standards reset, per-build audit/implementation notes are no longer kept as separate loose history files. The following standalone notes were folded into this development history and removed from the active docs folder so future build notes have one canonical home.


## Folded note: BACKGROUND_REPLACEMENT_0483.md

# Tech Priests 0.1.483 — Background Image Replacement Asset

This pass imports the supplied Mechanicus factory background as `background-image.jpg`.

Bundled paths:

- `graphics/background-image.jpg`
- `graphics/menu/background-image.jpg`
- `core/graphics/background-image.jpg`

The source image was converted directly from the uploaded PNG into JPEG form. No image generation or restyling was performed in this pass.

Note: the package now contains the replacement asset under the expected filename and a core-style mirror path. If Factorio does not shadow the core static menu background by filename alone in the current runtime, the next implementation step is to wire this image through a proper main-menu simulation or menu-background override mechanism instead of relying on asset-path mirroring.


## Folded note: DIRECT_MINING_SAFETY_0490.md

# Tech Priests 0.1.490 - Direct Mining Safety / No-Spill Pass

This pass hardens the legacy direct emergency-gathering path after live tests showed Tech-Priests could vanish during mining and spill ammunition onto the ground.

## Rules added

- Direct mining may only act on literal world sources: resource patches, trees, and neutral rock/simple entities.
- Tech-Priests must never mine, damage, or scan their own station, another Cogitator Station, another Tech-Priest, item-on-ground entities, containers, machines, or other protected owned entities.
- Direct mining may only deposit the material actually gathered. A stone rock can yield stone; it cannot magically complete a firearm-magazine writ.
- Emergency outputs must go to the station inventory or a station-bound stash. Ground spill is not an accepted normal storage path.
- If a paired priest disappears without an active re-imprinting rite, the safety module attempts a controlled rescue/respawn and logs the event.

## New primitive stash

Adds a start-unlocked **Martian Stone Cache** recipe:

- 12 stone
- 4 seconds
- 12 inventory slots

The inventory steward may build this crude cache near the station when the station inventory is full and stone is available.

## Diagnostics

Command:

```text
/tp-direct-mining-safety-0490
/tp-direct-mining-safety-0490 all
/tp-direct-mining-safety-0490 rescue
/tp-direct-mining-safety-0490 on
/tp-direct-mining-safety-0490 off
```

Emergency diagnostics now include `DIRECT-MINING-SAFETY-0490` rows.


## Folded note: GUI_ASSET_IMPLEMENTATION_0482.md

# GUI Asset Framework Status

The 0.1.482 frame-kit experiment has been rolled back in 0.1.487. The oversized ornate frame pieces did not fit the Cogitator Work State window and were removed from the package.

Retained GUI assets are limited to practical utility pieces: skull emblem, lamps, switches, small controls, and portrait sheets. The Work State panel currently uses the native Factorio frame and tabbed-pane layout while future diegetic GUI work is redesigned.

See `GUI_ASSET_ROLLBACK_0487.md` for the active decision record.


## Folded note: GUI_ASSET_ROLLBACK_0487.md

# Tech Priests 0.1.487 GUI Asset Rollback

The 0.1.482 ornate frame-kit experiment was rejected after live visual review. The assets were behaving like large outer-frame artwork rather than usable inner GUI framing, and they made the Cogitator Dictator Work State panel look worse while crowding the working diagnostic panes.

Removed from the public package:

- `graphics/gui/frame_kit/`
- `graphics/gui/medallion_spin/`
- frame-kit and medallion sprite registrations
- source/import manifest documentation for the rejected frame-kit experiment

Retained for future use:

- mechanical skull/cog emblem
- warning lamps
- toggles, levers, buttons, sliders, and gauges
- portrait sheets and portrait registries

The Work State GUI keeps the working native Factorio window, tabs, tables, and debug panes. Future diegetic GUI work should be rebuilt around assets designed for the actual inner content geometry rather than forcing oversized outer-frame pieces into a tabbed window.


## Folded note: PACKAGING_CLEANUP_0.1.481.md

# Packaging Cleanup 0.1.481

Removed from the public package:

- Experimental external-font folders and license staging notes.
- `locale/en/info.safe-fallback.template.json`.
- `locale/en/info.fonts-enabled.template.json`.
- `prototypes/fonts.lua` and the data-stage loader for it.
- Local font descriptor tools and local public package builder.
- Root patch overlay readmes.
- Repeated audit, archive, rebase, testing, and standards document trees.

Runtime display now uses Factorio base UI fonts only. Diegetic identity should come from wording, color, icons, sound, sprites, layout, and future custom GUI backplates.


## Folded note: PLANETARY_MAGOS_PORTRAITS_0486.md

# 0.1.486 Planetary Magos Portrait Reference Sheet

This build adds a dedicated Planetary Magos portrait reference sheet:

`graphics/gui/portraits/planetary_magos_portrait_sheet_a.png`

The sheet is registered as Factorio GUI sprites and indexed by `scripts/core/portrait_registry_0486.lua`.

This is intentionally an asset framework pass only. The sheet is reserved for explicit Planetary Magos portrait assignment once the Cogitator Work State portrait viewport and persistent pair-portrait binding are implemented. It should not be randomly mixed into the ordinary lower-rank portrait pool unless explicitly requested later.

Deferred work:

- Slice individual portrait cells.
- Create stable portrait IDs per cell.
- Persist assigned portrait ID on the station/priest pair table.
- Display the selected portrait in the Cogitator Work State GUI.
- Add manual or deterministic assignment rules for named/high-rank Magos.


## Folded note: PORTRAIT_ASSET_REGISTRY_0484.md

# Portrait Asset Registry 0.1.484

This pass imports the newly supplied alternate human / augmented portrait sheet as:

`graphics/gui/portraits/alternative_human_augmented_portrait_sheet_c.png`

Runtime sprites registered:

- `tech-priests-gui-portraits-alternative-human-augmented-portrait-sheet-c`
- `tech-priests-portrait-alternative-human-augmented-sheet-c`

Source dimensions: `1265 x 1243`.

The sheet is currently treated as a full-sheet asset. Individual portrait-cell slicing, persistent portrait assignment per priest pair, and use inside the Cogitator Work State portrait bay remain intentionally deferred until the GUI shell and tab authority are stable.

Debug command:

`/tp-portrait-registry-0484`


## 0.1.486 Planetary Magos Sheet

A dedicated Planetary Magos reference sheet is now bundled as `planetary_magos_portrait_sheet_a.png` and registered by `portrait_registry_0486.lua`. It is reserved for explicit high-rank assignment later.


## Folded note: SELF_STATION_SCAN_VISUAL_LEASE_0489.md

# Tech Priests 0.1.489 - Own-Station Scan and Visual Lease Hardening

This pass blocks scan, mining, and laser visuals from targeting a priest's own paired Cogitator Station. The paired station is already the priest's command reliquary and inventory authority; it should not be treated as an unknown external target.

The pass also tightens station radius and connection-line overlay leasing. Radius circles, interstation links, and priest-to-station links now require active station/priest selection or Cogitator placement context. Stale selected-pair fallbacks are no longer enough to keep overlays alive.

Runtime diagnostic command:

```
/tp-self-station-scan-0489
/tp-self-station-scan-0489 all
/tp-self-station-scan-0489 clear
```


## Folded note: TECHNOLOGY_LOCALE_AUDIT_0492.md

# Technology Locale Audit 0.1.492

This audit verifies that every technology prototype declared by the mod has a corresponding `technology-name` and `technology-description` locale key in `locale/en/base.cfg`.

- Technology prototypes found: 39
- Missing `[technology-name]` keys: 0
- Missing `[technology-description]` keys: 0
- Duplicate locale section headers found: 0
- Duplicate locale keys found inside sections: 0

Result: all current technology prototype keys are covered.

## Technologies checked

- `blackstone-citadel-manufacture`
- `cogitator-logistic-requisition`
- `cogitator-operating-radius-1`
- `cogitator-operating-radius-2`
- `cogitator-operating-radius-3`
- `cogitator-radar-sweep-acceleration`
- `cogitator-station-deployment`
- `efficient-sacred-oil-rendering`
- `hydrogen-thruster-propulsion`
- `intermediate-cogitator-stations`
- `machine-maintenance-litanies`
- `machine-spirit-capacity-1`
- `machine-spirit-capacity-2`
- `machine-spirit-initial-consecration-1`
- `machine-spirit-initial-consecration-2`
- `orbital-relic-procurement`
- `orbital-trader-deployment`
- `paraffin-separation`
- `planetary-magos-cogitator-stations`
- `planetary-magos-command-range-1`
- `planetary-magos-command-range-2`
- `planetary-magos-command-range-3`
- `planetary-magos-command-range-4`
- `pure-carbon-processing`
- `ritual-of-machine-appeasement`
- `ritual-salt-extraction`
- `ritual-wood-pulping`
- `sacred-candle-rendering`
- `sacred-incense-grenades`
- `senior-cogitator-stations`
- `sodium-carbonate-synthesis`
- `tech-priest-reimprinting-acceleration-1`
- `tech-priest-reimprinting-acceleration-2`
- `tech-priest-reimprinting-acceleration-3`
- `tech-priest-rite-of-kinetic-exemption`
- `thetazine-propulsion`
- `void-cogitator-stations`
- `void-fusion-thruster-propulsion`
- `void-sealed-cargo-unsealing`


## Folded note: VISUAL_LEASE_CLEANUP_0487.md

# Tech Priests 0.1.487 Visual Lease Cleanup

Station radius circles, interstation links, and priest-station link lines are context visuals. They should appear while a player is selecting/hovering a Cogitator or priest, or while holding a Cogitator station for placement, then decay/clear after that context ends.

This pass adds `scripts/core/visual_lease_cleanup_0487.lua`, loaded after the earlier visual authorities. It shortens overlay TTLs and aggressively clears context overlays when no station/priest selection or station placement cursor is active. If Alt mode is enabled, it redraws only Alt-mode writ icons after clearing, leaving radius and connection overlays gone until context returns.

Debug command:

```
/tp-visual-lease-0487
/tp-visual-lease-0487 clear
/tp-visual-lease-0487 off
/tp-visual-lease-0487 on
```


# 0.1.494 Work State Organization Pass

The Cogitator Dictator Work State / Boot pane was reorganized from a long continuous list into native Factorio GUI plaques. This keeps the existing stable tabbed window and avoids the rejected ornate outer-frame assets, while giving the panel a stronger Cogitator-terminal structure. The new layout introduces separate sections for Identity Reliquary, Doctrine Seal, Current Rite, Command Oath, Recent Notations, Machine-Spirit Diagnostics, Personal Martian Machinery, Inventory Reliquaries, and Work Doctrine.

The Current Rite plaque is now the first behavior-debugging surface to check. It reports the active rite, action owner, target seal, movement verdict, craft timer, current writ, and lower executor slate. The goal is to make behavior disagreement visible immediately when a priest is claiming one action while an older executor is attempting another.


# 0.1.495 Consecration Mining / Pair Link / Work State Table Pass

Consecration now has a late mining-drill sensor for machines that do not expose assembler-style `products_finished`. The sensor watches mining progress wraps and mining output inventories and routes completed mining cycles through the normal machine-spirit operation ledger, so a consecrated burner miner or electric miner can lose sanctity and record work-rites when it mines rather than only when it crafts.

Pair lifecycle received a link-hardening authority. It repairs reverse maps between station and priest, records last valid priest signal, tries to rebind nearby orphaned priests before spawning replacements, and only then uses the existing controlled respawn path. This is intended to reduce cases where a station has a nil priest, stale priest pointer, or apparent vanish/reappear behavior.

The next Work State visual organization step was started: Writ Queue and Command Tree panes now use structured tables instead of long prose lists. Writ Queue separates current writ, pending writs, recent writ seals, and watchdog status. Command Tree separates rank, socket usage, superior, direct subordinates, peer communion, current writ, and priest signal.

## 0.1.496 — Work State GUI Sprite Scope Hotfix

Fixed a runtime crash after the Cogitator Work State boot sequence. The 0.1.494 Work State organization pass called `add_gui_sprite_0482` from `add_identity_plaque_0494`, but the helper was declared later in the same Lua chunk as a local function, leaving the earlier function body unable to see it at runtime. The helper is now forward-declared and assigned later so both the Identity Reliquary plaque and the later Work State control rail share the same in-scope function.

No standalone audit/pass/history document was added.

## 0.1.497 — Emergency Supply Reserve / One-Item Writ Pass

Emergency survival supplies are now treated as one-item writs. Ammunition, repair packs, and consecration items should no longer cause a priest to stall while trying to gather or craft a stack-sized reserve before the base has machinery. The late authority clamps critical supply requests to one unit, checks whether the station or same-surface station network already has the item, and completes the current/pending emergency writ when the need is satisfied.

A passive reserve balancing pass now moves critical items from accidental priest cargo, surplus station stock, or station-adjacent storage into stations with an active one-item need. This is intentionally conservative: it is not a bulk logistics bot system, but it prevents obvious cases where one station or priest has excess ammunition while another priest is still chanting for one clip.

The new diagnostics command is `/tp-emergency-reserve-0497`, and emergency diagnostics append `EMERGENCY-RESERVE-0497` rows showing clamp, satisfaction, and balancing activity.

## 0.1.498 - Task / Pair State Audit and Quarantine Pass

- Added `scripts/core/task_pair_audit_0498.lua` as a late-loaded diagnostic and quarantine layer for vanishing Tech-Priests.
- The new layer records Tech-Priest/Cogitator entity-removal events, priest-unit changes, large position jumps, and current order/lower executor state in emergency diagnostics.
- Missing-priest pairs now quarantine lower executor surfaces so invisible acquisition/crafting work cannot continue after the priest body is invalid.
- Valid-priest respawn attempts are blocked unless the pair is in an active re-imprinting state, preventing a live visible priest from being destroyed by a stale rescue/respawn path.
- Legacy direct emergency gathering is now literal-only: copper comes from copper ore, stone from stone, wood from trees; dirt/stone fallback is rejected for non-stone targets.
- Existing pair-link and direct-mining safety diagnostics remain active; the 0.1.490 rescue loop is delegated to the pair-link/audit authority to reduce duplicate rescue churn.

## 0.1.499 — Priest lifecycle authority / stuck recovery disable pass

- Audited active Tech-Priest destruction paths after repeated reports of priests vanishing during ordinary gather/mining assignments.
- Added `scripts/core/priest_lifecycle_authority_0499.lua` as the last-loaded lifecycle authority.
- Blocked orphan-purge destruction, mobility replacement destruction, and respawn/recall replacement while the vanish source is being isolated.
- Disabled acquisition-repair and execution-watchdog reactivation loops by default for this pass so stuck-detection systems cannot force replacement/recall behavior.
- Added `/tp-priest-lifecycle-0499` and emergency diagnostic rows showing removal observations, blocked respawns, blocked purges, and known legacy priest-destroy sites.

## 0.1.500 - Priest lifecycle seal

The vanishing-priest failure persisted after 0.1.499, including cases where a visible priest spawned, walked briefly, and then became invalid with no useful removal event. This pass treats direct script-side priest destruction as unsafe unless it is part of Cogitator Station removal or death cleanup. Added `scripts/core/priest_lifecycle_seal_0500.lua`, patched direct priest-destroy call sites in legacy lifecycle/replacement paths, disabled stuck/recall/respawn replacement behavior while auditing, and added `/tp-priest-lifecycle-0500` plus pair-dump diagnostics. Valid priests are kept non-destructible for this audit pass so damage/stray combat cannot masquerade as scripted disappearance.


## 0.1.508 - Passive recovery and physical acquisition lease

Live 0.1.507 testing confirmed the startup log loaded `tech-priests 0.1.507`, but the runtime still emitted repeated `recovery-teleport-0503 ... reason=ensure-request ok=false` lines immediately after pair creation and during ordinary emergency work. This showed that the older 0.1.503 recovery module was still acting as a movement owner and bypassing the newer intended mobility contract.

Added `scripts/core/movement_recovery_authority_0508.lua`. The new layer patches global ensure/respawn calls and the 0.1.503 recovery module so valid same-surface priests are passively validated, reverse maps are repaired, stale recall/missing flags are cleared, and no teleport is attempted. Missing/cross-surface priests still fall through to controlled recovery. Direct acquisition now owns a physical movement lease and only lets old direct-mining executors run once the visible priest is adjacent to the target.

Added `/tp-movement-recovery-0508` and `PAIR-DUMP-0468 MOVEMENT-RECOVERY-0508` diagnostics. No new standalone audit document was added.

## 0.1.532 — Task/status churn damper and diegetic GUI tint

Live diagnostics showed active emergency/logistics writs still being accompanied by repeated passive `mouse-over` and `radar-priest-scan` refreshes, duplicate heartbeat rows, and legacy scheduler clears to `no-managed-priority-claimed` while order queues still had active current orders. This produced visible overhead task churn: the priest was still working, but the reporter layer kept seeing stale idle/cogitation signals and rapidly replacing the displayed text.

Added `scripts/core/status_churn_damper_0532.lua` as a late-loaded authority shim. It does not create work, complete orders, move priests, draw independent text, or bypass the dispatcher. It only protects active order leases from passive refreshes, suppresses idle/no-managed-priority visual clears while a valid current writ or dispatcher action is active, filters duplicate same-tick heartbeat log spam, and gives the overhead status reporter a short hysteresis lease so lower-priority equivalent text cannot flicker over the current writ.

The diagnostic command `/tp-status-churn-0532` reports the selected pair's mode, current order, visual state, overhead lease, and suppression counters. Emergency pair dumps also append a `STATUS-CHURN-0532` block.

The Cogitator Work-State Reliquary also received a conservative diegetic GUI tint pass. The outer native frame now uses a muted brown style, while the main internal body uses a dark green Cogitator-instrument style. This stays in the existing native Factorio GUI system and does not reintroduce the rejected ornate frame-art experiment.

No new standalone audit/history document was added.



## 0.1.533 — Placeholder audio manifest integration

Integrated the supplied placeholder audio bundle as a functional first-pass sound layer. The package now includes `sound/tech-priests/*.ogg`, `docs/AUDIO_MANIFEST.md`, `docs/AUDIO_GENERATION_PROMPTS.md`, `docs/PLACEHOLDER_AUDIO_INDEX.tsv`, and `docs/PLACEHOLDER_AUDIO_README.md`.

Added prototype registrations for each placeholder OGG in `prototypes/sound.lua`. Sound prototype names are generated from the supplied filenames using the `tech-priests-tp-...` naming pattern, preserving the original filenames so final replacement assets can keep the same paths.

Updated `sound_manager_0475` so repair, sanctification/oil, scan, emergency, GUI, station-link, low-sanctity, and detritus-clog events can use the new placeholder candidates with per-category cooldowns. Candidate selection now rotates deterministically across variants so repeated one-shots do not always choose the first file.

Added `scripts/core/placeholder_audio_0533.lua` as an audio-only reporter. It wraps pair creation for link-established cues, observes invalid station/priest links for broken-link cues, scans consecration machine records for low-sanctity threshold crossings and detritus/jam transitions, and plays GUI open/close cues. It does not create work, alter orders, move priests, complete tasks, modify inventories, draw visuals, or claim action families.

Patched `operational_sounds_0531` so custom GUI clicks use the new button/tab/portrait/close placeholder sounds rather than only the older clicker/clak assets. Existing machine and respirator sounds remain available.

No standalone audit/history document was added; integration notes were appended here and the current testing goals were updated.

## 0.1.534 — Graphical asset and stone-cache integration pass

Integrated the supplied graphical assets into the mod package. The pass copied new station art, Martian emergency machine art, stone-cache/cargo art, primitive void steam machinery art, and rough GUI assets into appropriate graphics folders. The rough GUI material is intentionally preserved for later intelligent slicing and is not yet wired into the active GUI shell.

The Martian Stone Cache family was expanded. The existing `tech-priests-martian-stone-cache` is now a two-by-two basic cache with four slots and a higher stone cost. Named item caches were added for coal, stone, wood, iron ore, copper ore, iron plates, copper plates, copper cable, iron gears, and iron rods; each has six slots and a dedicated sprite/icon. The Stone Cache Item Vault has ten unrestricted slots. The Primitive Acclimator Battery Bank is an accumulator-style cache-family entity with no physical inventory, while the Pressurized Fluid Vault is a storage-tank-style cache-family entity. Basic and Advanced Space Cargo Inventory containers were added with twenty and fifty slots and are unlocked alongside Void Cogitator Stations for this first test pass.

Added `scripts/core/stone_cache_filter_0534.lua` as an inventory steward for named stone caches. Because ordinary Factorio container prototypes do not provide a simple per-entity item-only inventory filter, the steward periodically scans named caches and ejects wrong item stacks. It does not create orders, move Tech-Priests, complete tasks, or claim behavior authority.

Junior, Senior, Planetary Magos, and Void Cogitator Stations now use the new supplied station sprites and newly generated icons while retaining the existing rank tint scheme. The Intermediate Cogitator Station deliberately remains on the previous default sprite because no new intermediate art was supplied.

Martian emergency machines now use supplied EMM sprites and generated shadows/icons. Unused EMM placeholder art was retained under `graphics/entity/martian-micro/future/` for later systems such as the planned Inter-Magos network connector. The Space Age primitive steam chain also received the new Void Steam Electric Generator and Void Steam Catalyzer graphics, with the generator using a two-by-two footprint and the catalyzer using a broad two-by-four platform footprint.

No standalone audit/history document was added; these notes were appended here and the current testing goals were updated.


## 0.1.535 — Entity-derived icon review pass

Regenerated the active non-Cogitator asset icons introduced in the 0.1.534 art pass. The Martian emergency machine icons are now produced directly from the active EMM body sprites under `graphics/entity/martian-micro/`. The Stone Cache, named cache variants, Item Vault, Primitive Acclimator Battery Bank, Pressurized Fluid Vault, and Basic/Advanced Space Cargo Inventory icons are regenerated from their active `graphics/entity/stone-cache/` sprites. The Void Steam Electric Generator and Void Steam Catalyzer / Sterling Steam Catalyzer icons are regenerated from their active primitive void steam machine sprites.

Cogitator Station icons were deliberately left untouched because 0.1.534 had already regenerated the station-specific rank-tinted icon set and the user explicitly excluded cogitators from this pass. No behavior, task authority, cache filtering, inventory sizing, recipe cost, GUI behavior, or sound routing was changed. No standalone audit/history document was added.


## 0.1.536 — Mechanical Cogitator GUI frame slicing integration

Integrated the approved sliced GUI frame kit into the primary mod package under `graphics/gui/cogitator_frame_0536/`. The package includes the 384px runtime slice set, normalized source frames, mechanical overlay review, stretch-test review, and the slice manifest produced from the frame-slicing pass.

Registered the live slice pieces as GUI sprites in `prototypes/gui_sprites.lua` and added stable frame mappings to `scripts/core/gui_asset_framework_0482.lua`. The active Work-State Reliquary now assembles the decorative frame as runtime sprite widgets around the existing tabbed content: fixed corner panels and top/bottom emblems, stretch-X horizontal rails, stretch-Y side columns, and a mechanically sliced inner aperture/bezel around the native Factorio content frame.

The Work-State Reliquary width was expanded and recentered on the player's display so the new side columns and bezel do not crush the existing diagnostics, inventory ledgers, command lattice, vox reliquary, writ reliquary, and forge slate tabs. This remains a display wrapper only; no task authority, order ownership, movement behavior, inventory routing, sound routing, or overhead status logic changed.

No standalone audit/history document was added.


## 0.1.538 - Martian Stone Cache boot explosion repair

The live boot test failed during prototype assignment because `tech-priests-martian-stone-cache` and related cache containers referenced `rock-big-explosion`, which is not present in the current Factorio 2.0 prototype set being loaded. The Martian Stone Cache prototype builder now checks `data.raw.explosion` and uses `medium-explosion` or `explosion` only if those prototypes exist; otherwise it omits `dying_explosion` entirely. This is a prototype-load containment patch only and does not alter Tech-Priest behavior, task authority, cache filtering runtime logic, inventory stewardship, or the 0.1.536 sliced GUI shell.


## 0.1.539 — Direct-acquisition walking/work visual coherence

Live testing after 0.1.538 showed a Tech-Priest visually walking away while a mining beam remained connected to the resource behind them. The likely split was not a boot or GUI issue: the direct-acquisition executor was drawing target scan/mining visuals from walking status updates, and stale movement leases could survive into the adjacent work phase.

Changes made:

- `scripts/core/direct_acquisition_executor_0513.lua` now treats walking status as text-only. It no longer calls the target scan/mining beam while the priest is still outside adjacent work distance.
- Direct-acquisition work start now explicitly clears movement request state, clears the 0.1.518 movement lease when available, and issues a stop before work visuals or mining damage.
- `scripts/core/movement_cadence_contract_0518.lua` now exposes `tech_priests_clear_movement_lease_0518` and records `lease-cleared-0539` for diagnostics.
- `scripts/core/scan_beam_controller_0529.lua`, which is final-loaded visual authority, now suppresses resource/tree/rock mining beams unless the priest is adjacent and in a working/mining phase. This preserves the movement-before-action contract even though 0.1.529 overwrote earlier scan-line wrappers.

Testing focus: watch direct mining, tree/rock scrounging, and emergency acquisition while walking away from the target. No beam or smoke should appear until the priest is physically adjacent and stopped.

- Additional 0.1.539 hygiene: fixed the dormant `mobility_recovery_contract_0506.lua` vararg-in-nested-closure syntax error shown in the current Factorio log, so the compatibility movement recovery module can install instead of failing under pcall during boot.

## 0.1.540 — Work-State Reliquary GUI slice and display-panel refinement

Reworked the 0.1.536 Cogitator GUI shell so the long horizontal rails and vertical side machinery columns no longer scale as single distorted sprites. Each rail now has fixed end caps with only the middle segment stretching, and each side column has fixed top/bottom caps with only the central shaft segment stretching. Added the generated 0.1.540 segment sprite prototypes and packaged the matching PNG slices under the existing Cogitator frame asset folder.

Updated the Work-State content presentation so inner plaques, resource/catalog sections, and summary frames use a green-tinted Cogitator display frame style rather than default grey Factorio inset frames. Tightened label and table widths so long executor-state strings, active writ identifiers, personal notes, and table values wrap inside their panels instead of overflowing the display aperture.

This is a GUI display/layout pass only. It does not alter dispatcher ownership, movement contracts, direct acquisition, emergency production, repair, combat, consecration, station inventory doctrine, or task completion behavior.


## 0.1.541
- GUI: changed the 0.1.540 rail/side-column middles from stretched single strips to tiled mid sections so authored caps and cable/gauge detail survive resizing.
- GUI: applied green display styling to boot frames/spinner frames, narrowed long value labels, and preserved the current Work-State tab when boot/update repair redraws occur.
- GUI: added stronger terminal label wrapping so long identity/doctrine/status values continue onto the next line instead of running through panel edges.
- Visuals: lowered the Planetary Magos Cogitator station sprite so its platform sits on the ground instead of hovering.
- Visuals: normalized Cogitator station icon content size across junior/senior/planetary/void icons.
- Visuals: rescaled Martian emergency micro-machinery sprites: micro-smelter/lab to one-tile visual footprint, miner/assembler/grid to a compact near-one-tile footprint, and boiler/steam engine toward compact two-tile visuals.
- Visuals: doubled basic and advanced void cargo inventory visual and selection/collision footprints.
- Audio: reduced the emergency miner inherited machine sound volume by 50%; raised Tech-Priest voice bark defaults by roughly 10%.
- Behavior: strengthened direct-acquisition work clamp so arriving at a mining target clears movement request state, issues a stop command, and refreshes the mining lock while work is executing.


## 0.1.542 — Locale coverage, recipe-aware tech order, and consecration target ownership

Performed a mod-wide localization audit against the active prototype source files and the canonical `locale/en/base.cfg` file. Visible Tech Priests items, entities, recipes, technologies, fluids, asteroid chunks, and retained equipment-grid prototypes now have corresponding name/description coverage where Factorio can surface them. Hidden dynamic emergency mining/smelting wrapper recipes already use explicit `localised_name` / `localised_description` tables because their names are generated from arbitrary vanilla or modded item names. The pass also added descriptions for hidden projectile carrier entities used by sacred-oil and incense capsule application so they do not remain unnamed if surfaced by diagnostics. Locale duplicate-section and duplicate-key validation passed after the merge.

Re-normalized the technology order strings and late-station prerequisites so the research tree reads more like a recipe-aware chain: ritual materials and sacred-oil efficiency first, then orbital trader/procurement, then Cogitator station tiers, then radius/logistics/reimprinting/radar doctrines alongside their tier requirements, then Planetary Magos command doctrine and Void Cogitator deployment. Void Cogitator Stations now require Void-Sealed Cargo Unsealing as well as Planetary Magos station doctrine and use blue science, preventing that late void tier from appearing as though it belongs beside early station-radius improvements.

Added consecration target claims to `scripts/core/consecration_executor_0515.lua`. Once a priest selects a machine-spirit target, the executor records a short-lived claim keyed by surface and target unit. Other priests treat the same machine as claimed by another station/priest pair, which should stop the observed behavior where three priests all announce they are going to consecrate the one available machine while moving in conflicting directions. Claims release on completion, invalid target, missing-useful-item, consume failure, apply failure, or timeout. Pair dump diagnostics now include the active consecration claim count.


## 0.1.543 - Blackstone asteroid visual retarget

- Retargeted the cloned Blackstone asteroid family away from inherited Space Age metallic/iron asteroid visuals.
- Added a prototype-stage sprite retarget helper that normalizes nested asteroid/chunk/particle sprite nodes to the 64x64 Blackstone image assets already shipped in `graphics/icons/`.
- Applied `blackstone.png` to asteroid bodies, `blackstone-asteroid-chunk.png` to collectible chunks, and `blackstone-fragment.png` to cloned particulate/debris particles.
- Removed the previous visual dependency on tinting vanilla metallic asteroid graphics for the Blackstone lineage while leaving behavior, collection, spawns, recipes, and platform logic unchanged.

## 0.1.544 — Blackstone particle family, Planetary Magos offset, mining drill operation counter repair

- Lowered the Planetary Magos Cogitator Station sprite another approximate 10% of its visual footprint after live testing still showed a hovering platform.
- Added deterministic jagged Blackstone particle image slices from the included `blackstone-fragment.png` asset: tiny, small, medium, big, and large variants under `graphics/effect/blackstone-particles/`.
- Added an explicit Blackstone asteroid/chunk particle prototype family so renamed Space Age particle references such as `blackstone-asteroid-chunk-particle-medium` exist at data stage instead of failing assignID.
- Strengthened the consecrated mining drill operation sensor: it now polls more often, uses `products_finished` when available, retains output-inventory detection, and adds a progress accumulator so mining operations are still counted when belts/inserters empty output before the polling window observes it.

## 0.1.545
- Fixed Blackstone asteroid chunk boot failure by restoring cloned asteroid/chunk particle references to existing Space Age particle prototype names after Blackstone name replacement. This preserves the Blackstone asteroid/chunk body sprite retarget while avoiding assignID failure on `blackstone-asteroid-chunk-particle-medium`.

## 0.1.546 - Emergency micro visual containment and Planetary Magos station re-anchor

- Re-read `docs/STANDARDS_AND_PRACTICES.md` before packaging this build.
- Raised the Planetary Magos Cogitator Station render shift back upward after the previous downward correction overshot and made the platform sit below its selection frame.
- Added a visual-only emergency shrink clamp for the Martian emergency boiler, atmospheric condenser, emergency steam engine, and emergency smelter so their sprite layers no longer render at monolithic 10x+ apparent scale. Collision, selection, recipe, and behavior footprints are intentionally unchanged.
- Preserved the Blackstone particle registration work from 0.1.545.


## 0.1.547 - Pressurized fluid vault inherited-overlay cleanup

Audited the process used to turn the custom stone vault art into a functional fluid container. The entity was cloned from the vanilla `storage-tank`, and the prior pass only replaced `tank.pictures.picture`. That left inherited storage-tank fluid/window/flow overlay members and pipe-cover artwork active. Those inherited layers are the likely source of the pale rectangular nub visible under the Pressurized Fluid Vault despite the base PNG being clean.

The 0.1.547 pass now replaces the entire `tank.pictures` table with only the custom vault picture and clears inherited `fluid_box.pipe_covers` / `pipe_picture` references. Fluid capacity and north/south pipe connections remain intact; this is a prototype-art cleanup, not a recipe, inventory, collision, or runtime behavior change.


## 0.1.548

- Replaced the primitive acclimator battery-bank prototype with a normal stone-cache container using the battery-cache artwork, removing accidental accumulator/power-network behavior.
- Added a final explicit Martian micro-machine visual doctrine pass that overwrites inherited boiler, generator, furnace, lab, and assembler-style visual branches with the mod-owned single PNG sprites at intended one-tile/two-tile footprints.
- Restored the atmospheric water condenser from the over-shrunk visual clamp to a two-by-two readable footprint.
- Preserved smoke behavior, collision boxes, selection boxes, recipes, and emergency-machine logic.


## 0.1.549

- Corrected Martian emergency micro-machine visual scale doctrine: condenser/boiler/steam engine render as readable 2x2 single-image machines; smelter/lab render as 1x1 single-image machines without recursive post-scaling.
- Restored Primitive Acclimator Battery Bank to accumulator mechanics while preserving its custom battery-bank stone-cache artwork.
- Added Space Age platform-only buildability restrictions to basic and advanced space cargo inventory containers.
- Repaired Pressurized Fluid Vault pipe connection positions while keeping inherited vanilla pipe-cover art suppressed.


## 0.1.550 - Pressurized fluid vault pipe-position load fix

- Read `docs/STANDARDS_AND_PRACTICES.md` before editing.
- Fixed `tech-priests-stone-cache-pressurized-fluid-vault` storage-tank pipe connection positions after Transport Drones tightened the effective bounding box to approximately +/-0.898.
- Changed north/south pipe connection coordinates from +/-1.0 to +/-0.75 so the connections remain inside the entity bounding box during Factorio assignID.
- Preserved the custom vault sprite, storage-tank behavior, and north/south fluid usability.


## 0.1.551 — Battery-bank artwork and fluid vault connection correction

Reviewed standards before packaging. The Primitive Acclimator Battery Bank was confirmed to be an accumulator mechanically, but Factorio 2.0 renders accumulator art through `chargable_graphics`, not the older top-level `picture` and `charge_animation` fields. The battery bank now explicitly replaces `chargable_graphics.picture`, `charge_animation`, and `discharge_animation` with the custom stone-cache battery-bank artwork so vanilla accumulator art cannot bleed through.

The Pressurized Fluid Vault remains a `storage-tank`. Its pipe connections were restored to real north/south pipe-grid positions at `{0, -1.0}` and `{0, 1.0}` while the custom vault bounding box is finalized wide enough to keep those positions legal after Transport Drones compatibility edits. This preserves actual pipe access instead of hiding the assignID problem by moving the ports off the pipe grid.


## 0.1.552 - Locale audit correction and compatibility alias pass

- Read `docs/STANDARDS_AND_PRACTICES.md` before packaging. Current rules require single locale sections, no duplicate locale keys, valid zip root/version/integrity checks, and technology locale coverage for every mod technology prototype.
- Corrected a failed prior locale audit: `servitor-parts` was present as a technology prototype without `[technology-name]` and `[technology-description]` entries.
- Added a defensive unsuffixed `cogitator-operating-radius` technology locale alias for old-save/UI compatibility, while preserving the real suffixed technologies `cogitator-operating-radius-1`, `-2`, and `-3`.
- Added missing shared recipe/item locale aliases for servitor/offworld/relic/void-cargo procurement keys used by the tech chain.
- Re-ran locale duplicate validation and explicit technology locale coverage validation.


## 0.1.553 - primitive acclimator tuning and microfurnace render recovery

- Set the Primitive Acclimator Battery Bank accumulator buffer to 1MJ with 500kW input and 500kW output limits.
- Repaired the Martian microfurnace/smelter visual path by writing the same single custom sprite animation into both furnace animation and graphics_set animation fields, leaving collision and selection boxes unchanged.
- Followed standards checkpoint: no new standalone audit document; package root, version, ZIP, and locale uniqueness validated before surfacing.

## 0.1.554 - Micro-miner recipe menu and cogitator station offset pass

- Reworked the Martian Emergency Micro-Miner so its pseudo-mining outputs are visible selectable recipes in its private recipe category instead of hidden script-only choices.
- Converted the micro-miner to burner fuel operation so the recipes remain input-free but still consume chemical fuel and time.
- Lengthened pseudo-mining recipe times: basic survival materials are slow, uranium is slower, and discovered modded/planetary resources are deliberately very long bootstrap options.
- Raised the Planetary Magos Cogitator Station render offset slightly and lowered the Junior Cogitator Station render offset slightly based on live visual testing.


## 0.1.555 - Hidden proxy turret attachment heartbeat

Added a registry-owned heartbeat to `scripts/core/proxy_turret_alignment.lua`. The pass keeps the hidden small-arms proxy turret physically attached to its visible Tech-Priest shell. If the proxy is valid but too far from the priest, it is teleported back using the existing documented proxy-alignment exception. If the pair lost its proxy reference, the heartbeat may adopt a nearby unowned proxy of the correct prototype/force or recreate the proxy through the existing `ensure_proxy` helper. This is recovery/identity protection only: it clears stale shooting targets after reattachment and does not choose combat work, issue visible movement, or bypass the dispatcher/action-arbiter scheme.

## 0.1.556 - Runtime efficiency economy governor

Added `scripts/core/efficiency_economy_0556.lua` as a late-loaded governor rather than a new behavior controller. The pass raises movement reissue/logging cadences, wraps passive order refreshes behind cooldowns, adds cooldown memory for repeated rejected direct targets and dirt fallbacks, pre-cools repeated duplicate order submissions, compacts periodic pair-dump diagnostics by default, and throttles the most aggressive legacy service sweeps. The goal is to reduce task slam/pathing churn while preserving the existing dispatcher, scheduler, order queue, movement lease, and executor authorities.

## 0.1.557 - Efficiency economy review: radar memoization and shared expansion ghosts

Added `scripts/core/efficiency_economy_0557.lua` as a follow-on governor to the 0.1.556 economy pass. This pass does not create a new behavior controller. It wraps the existing radar and station-expansion paths so radar-detected objects only trigger expensive refresh/flash work on first sighting or after a long recheck interval, and resource-directed station expansion reuses an existing nearby/overlapping expansion ghost instead of letting every Planetary Magos in a pile project its own duplicate senior-station ghost. Resource expansion cadence is slowed, resource expansion is capped to one projected need per pass, and expansion records receive shared-plan metadata for diagnostics.


## 0.1.558 - Conclave Center governance scaffold

- Added the 2x2 Conclave Center prototype using the unused three-monitor skull-console artwork.
- Added item, recipe, locale, and Planetary Magos research unlock for the Conclave Center.
- Added a physical console GUI that opens the Tech-Priest management overview and displays doctrine ladder, conclave vote, and unrest scaffold pages.
- Gated remote Shift+Y command overview access behind having at least one Conclave Center placed for the force.
- Added lightweight doctrine-family technology classification, five-minute conclave vote window scaffolding, and research-finished loyalty relief tracking without adding priest movement, construction, acquisition, consecration, combat, or rogue-force behavior authority.

## 0.1.559
- Added diegetic Conclave Center chronometer language and rotating green skull-gear sigil reuse from the Work-State boot display.
- Added lightweight open-panel refresh so the Conclave timer sprite and countdown update without rebuilding the whole interface.
- Retuned Conclave labels/buttons/messages away from plain UI language toward noospheric/conclave slate terminology.


## 0.1.560 - Trimmed portrait sheet reslicing pass

- Replaced the four GUI portrait source sheets with the newly provided trimmed archive.
- Rebuilt portrait cell extraction from first principles instead of reusing old margin/stride constants. The resulting portrait cell sprites are generated as normalized 128x128 files under `graphics/gui/portraits/cells_0560/`, then registered by `prototypes/portrait_cells_0520.lua` using the same public sprite-name prefixes.
- Re-evaluated the Planetary Magos sheet as a 9x7 valid-cell sheet. The old 9x8 bottom row is no longer referenced because the trimmed asset no longer contains that row cleanly.
- This is UI identity/asset work only. No dispatcher, scheduler, movement, combat, construction, consecration, logistics, proxy turret, or Conclave behavior authority was changed.


## 0.1.561 - Sanctioned order history, authority, and doctrine-tech alignment

Added a governance-only Sanctioned Order History ledger that watches completed order-queue history and records per-priest totals for tasks, consecrations, repairs, acquisitions, logistics, construction, emergency construction, combat, and other completed writs. Authority now starts from rank baseline, with Junior = 1, Intermediate = 2, Senior = 3, and Planetary Magos = 5, and earns one additional order socket per 100000 completed sanctioned rites. This pass exposes authority through a diagnostic command and the Conclave Center without creating a new movement, task, or work-completion controller.

The Conclave Center doctrine ladder now assigns research technologies to doctrine families through a deterministic map-seeded compatibility map. Obvious keyword matches remain dominant, while a small seed-bound divergence chance lets each run develop different doctrinal politics. The Conclave panel now includes a Sanctioned Order History tab, and the unrest ledger can apply first-pass loyalty pressure when a doctrine's priests repeatedly rely on emergency construction beyond the tolerated fifty-rite threshold.


## 0.1.562 - Compact authority ledger and doctrine appeasement research

- Changed Sanctioned Order History from verbose task-category display to compact completed-task service totals.
- Authority now earns at thresholds 1, 10, 100, 1000, and 10000 completed tasks, for a maximum of five authority marks added to base rank authority.
- Added seven infinite repeatable doctrine appeasement researches, one for each Conclave doctrine family. These unlock after Planetary Magos Cogitator Stations and use the existing Conclave research-completion hook to add loyalty to the matching family.
- Left opposed-family loyalty loss as a documented later design choice rather than adding random punitive loyalty decay during this pass.

## 0.1.563 - Portrait Sheet Dimension Repair

- Corrected full-sheet GUI sprite registrations for the trimmed portrait PNGs by reading the actual image dimensions rather than assuming old square sheet sizes.
- Fixed `tech_priest_augmented_portrait_sheet_a.png` registration from the obsolete 1254x1254 rectangle to the real 1235x1233 asset bounds so Factorio no longer attempts to read below the bottom of the file.
- Updated registry metadata for the alternate augmented and Planetary Magos portrait sheets to match the trimmed archive dimensions.
- Left the generated normalized 128x128 portrait cell files in place; this pass repairs the full-sheet prototypes that caused the boot error.


## 0.1.564 - Diegetic Inner Screen GUI Extension

- Added shared green noospheric inner-screen GUI styles for Tech-Priest custom panels.
- Applied the inner-screen style to Work-State Reliquary scroll panes and tables so tab contents are no longer left as vanilla gray panels.
- Extended the same styling pass to the Conclave Center and Machine-Spirit State Ledger custom GUIs.
- Kept behavior/runtime authority unchanged; this is a GUI skinning and readability pass only.


## 0.1.565 - Inner CRT Screen Repair

- Corrected the 0.1.564 GUI skinning pass after live screenshots showed the Machine-Spirit State Ledger and Work-State Reliquary still rendering vanilla gray inner panes.
- Changed Tech-Priest custom GUI scroll panes to use a transparent/naked scroll style inside explicit green Cogitator display frames, so the CRT/noospheric screen frame owns the visible background instead of the vanilla Factorio scroll pane.
- Wrapped Work-State tab pages in inner display frames and applied the Machine-Spirit Ledger outer frame/button/tab/display styles directly.
- Kept runtime behavior, task ownership, combat, and Conclave mechanics unchanged.


## 0.1.566 — Movement enforcement governor

- Added `scripts/core/movement_enforcement_0566.lua` as a governor over existing movement authority, not a new work selector.
- Wrapped `tech_priests_request_movement_0418` to reject non-return movement destinations outside the pair's station work envelope.
- Added a low-frequency sanity pulse that clears stale movement leases, hidden pair targets, and resource/combat anchors that would otherwise continue pulling priests into the distance.
- Overleashed priests are redirected home through the existing movement request authority with cooldowns to prevent repeated command slam.
- Added `/tp-movement-enforcement-0566` diagnostics for rejected far movement, suppressed repeat requests, forced returns, and cleared far combat/resource targets.


## 0.1.567 - GUI Docking, Digital Inner Frame, Micro-Miner Stability

- Reworked Machine-Spirit State Ledger to use the same sliced Cogitator exterior shell family as the Work-State Reliquary.
- Pinned Work-State Reliquary left and Machine-Spirit Ledger right to reduce overlap during dual-panel inspection.
- Replaced tinted vanilla-gray inner frames with the green sliced CRT/bezel graphical set for custom inner display panels.
- Preserved Machine-Spirit tab selection during periodic refresh so Traits/Flaws no longer snaps back to Spirit Seal.
- Stopped Martian Micro-Miner runtime from cycling recipes once a valid selected pseudo-mining recipe is set.
- Reduced consecration overlay sprite scale on furnaces and mining drills by half to correct oversized grime/sheen patches.

## 0.1.568 - Economy efficiency governor pass

- Added `scripts/core/efficiency_economy_0568.lua` as a governor layer over existing authorities, not a new behavior/task controller.
- Reduced script-output churn by rate-limiting repeated emergency heartbeats, repeated passive order-refresh messages, and repeated raw-fallback candidate lines.
- Replaced verbose periodic pair dumps with compact pair-count / active-work / movement / pending-order summaries by default, with `/tp-efficiency-economy-0568 verbose` available when a full dump is needed.
- Phased Planetary Magos resource-expansion scans so newly placed clusters do not all scan and project expansion intent at once; added a small global scan budget per window and per-pair retry cooldown.
- Staggered selected non-critical nth-tick services such as movement recovery, behavior cleanup, planning, network visuals, and GUI boot refreshes while leaving dispatcher/order queue/executor ownership intact.
- Added periodic pruning for radar memoization and cooldown tables so long-running saves do not accumulate unbounded scan/cache history.
- Added `/tp-efficiency-economy-0568` diagnostics for suppressed log lines, deferred resource scans, skipped staggered services, and compact dump counts.



## 0.1.569 - Budgeted economy governor, phase one

Added `scripts/core/efficiency_economy_0569.lua` as the first concrete step toward the megabase efficiency plan. The pass wraps the existing single dispatcher rather than replacing it: active priests and idle priests are serviced in rolling buckets, idle pairs get slower rescan cadence, and selected non-critical background services/reporters receive stronger staggered cadence floors. This is intended to reduce synchronized task slam while preserving the scheduler → dispatcher → executor authority chain.

The pass also adds a low-cost dirty-region cache scaffold fed by build/mine/death events. It does not yet replace consecration or repair scans, but it records changed map chunks so later passes can move from broad repeated scans toward event-driven “only check places that changed” queues. Added `/tp-efficiency-economy-0569` to inspect/toggle dispatcher buckets, background buckets, dirty-region tracking, and pair-index rebuilding.


## 0.1.570 - Dirty-aware scan economy pass

Added `scripts/core/efficiency_economy_0570.lua` as the next clean megabase-efficiency step. This pass remains a governor over existing dispatcher/scheduler/executor authorities. It exposes a shared dirty-region query helper backed by the 0.1.569 dirty-region cache, wraps resource-doctrine fallback scans with short negative-result cooldowns so repeated no-source scans do not hammer the same area every pulse, and updates the station catalog to reuse clean recent snapshots when no nearby dirty region has changed since the last sweep. The station catalog periodic budget is also reduced from four scans per cadence to two, continuing the staggered, budgeted work model.


## 0.1.571 - Maintenance scan economy

- Added `scripts/core/efficiency_economy_0571.lua` as the next small megabase-efficiency governor.
- Repair and consecration executors now receive short no-work cooldown wrappers after they prove a station has no valid local target or no relevant supplies.
- Cooldowns are cancelled early when dirty-region tracking reports nearby entity changes.
- Added damage-event dirty-region marking so damaged machines/walls wake nearby maintenance scans without returning to constant polling.
- Added `/tp-efficiency-economy-0571` for runtime inspection/toggling.
- This pass does not choose targets, move priests, repair, consecrate, mine, construct, or complete work; it only prevents repeated expensive no-result maintenance searches.


## 0.1.572 - Unobserved transit economy

Added `scripts/core/efficiency_economy_0572.lua` as the next megabase-efficiency governor. The module wraps the existing movement request API after the movement controller and prior economy governors are installed. If a Tech-Priest work destination is on the same surface, inside the owning station's operating radius, and not visible to any connected player near the priest, destination, or station, the governor teleports the priest to a nearby non-colliding service position and clears the movement request instead of issuing a pathing command.

Observed priests still walk normally, and hostile/combat/retreat/player-facing movement reasons are excluded. The actual repair, consecration, logistics, acquisition, or construction executor still performs the work after arrival; this pass only replaces unseen transit with a cheaper arrival shortcut. Added `/tp-efficiency-economy-0572` for counters and recent transit records.

## 0.1.573 - Authority corridor logistics/crafting scaffold

- Added `scripts/core/authority_corridor_logistics_0573.lua` as a governor over existing inventory/crafting source resolution, not as a new task controller.
- Subordinate stations now expose home-local inventory sources by default, and may borrow superior station/stash sources only while carrying an active work writ/order chain.
- Borrowed superior sources are used for input/material resolution and removal; output deposit paths remain home-station/local to avoid scattering produced goods through the command hierarchy.
- Added `/tp-authority-corridors-0573` diagnostics for selected-pair authorized station chains and borrow counters.

## 0.1.574 - Cogitator corridor pathing guard

Added `scripts/core/authority_corridor_pathing_0574.lua` as the movement half of the authority-corridor model. This pass does not choose work, complete work, or create a new behavior controller. It wraps the existing movement request API and asks the 0.1.573 authority-corridor scaffold which station spheres are currently authorized for a pair.

Movement now follows the intended doctrine: a priest may path inside its home station radius by default; a subordinate may enter superior station coverage only while carrying an active logistics/acquisition/crafting/construction writ; and unauthorized far destinations are rejected and returned home rather than pathing into the wilderness. Long visible moves toward authorized superior-station coverage can be decomposed into a station-corridor waypoint, so the pathfinder receives shorter station-to-station travel instead of one large uncontrolled path request.

Patched the older 0.1.511 direct movement bounds contract and 0.1.566 movement enforcement governor so they recognize authorized 0.1.574 corridor destinations instead of rejecting them before the corridor guard can act. Added `/tp-path-corridors-0574` diagnostics for selected-pair authorized zones, rejected moves, waypoint decompositions, superior authorized moves, and forced returns.


## 0.1.575 - Corridor cache and phased path-economy pass

- Added `scripts/core/efficiency_economy_0575.lua` as an economy governor, not a new behavior controller.
- Cached short-lived authority-corridor authorization checks so repeated same-priest/same-target path requests do not keep walking the full superior-station writ chain.
- Added phased cleanup for expired writ/corridor hints and stale near-destination route hints.
- Added `/tp-efficiency-economy-0575` for cache counters and manual cache clearing.
- Preserved dispatcher/order queue/executor authority; no new visible work, mining, repair, consecration, or combat path was added.

## 0.1.576 - Diagnostics quiet default, global budget scaffold, and machine recipe reservations

- Changed full-priority diagnostics and emergency diagnostics settings to default off for normal play, with longer default diagnostic intervals when explicitly enabled.
- Added `scripts/core/efficiency_economy_0576.lua` as a governor-only layer that exposes a shared per-tick budget helper for future staged services without choosing work or bypassing dispatcher/order-queue authority.
- Retired the old Martian Micro-Miner doctrine popup; the Micro-Miner is treated as an assembling-machine-style emergency resource producer whose ordinary recipe selector is the source of truth.
- Stopped emergency facility doctrine from repeatedly changing Micro-Miner recipes once a valid emergency mining recipe is selected; it now only assigns one safe default if no emergency recipe exists.
- Added machine recipe reservation claims for Tech-Priest-controlled emergency smelter/assembler/condenser recipe changes. A claimed machine draws a small green reservation marker and rejects recipe changes from other priests until the claim expires or is released.
- This pass is a first contained step toward legacy-controller collapse: it does not delete old controllers yet, but it blocks one visible legacy conflict where recipe-setting helpers fought over the same facility.

## 0.1.577 - Enforced global runtime budgets

- Added `scripts/core/efficiency_economy_0577.lua` as a governor-only economy pass.
- Expensive executor/service-pair pulses now consume the 0.1.576 budget scaffold instead of all running in the same tick.
- Low-priority movement requests now spill into a deferred queue when the path-correction budget is exhausted.
- Preserves combat, retreat, manual, recovery, and high-priority movement as immediate paths.
- Added `/tp-efficiency-economy-0577` diagnostics for the enforced-budget queue and deferral counters.


## 0.1.578 - Catalog prototype-cache economy

- Continued the efficiency candidate program with a low-risk catalog indexing pass.
- Station catalog sweeps now cache stable prototype facts instead of rediscovering them for every entity: supported inventory ids and mineable product definitions are stored by entity type/name.
- Added `/tp-efficiency-economy-0578` to report cache entry counts.
- No task, movement, mining, repair, consecration, or doctrine behavior was changed.

## 0.1.579 — Event-Indexed Catalog Economy

- Added an event-indexed station catalog economy layer for megabase runtime reduction.
- Station catalog scans can now reuse known clean cell contents instead of always calling `surface.find_entities_filtered`.
- Build, revive, mine, death, and script-destroy events mark affected cells dirty and update/remove indexed entity references.
- Unknown or dirty cells still fall back to a normal surface scan, then teach the cell index for later reuse.
- Added `/tp-efficiency-economy-0579` diagnostics for cell/index hit/miss counts.
- This pass does not add a work controller or alter priest task selection; it is a catalog cache service only.


## 0.1.580 - Consecration economy pass

- Added `scripts/core/efficiency_economy_0580.lua` as a governor around the existing consecration update pipeline.
- Replaced full-table `update_all_consecration_targets` pulses with a budgeted rolling service.
- Added dirty-machine priority for built/damaged/removed/operation-completed consecration records.
- Clean idle machines now sleep between sanctity checks while active/recently-operated machines are serviced sooner.
- Added `/tp-efficiency-economy-0580` diagnostic command.


## 0.1.581 - Legacy wrapper consolidation economy

- Added a conservative compatibility shim around legacy global helper functions for pair lookup and station-radius lookup.
- Short-lived caches now reduce repeated reverse-map scans and radius recalculation churn from generated fragments while preserving the old public function names.
- Added `/tp-efficiency-economy-0581` for status, clear, on, and off controls.

## 0.1.582 — Grand behavior-tree economy cache

Added a conservative behavior-tree economy shim. The pass wraps the dispatcher and the legacy `tick_pair` route so repeated idle/no-work decisions can sleep for a short cache window instead of re-running the whole high-level behavior stack when nothing has changed. Active orders, combat, repair, consecration, acquisition, crafting, manual/recovery pulses, and entity-change events still invalidate or bypass the cache. Added `/tp-efficiency-economy-0582` diagnostics.


## 0.1.583 - Visual/render economy pass

- Added `scripts/core/efficiency_economy_0583.lua` as a render-governor shim, not a behavior controller.
- Wrapped transient runtime rendering calls used by this mod so offscreen status text, beams, circles, lights, and reservation icons are not freshly created when no connected player is near the target area.
- Preserved explicitly player-filtered overlays so selected network/radius diagnostics still render when deliberately requested.
- Added `/tp-efficiency-economy-0583` with on/off, skip-on/skip-off, radius, and status controls.

## 0.1.584 - Obstacle slap-fight guard

- Added `scripts/core/obstacle_attack_guard_0584.lua` as a movement sanity governor, not a new work selector.
- Detects Tech-Priests that are already under movement/work orders but have fallen into a Factorio unit attack command against a neutral obstruction such as a tree, rock, boulder, simple entity, cliff, or resource.
- Stops the priest's weak default melee attack and performs a budgeted obstruction-clear pulse through the existing station force/inventory context.
- Respects authority corridor position checks before clearing so the guard does not authorize far off-mission clearing.
- Added `/tp-obstacle-guard-0584` diagnostics.

## 0.1.585

- Added dirty/event coalescing economy around existing catalog and consecration dirty markers.
- Build/damage/remove bursts now de-duplicate same-entity invalidations and flush them through a small budgeted queue.
- Preserved existing dispatcher/authority routes; no new behavior controller added.


## 0.1.586 - Optional lean GUI sprite graphics mode

Added a startup-gated lean GUI sprite mode that uses generated half-resolution copies for oversized decorative GUI SpritePrototypes, compensating with sprite scale so layout remains stable. Full-resolution art remains the default. This is a low-risk graphics-memory/load pass focused on GUI assets rather than entity sprites or gameplay icons.

## 0.1.587 — Logistics/Supply Cache Economy

Added a conservative logistics economy governor around existing inventory steward, station work inventory, and authority-corridor logistics APIs. Repeated same-priest/same-item source lists, authorized station lists, and item-count queries now use very short-lived caches with broad invalidation on entity topology changes and after successful removals. This pass does not create work, craft, mine, move, or alter deposit doctrine; it only reduces repeated Lua/source-walking overhead during logistics and emergency-production bursts. Added `/tp-efficiency-economy-0587` for live cache counters and toggles.

## 0.1.588 — Doctrine Web, Rogue Forces, and Hierarchy-Local Logistics

Tightened the logistics cache so supply/source/count answers remain local to a pair and its direct superior chain until a future intranetwork-link building exists. Unrelated Tech-Priest hierarchies on the same force and surface should no longer share cached logistics answers by accident. Expanded the Conclave Center with a Doctrine Web tab that lists doctrine dislikes, currently available research affinities, seed-basis assignments, and recent doctrinal incidents. Research now grants loyalty to its favored family as before, while families that doctrinally dislike that research family have a small deterministic chance to lose one loyalty. If a doctrine reaches zero loyalty, existing members of that family defect to a named rogue force such as `tech-priests-rogue-logistics`; newly placed priests remain loyal to the player force unless later driven into schism themselves.


## 0.1.589 - Conclave schism governance settings

- Added runtime-global Conclave settings for enabling/disabling doctrine rebellions and for allowing/disallowing defecting doctrine stations to seize nearby player machines.
- Reworked zero-loyalty schism handling so the hostile defectors become a separate rogue force while the loyal doctrine family's Conclave loyalty resets to baseline for newly placed priests.
- Added optional station-radius machine seizure for schisms when the player disables the "Don't Touch My Toys" protection.
- Added Doctrine Web policy and recent schism-wave reporting so players can see rebellion/seizure behavior in the Conclave UI.
- Preserved the authority stack: schism logic changes force ownership and governance state only; it does not add new movement, crafting, combat, or logistics controllers.

## 0.1.590 — Schism force inheritance and Data Spike reclamation

- Rogue doctrine forces now inherit the parent force's researched technologies and enabled recipes when a doctrinal schism creates or reuses that force.
- Rogue doctrine forces are explicitly hostile to the parent force and to other rogue doctrine forces, allowing multiple schismatic families to become separate hostile factions rather than one generic rebellion bucket.
- Converted schism pairs are marked for rogue emergency self-sustainment so their behavior state records that they are no longer loyal Conclave participants.
- Added the Data Spike as a Planetary Magos-era reclamation countermeasure. It is a long-range capsule that script-triggers a reclaim attempt on hostile Tech-Priests, Cogitator Stations, and common seized structures.
- Data Spike recovery of a Tech-Priest or Cogitator Station reclaims the paired station, priest, and hidden proxy turret together when the pair can be identified.

## 0.1.591 — Timed Data Spike Reclamation and Void Doctrine Hard Loyalty

- Moved Data Spike unlocking out of Planetary Magos station research into a four-tier Data Spike Reclamation chain. Tier I unlocks the spike and starts from a 90-second visible claim timer; tiers II-IV reduce the attacker-side countdown by 20 seconds each before defender hardening is applied.
- Added repeatable Data Spike Defense research. Each level adds 10 seconds to hostile Data Spike capture timers against that force's entities.
- Reworked Data Spike impact handling from instant ownership flip to a player-only timed claim. Counter-spiking the same target from another force cancels/replaces the prior claim; mining/removing the target cancels the pending claim.
- Preserved reclaim behavior for full Tech-Priest/Cogitator pairs when the timer completes, including hidden proxy turret ownership.
- Made Void Doctrine internally hard-loyal so the space/void family resets loyalty at schism threshold instead of defecting.


## 0.1.592 — Surface-Scoped Schisms and Emergency Stand-Down

- Read standards and authority-refactor continuity before editing runtime governance behavior.
- Doctrine schisms now convert only the surface containing the majority of that doctrine family’s loyal participants, preventing isolated priests on distant planets from dragging an entire doctrine into a nonsensical offworld revolt.
- Added stocked-station emergency stand-down timers: loyal stations that have ammunition, repair packs, and sacred oil/appeasement items stocked arm a deterministic seed-based timer between one and fifteen minutes, then exit emergency construction posture if supplies remain stable.
- Doctrine loyalty events now record the most recent influence per family for display in the Conclave Doctrine Web and per-priest Doctrine Web Reliquary.
- Void Doctrine remains hard-loyal and schism immune.

## 0.1.593
- Hard runtime performance firewall: suppresses non-critical Tech-Priests runtime logs when diagnostics are off.
- Adds short-lived direct-acquisition target caching and movement reissue holding to reduce repeated scans/pathing calls.
- Adds /tp-efficiency-economy-0593 counters.


## 0.1.594 - Adaptive route economy pass

- Added `scripts/core/efficiency_economy_0594.lua` as a post-registration governor around `TechPriestsRuntimeEventRegistry` nth-tick routes.
- Wrapped non-critical registered routes in-place instead of adding a new behavior controller.
- Diagnostics routes are skipped in normal play when diagnostics settings are disabled.
- Visual/audio/GUI/presentation routes receive deterministic skip multipliers under busy/heavy/extreme priest counts.
- Inventory/scheduler/background routes receive lighter deterministic skip multipliers only at large priest counts.
- Movement, combat, recovery, lifecycle, corridor, obstacle, dispatcher, and arbiter routes are treated as critical and are not throttled by this pass.
- Added `/tp-efficiency-economy-0594` to report current pair count, adaptive tier, wrapped route count, skipped route count, and diagnostics state.



## 0.1.595 - Dormant runtime gate

- Added a dormant runtime gate so nth-tick Tech-Priest services remain asleep before any Tech-Priest runtime entities/pairs/stations/conclave systems exist.
- Hooked the gate through the runtime event registry dispatcher instead of adding a new behavior controller.
- Build/research/player events still run and can awaken the runtime when relevant Tech-Priest entities or technologies appear.
- Added `/tp-runtime-dormant-0595` for live-state inspection.

## 0.1.596 - Early passive-service austerity gate

- Added `scripts/core/efficiency_economy_0596.lua` and load it at the very top of `control.lua` before legacy fragments.
- Wrapped raw `script.on_nth_tick` registrations so legacy direct nth-tick services are dormant-gated until the 0.1.595 runtime gate reports that Tech-Priest runtime entities exist.
- Preserved the runtime event registry route and did not add a new behavior controller; this pass only gates passive periodic services that previously bypassed the registry.
- Added `/tp-efficiency-economy-0596` for telemetry on wrapped, skipped, and allowed raw nth-tick calls.

## 0.1.597 - Order Orchestrator / Resource Reservation Economy

- Added a non-controller order orchestration shim that wraps the existing resource doctrine and order queue.
- Resource acquisition now receives short-lived source/tile reservations so many priests requesting the same item do not all choose and path toward the same resource entity.
- Added station/item source caching and short no-source cooldowns to reduce repeated scans when many priests ask for the same unavailable item.
- Added `/tp-order-orchestrator-0597` diagnostics for reservation/cache counters.
- Preserved the existing dispatcher/order-queue/resource-doctrine behavior path; this pass coordinates target choice before pathing rather than replacing priest AI.

## 0.1.598 - Efficiency standards and cooperative parallelization route economy

- Added an explicit efficiency/cooperative-parallelization rule to `docs/STANDARDS_AND_PRACTICES.md` because the project now needs enforceable runtime performance doctrine, not just ad hoc throttles.
- Added `scripts/core/efficiency_economy_0598.lua`, a deterministic route-budget shim that treats Factorio's single-threaded Lua model as cooperative parallelization: non-critical diagnostics, visuals, GUI, audio, chatter, conversation, doctrine, and background scheduler routes are phase-sliced across ticks as active priest counts rise.
- Patched the runtime event registry nth-tick dispatcher with a single budget hook so future route economy can happen centrally instead of each module inventing another periodic controller.
- Preserved critical lifecycle, dispatcher, combat, movement, recovery, safety, acquisition, crafting, construction, repair, consecration, inventory, and authority routes as immediate.
- Added `/tp-efficiency-economy-0598` to report/toggle the route economy and show counters for allowed/deferred categories.

## 0.1.599

- Added adaptive priest sleep states as an efficiency governor around legacy `tick_pair` calls.
- Fully idle, unobserved priests progressively sleep longer between probes.
- Build, mine, damage, death, research, selection, and opened-station interactions wake nearby or global sleep state.
- Added `/tp-efficiency-economy-0599` diagnostics.


## 0.1.600 - Runtime broker and first pair-bucket spine

- Added `scripts/core/runtime_tick_broker.lua` as the first central budgeted runtime service broker.
- Added `scripts/core/pair_bucket_registry.lua` with basic `active`, `idle`, `invalid`, `repair`, `logistics`, `combat`, `movement`, `visible`, `dirty`, and `sleeping` buckets.
- Registered the broker and bucket registry from `control.lua` before broker-aware order/repair services install.
- Converted `order_queue_0469.lua` periodic ticking to register through the runtime broker when available, preserving registry/direct fallback paths.
- Converted `repair_executor_0516.lua` periodic repair service to register through the runtime broker and service only the `repair` pair bucket, preserving legacy/scheduler wrapping and registry fallback.
- Added `/tp-runtime-report` to report broker services, service counters, and pair bucket counts.

## 0.1.601 - Shared repair reservations and work queue authority

- Added `scripts/core/work_reservations.lua` as a shared short-lived reservation authority for repair, sanctify, resource, construction, pickup, and combat work.
- Added `scripts/core/work_queue_authority.lua` as a surface/force/category work queue authority so discovered work can be folded once and claimed by suitable priests instead of rediscovered by each priest independently.
- Registered reservation and work queue cleanup services through the central runtime broker instead of adding new independent nth-tick controllers.
- Integrated `repair_executor_0516.lua` with the shared repair reservation layer while preserving its local legacy fallback reservation table.
- Integrated repair target discovery with the shared repair work queue: repair candidates can be submitted once, duplicate queue submissions fold, and repair bucket pairs claim nearest eligible work.
- Expanded `/tp-runtime-report` to include reservation and work queue counters.
- Extended the pair bucket repair classification so existing shared repair queue work can wake repair bucket servicing rather than idling until a private pair order exists.

## 0.1.602 - Efficiency authority inventory standard

Added a standards-and-practices rule requiring an audit of existing runtime authority layers before introducing new efficiency machinery. This is meant to prevent stacking multiple schedulers, queues, reservations, caches, throttles, and sleep-state systems over the same behavior without a clear owner. Future efficiency passes must identify the current owner, existing delay/budget/cache mechanisms, replacement vs. duplication status, the legacy path being removed or demoted, and the diagnostic counter that proves the change reduces work rather than merely delaying it through another layer.


## 0.1.603 - Runtime authority boundary cleanup

- Documented the explicit runtime authority boundary: Work Queue finds jobs, Reservation claims jobs, Order Queue executes jobs.
- Reviewed `order_queue_0469.lua`; it remains the per-pair execution stack and wrapper/adoption layer, not a shared world-work discovery authority.
- Reviewed `work_queue_authority.lua`; added repair discovery ownership there so shared repair candidates are found and folded by the work queue authority rather than by the repair executor maintaining its own broad discovery path.
- Reviewed `repair_executor_0516.lua`; removed its direct repair-area scan/submit/select block and made it defer repair discovery to `work_queue_authority.discover_repair_near()` before claiming through `claim_nearest()`.
- Preserved reservation ownership through `work_reservations.lua`; repair work is still claimed through the reservation authority before execution/pathing.
- Expanded work-queue runtime report counters with repair discovery scans, checked entities, and submitted repair work so we can see whether discovery is occurring in the owning authority instead of being duplicated elsewhere.


## 0.1.604 - Efficiency authority audit and dirty-cache consolidation

- Read `docs/STANDARDS_AND_PRACTICES.md` and `docs/AUTHORITY_REFACTOR_CONTINUITY.md` before editing runtime economy behavior. Current standards require locale uniqueness, packaging validation, history notes in this file, a pre-build standards checkpoint, dispatcher/executor continuity, cooperative scheduling instead of broad scan loops, an efficiency-authority inventory before new optimization systems, and strict runtime boundaries: Work Queue finds jobs, Reservation claims jobs, Order Queue executes jobs.
- Audited all `efficiency_economy_*.lua` modules and confirmed existing dirty/cache/sleep ownership already exists: 0569 owns the dirty-region scaffold, 0570 owns dirty-aware helper queries and negative scan cooldowns, 0579 owns the indexed catalog cell cache, 0585 owns dirty-event coalescing, 0582 owns calm/no-work behavior caching, 0595 owns whole-runtime dormancy before Tech-Priest entities exist, and 0599 owns per-priest adaptive idle sleep.
- Decided not to add a new dirty-region cache or new sleep system. The canonical scan-cache authority remains `efficiency_economy_0579`; the older 0569/0570/0571/0585 modules remain dirty markers, helpers, cooldowns, and coalescers beneath that authority rather than competing world-query systems.
- Updated `work_queue_authority.discover_repair_near()` to consult the existing 0.1.579 indexed catalog cell cache first through `entities_for_area()`. Only when the cache is missing or dirty does the work queue perform a direct `find_entities_filtered()` scan, after which it reports the scan back to `note_area_scan()` so future discovery can reuse the canonical index.
- Expanded `/tp-runtime-report` with an Efficiency Authority Inventory section that surfaces canonical ownership and live counters for dirty-region marks, dirty-aware negative cache hits/skips, indexed catalog cells/entities/dirty cells, dirty-event coalescing, calm behavior cache skips, dormant runtime sleep, and adaptive priest sleep state.
- Preserved the authority boundary cleanup from 0.1.603: the Work Queue discovers shared jobs, Work Reservations claim targets, and the Order Queue executes per-priest action stacks. This pass consolidates reporting and routing through existing cache/sleep systems rather than creating another efficiency layer.

## 0.1.605 — Timing Authority Consolidation Pass

- Expanded the Efficiency Authority Inventory with explicit timing ownership boundaries: runtime event registry owns Factorio hooks, runtime tick broker owns budgeted recurring service execution, dormant/budget governors own skip gates, and behavior modules own behavior logic only.
- Migrated five recurring direct nth-tick services into `runtime_tick_broker`: behavior execution doctrine 0505, construction planner 0359, emergency facility doctrine 0357, inventory steward 0357, and mobility/recovery contract 0506.
- Preserved registry/direct nth-tick fallback paths only for install-order safety if the broker is unavailable.
- Expanded `/tp-runtime-report` with timing authority counters: registry nth-tick route keys, registry nth-tick handler count, broker service count, and remaining static direct fallback audit count.
- Reaffirmed sleep ownership: 0595 is whole-runtime dormant gating, 0599 is pair/priest adaptive sleep, 0582 is a compatibility shim, and pair-bucket sleeping is classification only.


## 0.1.606 — Runtime Telemetry Refinement and Planning Pass

- Refined `runtime_tick_broker.lua` telemetry without creating a new runtime authority. Broker skips are now split into empty, sleeping, not-due, disabled, budget-exhausted, and error counters instead of one blended idle count.
- Added rolling metric windows to the runtime broker so `/tp-runtime-report` can show recent 60-second activity for service runs, errors, path requests, direct scans, cache hits, and cache misses instead of only lifetime totals.
- Added a small runtime telemetry sink exposed as `_G.tech_priests_runtime_metric_0606` so existing authorities can report counters without becoming subordinate to a new scheduler/cache/sleep system.
- Wired the existing indexed catalog (`efficiency_economy_0579.lua`), repair discovery (`work_queue_authority.lua`), and movement controller (`movement_controller.lua`) into unified scan/path telemetry. The report now surfaces attempted scans, cache redirects, cache hits/misses, negative skip placeholders, direct surface scans, estimated scans avoided, movement requests, collapsed requests, retarget holds, task-transition holds, and engine movement commands.
- Added `docs/FUTURE_EFFICIENCY_CANDIDATES.md` as a planning-only document for spatial interest management, movement intent reuse, squad tasks, deferred reevaluation, event-driven transitions, and GUI/audio/visual emission budgeting. It explicitly does not authorize new efficiency authorities without passing the existing authority-inventory rule.

## 0.1.607 — Event-Driven Work Feeder, Candidate E First Slice

Standards checkpoint: reviewed `docs/STANDARDS_AND_PRACTICES.md` before editing. The locale rule, packaging rule, behavior-development rule, documentation history rule, pre-build standards checkpoint rule, authority-refactor continuity rule, efficiency/cooperative parallelization rule, efficiency authority inventory rule, runtime authority boundary rule, and timing authority consolidation standard remain active. This pass does not add a new scheduler, cache, reservation layer, queue layer, sleep layer, or execution authority.

Efficiency authority inventory answers before implementation:

1. Existing owner: work discovery remains owned by `work_queue_authority.lua`; target claims remain owned by `work_reservations.lua`; execution remains owned by `order_queue_0469.lua` and executors; timing remains owned by `runtime_tick_broker.lua` through `runtime_event_registry.lua`; dirty/index cache remains owned by `efficiency_economy_0579.lua` with existing subordinate dirty helpers.
2. Existing scheduler/cache/sleep coverage: broker services, pair buckets, reservations, indexed catalog, and adaptive sleep already apply. This pass does not add any additional delay gate.
3. Change role: `event_driven_work_feeder_0607.lua` feeds existing authorities only. It turns high-signal `on_entity_damaged` events into shared repair work submissions so polling repair discovery has less work to find later.
4. Old path reduced: periodic repair discovery no longer has to be the only fast path for damaged machines; damaged entities can enter the shared repair queue immediately through the event path.
5. Diagnostic proof: `/tp-runtime-report` now surfaces event-fed repair candidates, submissions, duplicate folds, failures, and per-tick budget skips. If this pass helps, repair work should show more event-fed submissions and fewer direct repair discovery scans over time.

Changes:

- Added `scripts/core/event_driven_work_feeder_0607.lua` as a leaf helper beneath the event registry.
- Registered `on_entity_damaged` through `runtime_event_registry.lua` to submit repair candidates to `work_queue_authority.lua`.
- Added a conservative per-tick damage-event budget so mass combat damage cannot flood the shared work queue with unlimited event work in one tick.
- Added event-fed telemetry metrics to the runtime broker report:
  - `event_repair_candidates`
  - `event_repair_submitted`
  - `event_repair_duplicate_folded`
  - `event_repair_submit_failed`
  - `event_repair_budget_skipped`
- Fixed the malformed `rolling-60s` report line introduced during the 0.1.606 telemetry pass so `runtime_tick_broker.lua` remains syntactically coherent.

Notes for live testing:

- Damage a wall, turret, assembler, or other repairable entity near a station and run `/tp-runtime-report`.
- Expected signal: `event-fed-accounting repair_submitted` should increase and `work-queues repair=` should briefly show queued repair work unless a priest claims it immediately.
- Duplicate damage events against the same entity should fold into the existing repair order rather than creating many repair jobs.
- This pass intentionally does not event-drive construction, sanctification, resource discovery, or pickup yet. Those should only be added after the repair damage path proves stable.


## 0.1.608 - Directed repair wakeups for event-fed work

Standards checkpoint: this pass reviewed the current authority boundaries before coding. Existing owners remain unchanged: `runtime_event_registry.lua` receives events, `runtime_tick_broker.lua` owns budgeted cadence, `pair_bucket_registry.lua` classifies eligible pairs, `work_queue_authority.lua` records shared work, `work_reservations.lua` claims targets, `order_queue_0469.lua` executes per-priest orders, `efficiency_economy_0570.lua` owns negative-result cooldowns, `efficiency_economy_0579.lua` owns indexed dirty catalog reuse, and `efficiency_economy_0599.lua` owns adaptive pair sleep.

Efficiency questions answered before implementation:

1. Existing owner: damage events are received through `runtime_event_registry.lua`; repair jobs are fed to `work_queue_authority.lua`; pair eligibility is represented by `pair_bucket_registry.lua`; adaptive sleep is governed by `efficiency_economy_0599.lua`.
2. Existing scheduler/cache/sleep layers already apply: broker timing, pair buckets, shared work queues, reservations, indexed catalog 0579, dirty/negative helper 0570, and adaptive sleep 0599.
3. This change feeds those existing authorities. It does not replace or duplicate them.
4. No old controller was removed in this pass. The older broad repair-queue bucket fallback remains as a safety fallback until repair discovery is fully directed. The new path adds a short-lived directed repair bucket hint so damage events can wake one nearby relevant pair instead of relying only on later broad rediscovery.
5. Diagnostic proof points: `/tp-runtime-report` now surfaces directed repair wakeups, already-awake skips, no-pair misses, and event-cleared negative-cache counts.

Implemented changes:

- Replaced the 0.1.607 event feeder with `scripts/core/event_driven_work_feeder_0608.lua`.
- Damage events still submit repair work to the existing shared work queue.
- Damage events now find the nearest valid same-surface/same-force pair within a conservative radius and mark it with a short-lived repair wake hint.
- `pair_bucket_registry.lua` now supports a leaf `force_bucket(pair, bucket, ttl, reason)` helper for short-lived directed bucket hints. This helper classifies; it does not execute work.
- `efficiency_economy_0599.lua` now exposes `wake_pair(pair, reason)` so event-fed repair work can clear adaptive sleep for the affected pair without waking every priest.
- `efficiency_economy_0570.lua` now exposes `clear_near_entity(entity, reason)` as a best-effort clearing hook for existing negative-source cooldowns near a high-signal event. This is intentionally not a new negative cache.
- The event feeder marks the existing 0579 indexed catalog dirty on damage events so cached area knowledge does not suppress repair discovery after the world changes.
- Runtime telemetry now includes directed wake, already-awake, no-pair, and negative-clear counters in both cumulative and rolling-window report lines.

Design note: the broad repair-queue fallback in `pair_bucket_registry.lua` remains deliberately in place for safety. The directed wake path is the preferred fast path, but it should not yet be the only path until live testing confirms repair work is never stranded when no event-fed wake hint exists.


## 0.1.609 — Spatial Interest Theater-Gate Review

Efficiency inventory answers before implementation:

1. Current authority: visual/audio presentation remains owned by overhead status, sound manager, placeholder/operational audio, and visual lease authorities. Sleep remains owned by 0595/0599/0582; pair classification remains owned by pair buckets.
2. Existing governors already apply: pair buckets, adaptive sleep, broker telemetry, and event-driven wakeups. This pass does not add a new scheduler, cache, reservation, or sleep state.
3. Change type: leaf telemetry/helper feeding existing presentation authorities. It classifies whether a pair/entity is observed by a nearby/selected player and allows nonessential theater to be skipped when remote.
4. Removed/demoted path: periodic overhead status refreshes no longer redraw for low-detail remote pairs. Machine audio warnings may skip offscreen emission through the same helper. Simulation work is untouched.
5. Diagnostic counters: `/tp-runtime-report` now surfaces `spatial-interest-0609` tier counts plus theater allowed/suppressed, overhead suppressed, and audio suppressed counters.

Boundaries: `spatial_interest_0609.lua` is not a sleep layer and must not choose work, claim targets, schedule services, or execute priest actions. It exists only to reduce nonessential presentation churn for offscreen/remote entities.


## 0.1.610 — Cache-first scan routing pass

Efficiency inventory answers before implementation:

1. Current authority: `efficiency_economy_0579.lua` remains the canonical indexed dirty/catalog cache. `efficiency_economy_0570.lua` remains the older resource negative-result helper. No new cache authority was created.
2. Existing governors already apply: runtime broker, pair buckets, shared work queues, reservations, event-fed repair work, directed wakeups, spatial-interest theater suppression, indexed catalog reuse, and adaptive sleep.
3. Change type: scan-routing helper only. `scan_routing_0610.lua` asks the existing indexed catalog first, falls back to direct `surface.find_entities_filtered` only when the indexed cells are unknown/dirty/disabled, and records telemetry.
4. Removed/demoted path: repeated repair discovery, consecration target discovery, ground item pickup scans, retention-box scans, and resource doctrine item/inventory/mineable scans now route through the cache-first helper before direct scanning. Direct scans remain fallback paths.
5. Diagnostic proof points: `/tp-runtime-report` now includes `scan-routing-0610` counters, plus the existing unified scan-accounting totals.

Boundary: `scan_routing_0610.lua` does not own work selection, reservations, execution, scheduler cadence, or the dirty index itself. It is a leaf router that prevents repeated discovery code from bypassing the existing indexed cache.

## 0.1.611 — Movement active-request service pass

Standards checkpoint: this pass reviewed `docs/STANDARDS_AND_PRACTICES.md` before packaging. Existing ownership remains unchanged: timing belongs to `runtime_tick_broker.lua`, pair classification belongs to `pair_bucket_registry.lua`, movement/path commands belong to `movement_controller.lua`, work discovery belongs to `work_queue_authority.lua`, and indexed scan reuse belongs to `efficiency_economy_0579.lua` through `scan_routing_0610.lua`. No new scheduler, cache, reservation, sleep, or queue authority was added.

Efficiency inventory answers before implementation:

1. Current owner: movement/path pressure is owned by `movement_controller.lua` and its movement authorities. The broker may time the service, but it does not choose movement targets.
2. Existing governors already apply: the runtime broker, movement controller retarget holds, path request collapsing, task-transition holds, pair buckets, and adaptive sleep all already exist.
3. Change type: consolidation beneath the existing movement owner. Movement requests are now tracked as active request ids so movement servicing can process outstanding movement intents instead of scanning every priest/station pair every service tick.
4. Old path reduced: the movement service and movement sample loop no longer need to iterate all pairs just to discover whether a movement request exists. Existing requests from old saves are migrated into the active-request set on first load.
5. Diagnostic proof points: `/tp-runtime-report` now includes movement-controller active request counts, active movement processed totals, invalid/expired request pruning, and movement budget exhaustion. The broker rolling line also shows active movement processing and movement budget exhaustion.

Implemented changes:

- Updated `scripts/core/movement_controller.lua` to maintain `active_request_ids` beneath the existing movement controller storage root.
- Movement requests mark the pair as active movement work and apply a short-lived existing `pair_bucket_registry` movement hint for classification only.
- `M.service()` now processes active movement request ids with a broker budget instead of broadly looping all pairs.
- `M.sample()` now samples active movement request ids with a broker budget instead of sampling all pairs every sample tick.
- Movement service and sample are now registered as `runtime_tick_broker` services when the broker is available, with registry/direct `script.on_nth_tick` only as fallback.
- Expanded `/tp-runtime-report` with movement-controller active-request telemetry.

Boundary: this pass does not cache engine paths and does not invent a new pathfinding layer. It only makes the existing movement controller cheaper by letting it service known active movement intents.

## 0.1.612 — Scan-routing continuation for construction and logistics

Standards checkpoint: this pass reviewed `docs/STANDARDS_AND_PRACTICES.md` before packaging. No new scheduler, cache, queue, reservation, sleep, or movement authority was added. Existing ownership remains unchanged: repeated discovery should route through `scan_routing_0610.lua`, which remains a leaf helper over the canonical indexed catalog `efficiency_economy_0579.lua`; construction planning still belongs to the construction planner modules; logistics fetch and machine servicing still belong to their existing executors.

Efficiency inventory answers before implementation:

1. Current owner: construction placement/resource discovery is owned by `construction_planner.lua` and `construction_site_planner.lua`; loose-item fetching is owned by `logistics_fetch_executor_0527.lua`; machine service discovery is owned by `logistics_machine_fulfillment_0528.lua`; scan reuse is owned by `scan_routing_0610.lua` over indexed catalog `0579`.
2. Existing governors already apply: runtime broker cadence, scan-routing cache-first fallback, negative-result TTLs, movement active requests, work queues/reservations for shared work categories, and adaptive/spatial presentation gates.
3. Change type: leaf routing consolidation only. Direct high-frequency `surface.find_entities_filtered` calls in these discovery paths now ask the existing scan router first and fall back to direct scanning only through that helper.
4. Old path reduced: construction clearance/miner/resource checks, construction-site planner clearance/miner/resource checks, logistics loose-ground pickup checks, machine servicing machine scans, adjacent-automation scans, and retention/waste container scans no longer bypass the cache-first scan router.
5. Diagnostic proof points: `/tp-runtime-report` `scan-routing-0610` now aggregates all category prefixes dynamically, so construction and machine-logistics scan attempts/cache hits/direct fallbacks are included rather than hidden behind only the original fixed category list.

Boundary: this does not change construction placement rules, logistics source ownership, machine servicing behavior, pathfinding, task assignment, or reservation behavior. It only reduces repeated world-polling pressure by routing more existing scans through the already-approved cache-first scan path.


## 0.1.613 — Event/Queue Pressure Reduction Pass

Standards checkpoint followed before packaging: locale uniqueness, valid ZIP root/version, development-history append, authority-refactor continuity, no duplicate runtime efficiency authority, and no new scheduler/cache/sleep/task-selection layer.

Efficiency authority inventory answers:

1. Existing owner: work backlog remains `work_queue_authority.lua`; dirty/index knowledge remains `efficiency_economy_0579.lua` with `0570` negative-source clearing as a subordinate helper; event registration remains `runtime_event_registry.lua`; execution remains order/executor owned.
2. Existing governors already apply: broker timing, pair buckets, work queues, reservations, scan routing, indexed cache, negative-source cooldowns, and adaptive sleep.
3. This pass feeds/refines those authorities. It does not replace them and does not introduce another authority.
4. Removed/demoted behavior: duplicate queue submissions no longer become stale no-op folds; they refresh the existing order priority/expiry instead of requiring later rediscovery. Build/mine/destroy events now mark existing cache/negative authorities dirty instead of waiting for polling fallback to notice.
5. Diagnostic counters: `/tp-runtime-report` now exposes work-queue `refreshed` and `claim_examined` counts plus event-feeder dirty-event `dirty_seen`, `dirty_touched`, and `dirty_invalid` counters.

Implemented changes:

- `work_queue_authority.lua` duplicate submissions still fold into one order, but now refresh the existing order's priority, expiry, duplicate count, and source telemetry.
- `work_queue_authority.lua` tracks how many orders claim attempts examine, making queue-pressure visible before adding any spatial shard/index inside the queue authority.
- `event_driven_work_feeder_0608.lua` now listens to build, robot-build, script-raised-build, player-mined, robot-mined, entity-died, and script-raised-destroy events as dirty/negative invalidation signals only.
- Those world-change events feed the existing `0579` dirty/index authority and `0570` local negative-source clearing helper. They do not submit unconsumed construction/sanctify/pickup jobs yet and do not directly execute work.

Rationale:

The previous scan-routing passes reduced repeated broad polling, but queue pressure can still build through duplicate event/discovery submissions and stale negative knowledge after world changes. This pass keeps the existing authority graph intact while making duplicate work folding more useful and making existing dirty/negative systems more event-aware.

Next review target:

Watch `/tp-runtime-report`. If `claim_examined` climbs sharply while actual claims stay low, the next bounded queue-owner revision should consider an internal work-queue cell index or category-local round-robin cursor inside `work_queue_authority.lua`. That must remain inside the existing work queue authority, not become a second work queue.


## 0.1.614 — Work Queue Spatial Claim Pressure Reduction

Standards checkpoint followed before packaging: this pass reviewed `docs/STANDARDS_AND_PRACTICES.md`, respected the efficiency authority inventory rule, preserved the runtime authority boundary rule, and did not add a new queue, scheduler, cache, sleep, reservation, movement, or execution authority.

Efficiency authority inventory answers:

1. Existing owner: shared backlog storage and claim candidate selection are owned by `work_queue_authority.lua`. Reservations remain owned by `work_reservations.lua`; per-priest execution remains owned by `order_queue_0469.lua`; timing remains owned by `runtime_tick_broker.lua`.
2. Existing governors already apply: broker cadence, pair buckets, shared work queues, reservations, scan routing, indexed dirty cache, event-fed repair jobs, directed wakeups, movement active requests, and adaptive/spatial presentation gates.
3. This change refines the existing work queue authority internally. It does not replace the queue and does not add a parallel queue.
4. Reduced path: `claim_nearest()` no longer has to begin every claim by scanning the entire surface/force/category bucket. It now checks a small nearby spatial cell set first and only falls back to the old full-bucket scan when no nearby indexed claim is available.
5. Diagnostic counters: `/tp-runtime-report` now exposes work-queue `spatial_hit`, `spatial_miss`, `spatial_examined`, and `full_fallback` counters alongside existing `claim_examined` totals. A healthy result is lower `claim_examined` growth per successful claim, especially in large saves with many queued jobs.

Implemented changes:

- Added a simple 64-tile cell index inside `work_queue_authority.lua` under the existing authority storage root.
- `submit()` now indexes new queued orders by surface, force, category, and cell. Duplicate folds preserve/update the same order and ensure it is indexed.
- `claim_nearest()` now inspects nearby cells around the claiming station first, with a bounded spatial examination budget, then uses the previous full-bucket scan as a safety fallback.
- Cleanup and claim removal remove orders from the internal spatial index as well as from the canonical bucket.
- Expanded work-queue report telemetry so future passes can decide whether a stronger spatial strategy is justified.

Rationale:

The previous pass made `claim_examined` visible and showed the next likely pressure point: even with duplicate order folding, a claim attempt can still examine too much backlog if many jobs exist in one surface/force/category bucket. This pass keeps the approved authority graph intact while making the existing work queue cheaper to query.

Next review target:

Watch the new `spatial_hit`, `spatial_miss`, `spatial_examined`, and `full_fallback` counters. If full fallbacks dominate, the next cleanup should tune cell size/search radius or add category-specific claim radii inside `work_queue_authority.lua`, not create a second work queue.


## 0.1.615 — Work Queue No-Work Claim Churn Reduction

Standards checkpoint followed before packaging: reviewed `docs/STANDARDS_AND_PRACTICES.md` and `docs/AUTHORITY_REFACTOR_CONTINUITY.md`, preserved the runtime authority boundary, and did not add a new scheduler, queue, reservation, cache, sleep, or execution authority.

Efficiency authority inventory answers:

1. Existing owner: repeated shared backlog claim pressure is owned by `work_queue_authority.lua`.
2. Existing governors already apply: broker cadence, pair buckets, shared work queues, reservations, scan routing, indexed dirty cache, event-fed work, directed wakeups, movement active requests, spatial-interest presentation gates, and internal work-queue spatial claims.
3. This pass refines the existing work queue authority internally. It does not create a second negative cache or another sleep state.
4. Reduced path: when a pair/category claim finds no valid order, that pair/category now receives a short no-work cooldown. New submissions or duplicate event refreshes bump the category generation, invalidating stale no-work cooldowns immediately. This prevents repeated empty claim scans while still letting fresh work wake the system.
5. Diagnostic counters: `/tp-runtime-report` now exposes work-queue `no_work_set`, `no_work_skip`, and `no_work_gen_clear` counters alongside spatial claim telemetry.

Rationale:

After 0.1.614, claim attempts became spatial, but empty categories could still be re-queried repeatedly by the same pair. This is not a new cache authority; it is local claim-churn suppression inside the existing work queue owner. A healthy result is rising `no_work_skip` during quiet periods and immediate `no_work_gen_clear` when event-fed or discovered work arrives.

Biggest clawbacks already achieved in this batch: cache-first scan routing, duplicate work-order folding, movement active-request servicing, event-fed repair jobs, directed repair wakeups, spatial-interest theater suppression, and spatial work-queue claims.

Largest remaining candidates: movement command funnel adoption for remaining direct `set_command` callers, dynamic broker budget weighting based on live crisis queues, and event-fed discovery for construction/pickup/sanctification where events can safely produce existing work-queue orders.


## 0.1.616 - Movement Funnel Adoption and Event-Fed Work Expansion

Efficiency authority inventory answers for this pass:

1. Existing owner: movement commands are owned by `movement_controller.lua`; event-fed discovery is owned by `event_driven_work_feeder_0608.lua`; shared backlog remains owned by `work_queue_authority.lua`.
2. Existing gates already apply: runtime broker timing, pair buckets, work queues, reservations, indexed scan routing, adaptive sleep, and spatial-interest presentation gating.
3. This pass feeds existing authorities and demotes direct movement fallbacks; it does not add a new scheduler, cache, sleep layer, reservation layer, or queue authority.
4. Removed/demoted paths: selected executor fallback `set_command` calls now try `tech_priests_route_ground_command_0429` before raw engine command fallbacks; build/drop events now feed existing queues rather than waiting for repeated broad polling scans.
5. Diagnostic proof: `/tp-runtime-report` now surfaces movement route attempts/ground/direct fallback counts and event-fed construction/sanctify/pickup submissions plus directed wake counters.

Implemented:

- Added movement-route telemetry to `movement_controller.lua` so remaining direct command fallbacks are visible.
- Routed construction, repair, consecration, and crafting fallback movement through the movement command funnel when the primary request helper is unavailable.
- Expanded `event_driven_work_feeder_0608.lua` to feed construction ghosts, newly built sanctification candidates, and dropped item pickup candidates into the existing shared work queue.
- Added directed wake hooks for construction, sanctify, and pickup queue events using existing pair bucket/adaptive sleep authorities.
- Kept event-fed work as a fast path beneath the existing queue/reservation/order architecture; no new task authority was created.

## 0.1.617 - Distributed Subordinate Assignment Doctrine

Standards checkpoint followed before packaging: reviewed `docs/STANDARDS_AND_PRACTICES.md`, preserved the efficiency authority inventory rule, and treated command hierarchy as the canonical owner of subordinate-chain assignment. This pass does not add a new scheduler, queue, reservation, cache, sleep layer, or task authority.

User rule implemented:

- When multiple eligible same-rank superiors are in command range, lower-rank subordinates are distributed across those superior chains before one superior fills all available subordinate sockets.
- Proximity still matters, but it is now a tie-breaker after command-chain load/fill ratio.
- Example: if two Senior priests and two Intermediate priests are all within valid range, the first Senior should not automatically take both Intermediates merely because it is marginally closer or earlier in iteration order. The hierarchy should prefer one Intermediate per Senior where both Seniors are eligible.

Authority inventory answers:

1. Existing owner: `command_hierarchy_0480.lua` owns direct superior/subordinate slates.
2. Existing consumers: `subordinate_scheduler.lua`, emergency cascade, Magos movement authority, diagnostics, and Work State displays should consume the hierarchy rather than rediscovering subordinate ownership independently.
3. This change refines the existing hierarchy authority. It does not add a second delegation system.
4. Demoted path: `emergency_cascade.lua` now prefers the hierarchy's direct subordinate list before falling back to broad nearby lower-rank discovery, so cascade behavior does not compete with distributed command ownership.
5. Diagnostic proof: `/tp-command-hierarchy-0480 status` now prints distributed assignment and multi-candidate counts; `/tp-command-hierarchy-0480 all` remains the detailed slate inspection path.

Implemented:

- Added distributed-subordinate fairness to `assign_direct_subordinates()` in `command_hierarchy_0480.lua`. Candidate superiors are sorted by fill ratio, then raw load, then proximity, then station unit for deterministic tie-breaking.
- Added command-hierarchy stats for distributed assignment situations.
- Updated emergency cascade subordinate discovery to prefer the canonical direct-subordinate slate.
- Added the distributed subordinate assignment rule to `docs/STANDARDS_AND_PRACTICES.md` because the user explicitly requested it as a rule for future delegation work.

Next efficiency target after this rule: resume the previously identified runtime-efficiency candidates, with dynamic broker budget weighting or event-fed construction/pickup/sanctification tuning as the next likely safe targets.


## 0.1.618 — Adaptive broker budget weighting efficiency pass

Standards checkpoint: this pass reviewed `STANDARDS_AND_PRACTICES.md` and preserved the current authority boundaries. It does not add a new scheduler, cache, queue, reservation, sleep, movement, or task authority. The existing owner is `runtime_tick_broker.lua`; the change feeds that authority with rolling telemetry so it can vary the soft budget passed to already-registered services.

Implemented a bounded adaptive runtime budget pass inside `runtime_tick_broker.lua`. The broker now computes category pressure from existing rolling counters such as event-fed repair submissions, directed wakeups, construction/sanctify/pickup event submissions, and movement/path request pressure. When a category is hot, the broker temporarily passes a larger soft budget to that service. It does not alter service intervals, priorities, target selection, queue ownership, reservations, movement ownership, or execution behavior.

Expected efficiency benefit: high-pressure categories clear backlog faster during bursts, reducing repeated wake/claim/queue churn across many ticks. Calm categories continue receiving their base budget. This is a runtime clawback from existing telemetry rather than a new control system.

Telemetry added to `/tp-runtime-report`:

- `adaptive-budget-0618 boosts`
- `rolling_boosts`
- category pressure for repair, movement, construction, sanctify, and pickup
- per-service `offered` budget total
- per-service `adaptive_boosts`

Future caution: if adaptive budgets produce visible starvation, add category caps or decay thresholds inside the broker only. Do not create a second budget manager.


## 0.1.619 — Budgeted full-fallback work-queue claim scans

Standards checkpoint: reviewed `STANDARDS_AND_PRACTICES.md` before packaging. Existing owner: `work_queue_authority.lua` owns shared world-work backlog and claim search. Existing systems already applying: spatial work-queue claim index, no-work cooldowns, reservations, broker service budgets, and scan-routing helpers. This pass does not add a new scheduler, queue, cache, reservation, sleep, movement, or task authority. It refines the existing work queue authority so its safety fallback cannot become an unbounded scan spike.

Implemented a bounded full-fallback claim scan beneath `work_queue_authority.lua`. If nearby spatial claim cells do not yield work, the authority still preserves the older full-bucket safety fallback, but now limits how many queued orders may be examined in one claim attempt. When the fallback budget is exhausted without finding work, the pair receives a deferred result instead of setting a no-work cooldown, because unexamined orders may still exist. This prevents large queue backlogs from creating a single-tick claim spike while preserving correctness through later attempts.

Telemetry added to `/tp-runtime-report`: `fallback_examined` and `fallback_budget_exhausted` for work-queue claims. These counters show whether the spatial index is carrying the common path or whether the fallback is still under pressure.


## 0.1.620 — Rotated cleanup budget pass

Standards checkpoint: reviewed `STANDARDS_AND_PRACTICES.md` before packaging. Existing owners: `work_queue_authority.lua` owns shared work backlog cleanup and `work_reservations.lua` owns reservation expiry cleanup. Existing systems already applying: runtime broker maintenance cadence/budget, queue spatial claims, queue no-work cooldowns, and reservation TTLs. This pass does not add a new scheduler, queue, cache, reservation, sleep, movement, or task authority. It refines maintenance traversal inside the two existing authorities.

Implemented rotated cleanup for shared work queues and reservations. Previously, cleanup services could start by considering all categories each maintenance pulse, which is safe but can become wasteful with large backlogs or many stale reservations. The cleanup pass now rotates by category when called without an explicit category, spreading maintenance work across pulses while preserving broker budgets and direct category cleanup for targeted calls.

Expected efficiency benefit: reduces periodic maintenance spikes and avoids repeatedly sweeping calm categories while one category is under pressure. Telemetry added to `/tp-runtime-report`: cleanup rotations and cleanup budget exhaustion for both work queues and reservations.


## 0.1.621 — Movement command funnel adoption pass

Standards checkpoint: reviewed `STANDARDS_AND_PRACTICES.md` before packaging. Existing owner: `movement_controller.lua` owns ground Tech-Priest movement and route-command fallback handling. Existing systems already applying: movement active-request service, movement retarget collapse, broker timing, pair buckets, action claims, and path/movement telemetry. This pass does not add a new movement authority, scheduler, queue, reservation, cache, or sleep layer. It demotes more raw `set_command` fallbacks into leaf fallbacks beneath the existing movement controller.

Efficiency authority inventory answers:

1. Existing owner: `movement_controller.lua` owns ground movement requests and direct command routing.
2. Existing gates already apply: active request ids, command refresh throttling, retarget holds, broker budget service, and `/tp-runtime-report` movement counters.
3. This pass feeds the existing movement authority; it does not duplicate it.
4. Demoted paths: selected direct-acquisition, emergency-production, overleash-return, mobility-recovery, and behavior-stack fallback `go_to_location` commands now attempt `tech_priests_route_ground_command_0429` before raw `LuaEntity.set_command`.
5. Diagnostic proof: existing movement report counters `route_attempts`, `route_ground`, `route_direct_fallback`, `requests`, `collapsed`, and `retargets_held` show how much fallback movement is entering the funnel rather than creating ungoverned engine path commands.

Expected efficiency benefit: fewer independent pathing owners, fewer duplicate raw go-to commands, better retarget collapse, and clearer telemetry for remaining direct movement fallbacks. The raw engine command path remains as a final compatibility fallback only.


## 0.1.622 — Conclave Task Auspex debug readout tab

Standards checkpoint: reviewed `STANDARDS_AND_PRACTICES.md` before packaging. Existing GUI owner: `scripts/gui/gui_router.lua` is the GUI event routing authority, with the legacy command overview builder remaining the existing Conclave/Command Overview frame. Existing telemetry owners remain unchanged: `runtime_tick_broker.lua` owns broker metrics, `pair_bucket_registry.lua` owns pair bucket reports, `work_queue_authority.lua` owns shared work-queue reports, `work_reservations.lua` owns reservation reports, `efficiency_economy_0579`/`scan_routing_0610` own scan/cache reporting, `efficiency_economy_0595/0599/0582` own sleep/dormant reporting, `movement_controller.lua` owns movement pressure reporting, and `order_queue_0469.lua` owns per-pair execution stacks.

Implemented `scripts/core/task_auspex_0622.lua`, a diegetic in-game debug readout tab attached to the existing Tech-Priest Command Overview / Conclave menu. The new "Task Auspex / Debug Readout" tab contains small submenus for General Auspex, Task Economy, Sleep/Wake, Scan/Path, and Selected Pair. It reads existing counters and report lines only; it does not schedule, claim, queue, reserve, move, scan, sleep, wake, or execute any work.

Added `/tp-task-auspex` as a convenience command to open the command overview directly to the new readout tab. The tab is also attached whenever the normal command overview is rebuilt. GUI button events route through the existing GUI router where available.

Expected benefit: live in-game visibility of task churn, queue pressure, reservation pressure, sleep/wake calls, movement/pathing pressure, cache hit/miss behavior, and selected-pair order stacks. This should make future efficiency work easier to validate without relying only on chat-spam commands or external logs.

## 0.1.623 — Task Auspex lazy rendering and refresh throttling

Reviewed the 0.1.622 Task Auspex and found the next efficiency risk: the debug UI itself could become a performance tax if the overview rendered every telemetry ledger every time the Conclave opened or every time a button was clicked. This pass keeps the Auspex UI-only and changes its default overview into a compact summary plus runtime broker block. Heavy task-economy, sleep/wake, scan/path, and selected-pair ledgers now render only when their submenu is selected.

Added a short per-player refresh throttle for Task Auspex button rebuilds so accidental double-clicks or noisy GUI input do not repeatedly rebuild the whole Conclave frame in the same moment. `/tp-runtime-report` now reports Task Auspex render count, section changes, manual refreshes, and throttled refreshes. No new scheduler, queue, reservation, cache, sleep, movement, task, or GUI authority was added.


## 0.1.624 — Command hierarchy topology-skip efficiency clawback

Reviewed the post-0.1.623 efficiency authority map and identified the next safe clawback inside an existing authority: `command_hierarchy_0480.lua`. The distributed subordinate pass made the command slate more useful, but the hierarchy still had a periodic rebuild path that could re-run the same subordinate assignment work even when the station topology had not changed.

This pass does not add a new scheduler, cache, queue, reservation, sleep state, or movement authority. Instead, it makes the existing command hierarchy authority cheaper by adding an O(pairs) topology signature covering station unit, surface, force, rank, and station position. Periodic rebuilds now skip the heavier slate reconstruction when that signature is unchanged. Forced command/install rebuilds still run normally.

Runtime reporting now exposes command hierarchy rebuilds, topology skips, not-due skips, last pairs seen, distributed assignments, multi-candidate cases, and load-balanced assignments. This gives the Task Auspex and `/tp-runtime-report` a way to show whether the distributed-subordinate system is saving work rather than performing ceremonial reclassification every interval.

## 0.1.625 — Profiler-backed runtime cost auspex

Authority review: this pass does not add a new scheduler, cache, queue, reservation, sleep layer, movement authority, or task selector. The existing `runtime_tick_broker.lua` remains the broker authority, and `runtime_event_registry.lua` remains the Factorio event/nth-tick registration authority. The change adds observation-only cost sampling beneath those existing authorities so future efficiency work can be driven by measured slow services instead of inferred churn.

Implemented:

- Added optional profiler timing around runtime broker service execution.
- Added optional profiler timing around runtime event registry callbacks and nth-tick routes.
- Expanded `/tp-runtime-report` with profiler summaries, top slow broker services, top slow registry routes, and debug-output audit counters.
- Added a Profiler submenu to the Conclave Task Auspex, reusing existing telemetry and preserving the debug UI austerity rule.
- Added debug-output counting hooks for the runtime report and central debug command surfaces.

No behavior was changed in this pass. The purpose is to observe first, identify the actual slow callbacks, and only then decide the next efficiency target.


## 0.1.626 - Runtime config/debug consolidation and compatibility-scan audit

Implemented a canonical runtime configuration snapshot rather than adding another runtime authority. The new `runtime_config_0626` module owns cached debug/profiler/log-spam setting interpretation and exposes the master `tech-priests-debug-mode` setting. Existing specific debug settings remain present as compatibility aliases, but high-frequency debug/profiler/Task Auspex and common debug-chat paths now consult the canonical debug mode before doing visible or expensive debug work.

Added compatibility-scan audit telemetry so broad migration-style scans are identified as one-time init scans, configuration-change scans, manual debug-command scans, or unexpected runtime watchdog scans. This makes it possible to verify that compatibility scans are not silently becoming periodic runtime costs. Also added the missing locale description for the lean GUI sprite startup setting.

## 0.1.627 - Reserved global log firewall repair

Load-failure repair pass. Factorio rejects mods that modify the engine-provided global `log` function. The earlier 0.1.593 performance firewall attempted to wrap `_G.log` to suppress high-frequency runtime log spam; that violates Factorio's protected global rules and caused the 0.1.626 control-stage load error: "Detected modification of the global 'log' function."

This pass removes the `_G.log` wrapper entirely. Debug/log-spam accounting remains on Tech-Priests-owned logger wrappers such as `tech_priests_0264_log` and `tech_priests_0264_try_write_file`, while the engine `log` function is left untouched. This preserves the 0.1.626 runtime config/debug consolidation intent without replacing a reserved Factorio global.

Added a standards note forbidding direct assignment/wrapping of engine-provided globals such as `log`; use project-owned wrapper functions and counters instead.

## 0.1.628 - Live smoke-test logistics/action priority repair

Live freeplay smoke testing on 0.1.627 exposed functional regressions hidden by earlier efficiency passes: priests asked for survival ammunition but did not physically fetch nearby starting-wreck/crash-site inventory, a direct stone/rock acquisition state could fail to show the mining beam, and newly placed Martian/emergency machines or basic furnaces were not reliably receiving fuel/ingredients.

Authority review: this pass does not add a new scheduler, cache, reservation, task queue, sleep layer, or movement authority. It repairs leaf behavior under the existing dispatcher/executor path:

- `logistics_fetch_executor_0527.lua` remains the physical known-source fetch executor. It now includes `defines.inventory.character_corpse` when withdrawing from cataloged/nearby storage and adds a bounded nearby-storage fallback scan for containers/vehicles/corpse-style inventories when the station catalog has not learned the source yet. This is intended specifically for early freeplay crash-site/starter inventory and other local cached stock.
- `action_state_arbiter_0488.lua` now gives active acquisition/logistics intent priority over stale `consecration-writ-active`/sanctification mode strings. Consecration may still run from an explicit order or active `consecration_0515` state, but an old mode label alone must not suppress mining beams, storage fetches, or machine logistics.
- `logistics_machine_fulfillment_0528.lua` now expresses missing fuel as a fetchable supply request, not merely a no-task condition. Once the requested fuel arrives in station stock, the machine task resumes as `supply-fuel`; ingredient requests still resume as `supply-ingredient`.
- Fixed the `tech-priests-category.png` technology icon size from 256 to 64 for the 64x64 icon, removing the sprite rectangle warning/fallback seen in the live log.

Primary expected behavior repair: if a station needs firearm magazines and a nearby crash-site/container/corpse inventory contains them, logistics fetch should move the priest to the source, withdraw the item physically, deposit it to the station, and then reserve balancing may share surplus with nearby station chains. If a priest is mining a rock/stone target, acquisition should be classified as acquisition rather than stale consecration, allowing the mining/scan beam. If a local furnace/emergency machine lacks fuel or ingredient and the station does not have it, machine logistics now hands off the exact item need to the existing fetch/acquisition path.
## 0.1.646 - Shared construction and defense planning constraints

Added `planning_constraints_0646.lua` as a policy-only authority beneath the existing planners. It determines whether a placeable entity has an enabled force recipe, whether an interior site preserves the outer defense band, and whether a defense position avoids every other friendly station's control radius.

Construction and bootstrap ghost planning now reject locked entities and stay inside the station yard. The infrastructure survey chooses unlocked placeable items and reports technology blockers. The existing defense perimeter planner consumes the same policy, omits shared-control arcs, adds cardinal gates after unlock, and creates weapon-range-based perimeter fire slots. `/tp-defense-debug` reports walls, gates, and fire slots.

Authority note: this pass feeds existing planners and adds no scheduler, work queue, reservation authority, movement owner, or executor. Physical defense construction remains legacy-controlled pending construction-executor migration.

Documentation audit: cross-referenced `BEHAVIOR_TREE_FOUNDATION_0642.md` and the historical `BEHAVIOR_ORDER_OF_OPERATIONS.md` against the active scheduler map, behavior monitor, dispatcher, construction planners, machine logistics, and defense perimeter code. Replaced them with one current behavior and construction contract that distinguishes executable authority from observational `BT-*` labels and desired behavior. Compacted the authority-continuity document, refreshed the mod and scripts READMEs, and removed 65 superseded audit, recovery, and efficiency snapshot files totaling about 18.4 MB. Stable standards, current testing goals, development history, and audio asset references remain.
