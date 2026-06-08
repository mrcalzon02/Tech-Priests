# Tech Priests Authority Refactor Continuity Plan

This document defines what it means to bring the current modules into one operating scheme while retiring the generated legacy control fragments safely. It is a stable project document, not a per-build audit note.

## Operating scheme

The runtime must eventually follow one per-pair path:

```text
pair lifecycle validation
→ scheduler/order queue selects or preserves intent
→ single dispatcher requests one action classification
→ action arbiter confirms the one visible action family
→ one executor performs the action over time
→ visuals/audio/GUI read state only
→ completion reports back to the order queue
```

The core doctrine remains:

```text
Cogitator Station owns intent and inventory.
Tech-Priest owns physical action.
Emergency machines own machine production.
Visual/audio/GUI systems report state; they do not create work.
Recovery protects identity; it does not direct travel.
```

## Authority definitions

### Lifecycle authority

Owns whether the station/priest pair exists and whether reverse maps are correct. It may rebind or respawn a missing priest when the station is valid. It may permit priest cleanup only when the station itself is removed or killed. It must not choose work, move priests, mine, craft, consecrate, repair, or refresh orders.

### Scheduler / order queue

Owns intent. It decides which job exists, which job is current, which jobs are pending, and whether an order is complete, failed, expired, or preempted. It must not directly perform visible world work.

### Dispatcher

Owns the per-pair runtime pass. It calls the scheduler, requests action classification, and calls the single executor permitted to act this pulse. It is the replacement for the generated `tick_pair` stack as a controller.

### Action arbiter

Owns visible exclusivity. It decides which one action family is allowed to claim the priest right now: combat, repair, acquisition, crafting, construction, consecration, logistics, or idle. It must not invent orders or complete recipes.

### Executors

Own physical completion over time. Direct acquisition walks to a target, waits until adjacent, mines/scavenges, and deposits. Station craft returns to the Cogitator, waits through a visible timed craft, and produces the result. Construction builds from available inventory. Combat, repair, and consecration will be migrated to executor ownership in later passes.

### Visual/audio/GUI reporters

Read state only. They may show BIOS text, overhead status, beams, radius links, audio cues, and diagnostics. They must not create work, complete work, teleport priests, or pulse acquisition.

## Legacy retirement method

Do not delete all generated fragments at once. The safe method is:

1. Identify one behavior family.
2. Define its scheduler input, action-family classification, movement contract, executor, completion signal, and diagnostics.
3. Wrap or disable the matching legacy control route only for that behavior family.
4. Validate in live testing.
5. Only then remove or quarantine the old generated fragment logic.

Legacy code may temporarily remain as leaf helpers, but it may not remain a controller once the dispatcher owns that behavior family.

## Current migration state after 0.1.517

The dispatcher owns direct acquisition, station-craft/emergency-production, and consecration pulses. Direct acquisition now has the 0.1.513 phase executor. Emergency production now has the 0.1.514 phase executor, which checks station inventory, prefers Martian emergency facilities, collects facility output, and only then uses timed station fallback crafting. The old acquisition/crafting/facility pulses are suppressed unless called by the dispatcher or manually. Legacy `tick_pair` is gated only while the dispatcher is actively owning direct acquisition or station-craft behavior for a pair. The 0.1.512 scheduler contract continues to stabilize active order-queue intent with short current-order leases, passive refresh blocking, same-family duplicate folding, and Planetary Magos cascade cooldowns.

Combat, construction placement, scavenge, and idle/chatter are not fully migrated yet. Consecration, repair, and combat-repair have entered dispatcher/executor ownership but may still rely on legacy wrappers as adoption points until generated fragments are retired. Combat repair is a tactical combat sub-family that selects defended damaged wall/gate clusters and routes physical repair through the 0.1.516 repair executor.

## Next refactor passes

### Pass A: Lifecycle cleanup

Remove recovery modules from movement authority. Confirm that valid same-surface priests are never teleported or destroyed by recovery. Keep recovery limited to rebind/respawn and station-removal cleanup.

### Pass B: Direct acquisition finalization

Make `acquisition_executor.lua` the only code that mines trees, rocks, dirt, or ore by hand. Remove or permanently quarantine 0273/0312/0315 direct-mining legacy execution bodies once their helper functions are safely copied into the executor.

### Pass C: Station craft finalization

Move emergency station craft completion fully into `crafting_executor.lua`. Legacy desperation craft routines should become data helpers or be removed.

### Pass D: Emergency machine doctrine

Partially migrated in 0.1.514. Martian emergency facilities are now preferred by a dispatcher-owned emergency production executor before timed station fallback crafting. Remaining work: migrate construction/placement of missing emergency facilities and richer machine recipe/output monitoring.

### Pass E: Construction executor

Move placement/building decisions behind construction executor ownership. Construction should not simultaneously be run by Magos planning, legacy emergency code, and direct acquisition fallback.

### Pass F: Repair/consecration/combat executors

Move each into leaf executor ownership with action-family claims. Combat may interrupt; repair beats consecration; consecration is routine work only.

### Pass G: Legacy fragment removal

After all action families have dispatcher-owned executors, remove generated `tick_pair` controller fragments or leave them disabled behind explicit compatibility flags.

## Required continuity checks for each pass

Before packaging each refactor build:

```text
read docs/STANDARDS_AND_PRACTICES.md
read docs/AUTHORITY_REFACTOR_CONTINUITY.md
update docs/CURRENT_TESTING_GOALS.md
append notes to docs/DEVELOPMENT_HISTORY.md
validate info.json version
validate zip root
validate zip integrity
validate locale uniqueness
```

## Diagnostic commands to preserve

```text
/tp-dispatcher-0510
/tp-behavior-cleanup-0509
/tp-movement-recovery-0508
/tp-action-stack-0507
/tp-order-queue-0469 all
/tp-emergency-diagnostics once
```


After 0.1.511, direct acquisition also has a movement bounds contract. The 0.1.273 generated one-second direct-gather hard-kick route is decommissioned through the runtime event registry. Future direct acquisition work must not re-enable that hard-kick controller. If a target is too far from the station for the pair's role, the correct response is to reject/replan/delegate/build machinery, not to issue a long uncontrolled travel command.

## 0.1.512 scheduler-stability pass

The next scheduler migration step is `scripts/core/scheduler_contract_0512.lua`. This module does not replace `order_queue_0469`; it wraps it so current orders receive an active lease, duplicate same-family submissions fold into the current order, passive GUI/mouse-over/radar refreshes are blocked while work is active, and Planetary Magos emergency cascade/planning pulses cool down while the leader is already working.

Future scheduler changes should preserve this distinction:

```text
Planner modules may submit intent.
Order queue stores and promotes intent.
Scheduler contract stabilizes active intent.
Dispatcher consumes the active intent and calls one executor.
Executors perform physical work.
```

Do not repair order spam by adding another direct planner pulse. If a behavior family needs new work, submit it to the queue and let the dispatcher/executor path consume it.


## 0.1.513 direct acquisition executor migration

Direct acquisition is the first behavior family to receive a real dispatcher-owned phase executor. Future changes to direct acquisition must preserve this route:

```text
scheduler/order queue supplies intent
→ dispatcher owns the per-pair pulse
→ direct_acquisition_executor_0513 owns target adoption, movement wait, timed extraction, deposit, return/yield
→ legacy direct functions are blocked while dispatcher-owned direct work is active
```

Do not repair direct acquisition by re-enabling independent 0273/0312/0315 service pulses, direct-gather hard-kicks, station-side remote deposits, or GUI/radar/mouse-over acquisition pulses. If acquisition needs a new target, submit or preserve intent through the order queue and let the dispatcher/executor path consume it.

The 0.1.513 pass deliberately does not migrate scavenge, construction, repair, combat, consecration, or emergency-machine production. Those families may still use legacy helpers until they receive equivalent executor ownership.

## 0.1.514 emergency production executor migration

Emergency production now has a dispatcher-owned phase executor in `scripts/core/emergency_production_executor_0514.lua`. Future emergency-production fixes must preserve this route:

```text
scheduler/order queue supplies item intent
→ dispatcher owns station-craft/emergency-production pulse
→ emergency_production_executor_0514 checks station inventory
→ collect existing Martian emergency facility output if present
→ call emergency_facility_doctrine only as a leaf helper to feed/request machines
→ wait for machine output
→ use timed station fallback craft only when machine production cannot proceed and materials are ready
→ deposit output and complete the order/task
```

Do not restore independent periodic emergency facility production pulses or legacy desperation-craft completion as controllers. Emergency facilities may remain helper modules until the construction/emergency-machine placement pass migrates them fully, but they must be called through dispatcher-owned production work.

The 0.1.514 pass deliberately does not migrate construction placement itself. The next cleanup layer should migrate construction/emergency-machine building so missing facilities are planned, built, and reported by a construction executor rather than by multiple planning fragments.



## 0.1.515 consecration executor migration

Consecration now has a dispatcher-owned phase executor in `scripts/core/consecration_executor_0515.lua`. Future consecration fixes must preserve this route:

```text
scheduler/order queue or legacy helper supplies consecration intent
→ dispatcher owns the consecration pulse
→ consecration_executor_0515 selects a useful machine target
→ priest walks to rite/capsule range
→ executor waits through visible ritual time
→ station-supplied capsule item is consumed
→ tech_priests_0515_apply_consecration_from_source records priest/station/item/method/order context
→ target cooldown prevents endless top-off loops
```

Do not restore direct station-inventory sanctification as a controller. The old `sanctify_target_with_priest` function may only remain as a wrapper/adoption point into the 0.1.515 executor until legacy generated fragments are fully retired.


## 0.1.516 repair executor migration

Repair now has a dispatcher-owned phase executor in `scripts/core/repair_executor_0516.lua`. Future repair fixes must preserve this route:

```text
scheduler/order queue or legacy helper supplies repair intent
→ dispatcher owns the repair pulse
→ repair_executor_0516 selects a damaged target by severity, role priority, and proximity
→ target reservation prevents multiple priests dogpiling the same entity when alternatives exist
→ priest walks to repair range
→ executor consumes repair packs over visible timed repair ticks
→ entity is repaired to full health rather than waiting for maximum repair-pack efficiency
→ repair order completes and the target enters a short cooldown
```

Do not restore direct `repair_target` controller behavior as an independent path. The old `repair_target` function may remain only as a wrapper/adoption point into the 0.1.516 executor until legacy generated fragments are fully retired.

## 0.1.517 combat repair doctrine

Combat repair now has a dispatcher-recognized action family in `scripts/core/combat_repair_doctrine_0517.lua`. Future combat-repair fixes must preserve this route:

```text
combat threat exists
→ dispatcher checks combat_repair_doctrine_0517 before ordinary combat classification
→ doctrine selects only damaged wall/gate clusters under enemy pressure with loaded/active turret or priest cover
→ dispatcher claims `combat-repair`
→ combat repair routes physical work through repair_executor_0516
→ cover loss aborts the repair state so exposed priests can return to combat/retreat behavior
```

Do not solve defended-wall repair by adding a second independent repair loop inside combat code. The combat doctrine may decide that a wall must be held, but `repair_executor_0516` remains the physical repair leaf executor.



## 0.1.518 movement cadence / task-churn contract

Movement remains owned by `scripts/core/movement_controller.lua`; 0.1.518 does not create a second movement authority. `scripts/core/movement_cadence_contract_0518.lua` wraps movement requests so long dispatcher-owned actions can keep a movement lease while the priest is walking. Lower-priority retarget attempts are held; combat, retreat, and real recovery may interrupt.

Future fixes for slow or stuttering priests must not reintroduce direct movement commands from scheduler, GUI, legacy generated code, or executor helpers. Submit movement through `_G.tech_priests_request_movement_0418` and let the movement cadence contract preserve or reject retargets.

Consecration target selection is now bounded as local machine maintenance. If a Cogitator Station lacks consecration items, the executor should cool down and request/allow production/acquisition of supplies rather than repeatedly failing the same consecration order every few ticks.


## 0.1.519 logistics / construction physical-access contract

Logistics pickup and construction placement now have a late authority contract in `scripts/core/logistics_construction_contract_0519.lua`. Future logistics/construction fixes must preserve this route:

```text
scheduler/order queue or legacy helper supplies item/construction intent
→ dispatcher gives construction high priority when an owned placeable item exists
→ logistics_construction_contract_0519 requires priests to walk to loose items or source inventories before withdrawal
→ construction planner may remain a leaf helper but cannot be an unrestricted independent controller
→ construction tasks create/maintain a ghost marker before physical placement
→ item is removed only from available station-known/source inventory after the priest has reached the relevant source/site
```

Do not restore silent item teleportation from ground stacks, remote machine inventories, or source containers into Cogitator Station inventory. Do not restore range-expansion ghost spam for station items that do not exist and cannot be produced by the currently unlocked/station-known production chain. Resource expansion should reject, defer, delegate, or first build the missing production chain rather than placing fantasy ghosts.


## 0.1.520 portrait assignment

Portrait assignment is a UI identity layer. `scripts/core/portrait_assignment_0520.lua` may assign and report stable portrait IDs and sprites, but it must not become a behavior source. Future GUI portrait work should keep this layer read-only with respect to scheduler, dispatcher, movement, construction, repair, consecration, combat, and logistics state. The next UI stages are deep tab cleanup and diegetic phrasing polish.


## 0.1.521 Work State deep tab cleanup

This pass is UI/data organization only. Writ Queue, Forge Plan, and Command Tree may render structured tables and expose diagnostic commands, but they must remain read-only display surfaces. Do not let these Work State panes create orders, complete work, mutate movement, or pulse legacy executors. Future UI polish should preserve the rule that GUI panes report dispatcher/scheduler/executor state; they do not own behavior.


## 0.1.522 Work-State diegetic polish

The fifth UI pass is wording-only: it renames Work-State panel captions, tabs, buttons, and slate headings into consistent in-universe language after the 0.1.521 structured tab cleanup. It must remain behavior-neutral. Do not use UI polish as a reason to create new scheduler, dispatcher, movement, repair, consecration, construction, logistics, or visual ownership paths.


## 0.1.523 Machine-Spirit State Ledger / trait scaffold

Machine traits, quirks, flaws, positive/negative crafting history, and placeholder naming are ledger annotations on the existing consecration machine record. `scripts/core/consecration/machine_traits_0523.lua` may observe completed operation history and add persistent machine-spirit marks at powers of ten, but it must not become a scheduler, dispatcher, movement, repair, construction, consecration, combat, logistics, or emergency-production authority.

Future machine-personality work should preserve this route:

```text
consecration decay/history observes a completed operation
→ machine_traits_0523 checks whether the operation count reached a powers-of-ten milestone
→ the existing machine record receives a quirk/trait/flaw/history mark
→ the Machine-Spirit State Ledger displays those marks
→ future gameplay effects may read the marks, but must be added deliberately through the relevant behavior authority
```

Do not add hidden production bonuses, penalties, crafting rewrites, or priest orders directly from the trait ledger. Names remain the placeholder `Machine` until a future name-table pass implements proper machine naming.


## 0.1.524 Machine-Spirit Trait Taxonomy

Machine-spirit trait taxonomy is a ledger/data layer in `scripts/core/consecration/machine_trait_taxonomy_0524.lua`. It derives eligibility from the existing consecration target registry: if `is_consecration_target(entity)` rejects an entity, the trait system must also reject it. Belts, inserters, pipes, walls, containers, and other non-sanctifiable entities must not roll traits, quirks, flaws, or names through this system.

Future trait/name work should preserve this route:

```text
consecration decay/history observes completed operation
→ machine_traits_0523 checks powers-of-ten milestone
→ machine_trait_taxonomy_0524 confirms sanctification eligibility and classifies the machine
→ taxonomy returns category-aware lore-only trait/quirk/flaw/name data
→ machine record receives the mark
→ Machine-Spirit State Ledger displays the mark
```

Do not add hidden production bonuses, penalties, recipe changes, priest orders, or scheduler/dispatcher behavior directly from the taxonomy. Gameplay effects may read trait records later, but only through the appropriate behavior or consecration authority and only after an explicit implementation pass.


## 0.1.525 priest identity background pass

`priest_identity_background_0525.lua` is a lore/UI identity module. It enriches persistent Tech-Priest personal dossiers and exposes `/tp-priest-identity-0525`. It is not a behavior authority and must remain read/write-only to profile memory; it must not create work, refresh orders, move priests, repair, consecrate, build, fight, or alter dispatcher/scheduler state.


## 0.1.526 logistics fetch / UI polish

Known-storage logistics is now a physical dispatcher-owned fetch step in `scripts/core/logistics_fetch_executor_0526.lua`. Future supply fixes must preserve this route:

```text
station catalog sees item in nearby container/machine inventory
→ scheduler/order queue expresses the item need
→ dispatcher gives logistics-fetch a chance before raw acquisition
→ priest walks to the source inventory
→ item is removed from the source only when the priest is in range
→ item is deposited into Cogitator Station inventory
→ order queue may complete because the station now truly has the item
```

Do not restore passive reserve balancing that silently moves loose container items into station inventory. Station-owned inventory and priest cargo can still be counted directly, but ordinary nearby containers are fetch sources, not station stock. UI-only Work-State and Machine-Spirit ledger polish may remain in reporter modules as long as it does not create work or complete tasks.


## 0.1.527 universal known-resource fetch

`logistics_fetch_executor_0527.lua` supersedes the 0.1.526 known-storage fetch wrapper. Future logistics fixes must preserve this route:

```text
scheduler/order queue expresses an item need
→ dispatcher checks universal known-resource/source fetch before raw mining or emergency crafting
→ logistics_fetch_executor_0527 finds an exact requested item in station catalog storage, machine/vehicle/corpse inventories, or loose ground stacks
→ priest moves to the source through the movement controller
→ item is withdrawn/picked up only after physical reach
→ item is deposited into Cogitator Station inventory
→ raw acquisition/crafting is only considered when no exact known source is available
```

Do not reintroduce silent remote source transfer, ammo-only fetch special cases, or raw-mining-first behavior when the exact item already exists in cataloged known resources.

## 0.1.528 machine logistics fulfillment

`logistics_machine_fulfillment_0528.lua` is a dispatcher-priority logistics executor for non-automated assemblers and furnaces. Future machine-service work must preserve this route:

```text
station catalog / scheduler expresses local production need
→ dispatcher gives machine logistics a chance before raw acquisition/emergency crafting
→ logistics_machine_fulfillment_0528 selects only local unautomated machines by default
→ priest walks to the machine before output/fuel/input transfer
→ output is physically carried to retention/station storage
→ mechanical detritus/scrap are routed to an internally tagged waste box when available
→ missing item ingredients are expressed as exact needs for logistics_fetch_executor_0527
```

Do not reintroduce silent remote clearing of machine outputs, direct machine-to-station insertion, or independent machine-service pulses. Automated machines adjacent to inserters/loaders/belts/pipes/pumps are intentionally skipped by default so priests do not fight player-built logistics networks. Fluid supply and pipe-aware service remain future work.

## 0.1.529 scan-beam and ground-item logistics pass

Scan/mining/combat beam visuals now route through `scripts/core/scan_beam_controller_0529.lua`. Future visual work should call `tech_priests_0529_scan_beam(pair, target, kind, opts)` or the existing wrapped globals rather than adding new independent `rendering.draw_line` paths for priest work. Mining resources, trees, and boulders should use this controller so smoke/damage visuals remain consistent.

Loose dropped items now route through `scripts/core/ground_item_hoover_0529.lua`. Future logistics fixes should preserve the physical-access rule: a dropped item does not enter station inventory until a priest reaches the item. If storage is full, the system should prefer station/retention storage or build storage from available chest items; it must not restore dump-to-ground overflow as normal behavior.



## 0.1.531 operational sound pass

Operational/mechanical sounds are reporter-only. `scripts/core/operational_sounds_0531.lua` may play custom machine/UI/respirator cues and register machine placement/removal audio, but it must not create work, alter orders, move priests, complete tasks, or become a parallel behavior controller. Future sound additions should route through `sound_manager_0475` or this operational-sounds reporter rather than direct scattered `surface.play_sound` calls.


## 0.1.533 placeholder functional audio doctrine

The placeholder audio manifest is integrated as reporter-only runtime state. `scripts/core/placeholder_audio_0533.lua` may observe pair creation/breakage, machine sanctity/detritus records, GUI open/close context, and existing sound-manager action events, but it must not submit orders, complete orders, move priests, create beams/text, alter inventories, or become another controller. New audio hooks should route through `sound_manager_0475` or the placeholder/operational audio reporters with per-category cooldowns.
