-- Tech Priests - runtime script entry point.
-- 0.1.438: ordered generated-fragment loader for Lua local/register limit relief.
-- Fragments preserve original execution order; no behavior bodies are intentionally deleted.


-- 0.1.596: early passive-service austerity hook. Loaded before legacy
-- fragments so direct script.on_nth_tick handlers are dormant-gated until a
-- Tech-Priest runtime entity actually exists.
pcall(function()
  local Economy0596 = require("scripts.core.efficiency_economy_0596")
  if Economy0596 and Economy0596.install_early_hook then Economy0596.install_early_hook() end
end)

require("scripts.generated.control_legacy_part_001")
require("scripts.generated.control_legacy_part_002")
require("scripts.generated.control_legacy_part_003")
require("scripts.generated.control_legacy_part_004")
require("scripts.generated.control_legacy_part_005")
require("scripts.generated.control_legacy_part_006")
require("scripts.generated.control_legacy_part_007")
require("scripts.generated.control_legacy_part_008")
require("scripts.generated.control_legacy_part_009")
require("scripts.generated.control_legacy_part_010")
require("scripts.generated.control_legacy_part_011")
require("scripts.generated.control_legacy_part_012")
require("scripts.generated.control_legacy_part_013")
require("scripts.generated.control_legacy_part_014")
require("scripts.generated.control_legacy_part_015")
require("scripts.generated.control_legacy_part_016")
require("scripts.generated.control_legacy_part_017")
require("scripts.generated.control_legacy_part_018")
require("scripts.generated.control_legacy_part_019")
require("scripts.generated.control_legacy_part_020")
require("scripts.generated.control_legacy_part_021")
require("scripts.generated.control_legacy_part_022")

-- 0.1.457: pair dump + debug command executive smoke test.  Loaded after the
-- legacy fragments so it can inspect the final pair storage shape without being
-- overwritten by older command blocks.
pcall(function()
  local PairDump0457 = require("scripts.core.debug.pair_dump_0457")
  if PairDump0457 and PairDump0457.install then PairDump0457.install() end
end)

-- 0.1.459: status-display authority must load after all legacy fragments so the
-- final draw_emergency_operation_status symbol follows the Work State panel
-- instead of stale emergency construction fields.
pcall(function()
  local StatusDisplay0459 = require("scripts.core.status_display_authority_0459")
  if StatusDisplay0459 and StatusDisplay0459.install then StatusDisplay0459.install() end
end)
-- 0.1.465: final recovery owner for Work State/BIOS GUI routing and restored radar artwork.
pcall(function()
  local Recovery0465 = require("scripts.core.workstate_gui_radar_recovery_0465")
  if Recovery0465 and Recovery0465.install then Recovery0465.install() end
end)

-- 0.1.466: combat/acquisition behavior mutex loaded last so red combat fallback
-- and amber acquisition/direct-mining visuals cannot fire together.
pcall(function()
  local Mutex0466 = require("scripts.core.behavior_mutex_0466")
  if Mutex0466 and Mutex0466.install then Mutex0466.install() end
end)

-- 0.1.467: disable the legacy Senior-only first-spawn grant and suppress the
-- old standalone Known Resources window while preserving the Work State tab.
pcall(function()
  local Authority0467 = require("scripts.core.startup_catalog_authority_0467")
  if Authority0467 and Authority0467.install then Authority0467.install() end
end)


-- 0.1.468: docked Known Resources refresh tab preservation, periodic pair dump
-- snapshots in emergency diagnostics, and neutral-boulder fallback laser guard.
pcall(function()
  local Authority0468 = require("scripts.core.diagnostics_behavior_authority_0468")
  if Authority0468 and Authority0468.install then Authority0468.install() end
end)

-- 0.1.600: central runtime tick broker and basic pair bucket registry.
-- Loaded before broker-aware services so order/repair can register into the
-- shared runtime spine instead of adding more independent nth-tick handlers.
pcall(function()
  local RuntimeBroker0600 = require("scripts.core.runtime_tick_broker")
  if RuntimeBroker0600 and RuntimeBroker0600.install then RuntimeBroker0600.install() end
end)

pcall(function()
  local PairBuckets0600 = require("scripts.core.pair_bucket_registry")
  if PairBuckets0600 and PairBuckets0600.install then PairBuckets0600.install() end
end)

-- 0.1.609: spatial-interest telemetry/theater gate. This is not a sleep or
-- scheduling authority; it only lets existing visual/audio reporters skip
-- nonessential offscreen presentation work.
pcall(function()
  local SpatialInterest0609 = require("scripts.core.spatial_interest_0609")
  if SpatialInterest0609 and SpatialInterest0609.install then SpatialInterest0609.install() end
end)


-- 0.1.610: cache-first scan routing helper. This is not a cache authority;
-- it routes repeated discovery through existing indexed catalog 0579 and falls
-- back to direct scans when cells are dirty or unknown.
pcall(function()
  local ScanRouting0610 = require("scripts.core.scan_routing_0610")
  if ScanRouting0610 and ScanRouting0610.install then ScanRouting0610.install() end
end)

-- 0.1.601: shared work reservations and surface/force work queues.
-- Loaded before order/repair services so duplicate target claims can be folded
-- before they become pathfinding churn.
pcall(function()
  local WorkReservations0601 = require("scripts.core.work_reservations")
  if WorkReservations0601 and WorkReservations0601.install then WorkReservations0601.install() end
end)

pcall(function()
  local WorkQueues0601 = require("scripts.core.work_queue_authority")
  if WorkQueues0601 and WorkQueues0601.install then WorkQueues0601.install() end
end)

-- 0.1.608: event-driven repair wake feeder. This is a leaf helper only: events
-- submit high-signal candidates to existing work queues and telemetry. It does
-- not own scheduling, reservations, sleep, cache, or execution.
pcall(function()
  local EventFeeder0608 = require("scripts.core.event_driven_work_feeder_0608")
  if EventFeeder0608 and EventFeeder0608.install then EventFeeder0608.install() end
end)

-- 0.1.469: per-priest order queue and resource-writ de-duplication. Loaded last
-- so legacy assignment/resource functions pass through a stable queue before
-- rewriting pair.mode, pair.scavenge, pair.emergency_craft, or active_task.
pcall(function()
  local OrderQueue0469 = require("scripts.core.order_queue_0469")
  if OrderQueue0469 and OrderQueue0469.install then OrderQueue0469.install() end
end)

-- 0.1.471: Planetary Magos strategic planning queue and canonical one-slot
-- overhead status governor. Loaded after the order queue so immediate work can
-- report from the active order while the Magos keeps separate construction
-- intentions.
pcall(function()
  local MagosPlanning0471 = require("scripts.core.magos_planning_queue_0471")
  if MagosPlanning0471 and MagosPlanning0471.install then MagosPlanning0471.install() end
end)

pcall(function()
  local Overhead0471 = require("scripts.core.overhead_status_governor_0471")
  if Overhead0471 and Overhead0471.install then Overhead0471.install() end
end)

-- 0.1.472: Planetary Magos may treat subordinate station operating areas as
-- command territory.  Point-blank combat/proxy-turret service is staged and
-- cooled down so damage/contact pressure cannot create command-loop stalls.
pcall(function()
  local Authority0472 = require("scripts.core.combat_magos_movement_authority_0472")
  if Authority0472 and Authority0472.install then Authority0472.install() end
end)


-- 0.1.473: hard-route remaining legacy priest overhead status emitters into
-- the canonical single-slot display and add configurable Cogitator BIOS speed.
pcall(function()
  local Authority0473 = require("scripts.core.overhead_text_authority_0473")
  if Authority0473 and Authority0473.install then Authority0473.install() end
end)

-- 0.1.474: station-side Alt-mode writ icons plus stable non-strobing
-- Cogitator radius/interstation/pair-link overlays and restored held-station
-- radius preview. Loaded last so older visual refreshers route through it.
pcall(function()
  local Authority0474 = require("scripts.core.alt_writ_visual_stability_0474")
  if Authority0474 and Authority0474.install then Authority0474.install() end
end)


-- 0.1.475: unified audio authority.  Legacy task sounds, order-queue writ
-- emissions, station task-switch cues, and action ambience now route through a
-- single cooldown-governed manager.
pcall(function()
  local Sound0475 = require("scripts.core.sound_manager_0475")
  if Sound0475 and Sound0475.install then Sound0475.install() end
end)

-- 0.1.476: visual overlay leases plus scheduler attention retention.  Radius
-- and link overlays now clear when the station/placement context ends;
-- ordinary writs cadence slowly instead of constantly replacing current tasks.
pcall(function()
  local Authority0476 = require("scripts.core.task_retention_visual_lease_0476")
  if Authority0476 and Authority0476.install then Authority0476.install() end
end)



-- 0.1.477: active order execution watchdog plus stricter task-switch/writ audio
-- gating. Loaded after retention/audio so it can re-arm stuck active writs and
-- suppress mode-churn pings that are not real stable task changes.
pcall(function()
  local Authority0477 = require("scripts.core.task_execution_sound_governor_0477")
  if Authority0477 and Authority0477.install then Authority0477.install() end
end)

-- 0.1.478: Work State gets vox/writ/forge-plan pages; consecration restores
-- record their source; distant mining beams are suppressed until movement is
-- actually issued and stocked writs can complete instead of chanting forever.
pcall(function()
  local Authority0478 = require("scripts.core.task_lifecycle_authority_0478")
  if Authority0478 and Authority0478.install then Authority0478.install() end
end)


-- 0.1.479: movement-before-action behavior contract. Distant non-hostile
-- acquisition/mining visuals are suppressed until a real movement request exists,
-- and diagnostics expose any remaining contract violations.
pcall(function()
  local Authority0479 = require("scripts.core.behavior_contracts_0479")
  if Authority0479 and Authority0479.install then Authority0479.install() end
end)

-- 0.1.480: strict noospheric command hierarchy. Planetary Magos/Senior/
-- Intermediate stations receive 2/4/8 direct subordinate sockets; Juniors
-- carry peer communion only. Loaded last so subordinate scheduling and Magos
-- subordinate-area authority read the same command slate.
pcall(function()
  local Authority0480 = require("scripts.core.command_hierarchy_0480")
  if Authority0480 and Authority0480.install then Authority0480.install() end
end)


-- 0.1.482/0.1.487: retained GUI utility and portrait registry.
pcall(function()
  local Gui0482 = require("scripts.core.gui_asset_framework_0482")
  if Gui0482 and Gui0482.install then Gui0482.install() end
end)

-- 0.1.484: additional portrait sheet registry. Loaded after the GUI asset
-- framework so later Work State portrait assignment can draw from the expanded
-- pool without touching the existing Cogitator screen shell.
pcall(function()
  local Portraits0484 = require("scripts.core.portrait_registry_0484")
  if Portraits0484 and Portraits0484.install then Portraits0484.install() end
end)


-- 0.1.486: dedicated Planetary Magos portrait reference sheet registry.
-- Loaded after the general portrait registry so future explicit portrait
-- assignment can reserve this sheet for highest-rank Magos displays.
pcall(function()
  local Portraits0486 = require("scripts.core.portrait_registry_0486")
  if Portraits0486 and Portraits0486.install then Portraits0486.install() end
end)


-- 0.1.487: reject the experimental ornate Work State frame and enforce
-- final decay cleanup for station radius/link overlays after hover/placement ends.
pcall(function()
  local Visual0487 = require("scripts.core.visual_lease_cleanup_0487")
  if Visual0487 and Visual0487.install then Visual0487.install() end
end)


-- 0.1.488: single-action arbiter. A priest may not visibly craft, scan, mine,
-- and fight at once; overhead text and beams now follow one active action.
pcall(function()
  local Action0488 = require("scripts.core.action_state_arbiter_0488")
  if Action0488 and Action0488.install then Action0488.install() end
end)

-- 0.1.489: own-station scan suppression and visual lease hardening.
-- Priests know their paired Cogitator Station; they must not draw scan/mining
-- beams at it, and station radius/link overlays must decay when no longer selected.
pcall(function()
  local Authority0489 = require("scripts.core.self_station_scan_visual_authority_0489")
  if Authority0489 and Authority0489.install then Authority0489.install() end
end)


-- 0.1.490: direct-mining safety and no-spill stash doctrine. Loaded last so
-- legacy emergency gathering cannot mine priests/stations, transmute rocks into
-- ammo, or dump outputs on the floor when a station-bound stash can be built.
pcall(function()
  local Safety0490 = require("scripts.core.direct_mining_safety_0490")
  if Safety0490 and Safety0490.install then Safety0490.install() end
end)

-- 0.1.495: consecrated mining drills now register mining-output work rites;
-- pair links are hardened so vanished/orphaned priests are rebound before a
-- controlled rescue respawn is attempted.
pcall(function()
  local Mining0495 = require("scripts.core.consecration.mining_sensor_0495")
  if Mining0495 and Mining0495.install then Mining0495.install() end
end)
pcall(function()
  local Pair0495 = require("scripts.core.pair_link_hardening_0495")
  if Pair0495 and Pair0495.install then Pair0495.install() end
end)

-- 0.1.497: emergency survival supplies are one-item writs only. Passive
-- reserve balancing moves ammo/repair/consecration from surplus station/priest
-- cargo to stations with an active need instead of making priests craft stacks.
pcall(function()
  local Reserve0497 = require("scripts.core.emergency_supply_reserve_0497")
  if Reserve0497 and Reserve0497.install then Reserve0497.install() end
end)

-- 0.1.498: task/pair audit and quarantine pass. Loaded last so it can
-- observe/remediate missing-priest events, block valid-priest respawn churn,
-- and force legacy direct gathering to be literal instead of transmuting rocks.
pcall(function()
  local Audit0498 = require("scripts.core.task_pair_audit_0498")
  if Audit0498 and Audit0498.install then Audit0498.install() end
end)

-- 0.1.499: hard priest lifecycle authority. Loaded last so rescue, recall,
-- mobility-replacement, orphan-purge, and stuck-watchdog paths cannot delete or
-- replace visible priests while the vanish failure is being isolated.
pcall(function()
  local Life0499 = require("scripts.core.priest_lifecycle_authority_0499")
  if Life0499 and Life0499.install then Life0499.install() end
end)

-- 0.1.500: direct priest lifecycle seal.  Visible Tech-Priests are preserved
-- unless their paired Cogitator Station is being removed or killed.  Stuck,
-- recall, respawn, mobility-replacement, and orphan-purge paths remain disabled
-- while the vanish source is isolated.
pcall(function()
  local Seal0500 = require("scripts.core.priest_lifecycle_seal_0500")
  if Seal0500 and Seal0500.install then Seal0500.install() end
end)

-- 0.1.501: vanish guard. Loaded after the lifecycle seal because the 0.1.500
-- run proved a priest can become invalid while the station and pair remain alive
-- without a recorded destroy/removal event. This seals late direct-mining services
-- and re-enables only controlled missing-priest recovery for testing.
pcall(function()
  local Guard0501 = require("scripts.core.priest_vanish_guard_0501")
  if Guard0501 and Guard0501.install then Guard0501.install() end
end)

-- 0.1.502/0.1.504: station-side direct acquisition tether. Loaded after
-- 0.1.501 because the visible native unit still vanished during emergency
-- direct-gather movement. 0.1.504 adds an anti-slam throttle so restored
-- watchdog/recovery callers cannot hammer the quarantine path every tick.
pcall(function()
  local Guard0502 = require("scripts.core.priest_vanish_guard_0502")
  if Guard0502 and Guard0502.install then Guard0502.install() end
end)

-- 0.1.503: recovery safety restoration. Loaded after the vanish guards so the
-- 0.1.502 station-side acquisition fix stays active while legitimate recall,
-- missing-priest rescue, watchdog roots, and authorized belt-immunity mobility
-- swaps are restored for behavior verification.
pcall(function()
  local Recovery0503 = require("scripts.core.priest_recovery_safety_0503")
  if Recovery0503 and Recovery0503.install then Recovery0503.install() end
end)

-- 0.1.505: behavior execution doctrine clamp. Loaded last so it can enforce
-- predictable order of operations after the vanish/recovery hotfixes: no
-- far-away world mining damage, facility-first emergency production, timed
-- station crafting, and throttled failed recovery teleports.
pcall(function()
  local Behavior0505 = require("scripts.core.behavior_execution_doctrine_0505")
  if Behavior0505 and Behavior0505.install then Behavior0505.install() end
end)

-- 0.1.506: mobility/recovery contract. Loaded after 0.1.505 so valid
-- priests are allowed to travel to work targets instead of being treated as
-- failed recovery cases and yanked back to their Cogitator Station.
do
  local ok, err = pcall(function()
    local Mobility0506 = require("scripts.core.mobility_recovery_contract_0506")
    if Mobility0506 and Mobility0506.install then Mobility0506.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.506] mobility_recovery_contract_0506 failed to install: " .. tostring(err)) end
end

-- 0.1.507: first legacy cleanup pass for behavior ownership. Loaded after the
-- mobility contract so it can document the canonical stack and report duplicate
-- action claims while moved services remain in their owning modules.
pcall(function()
  local Stack0507 = require("scripts.core.action_stack_contract_0507")
  if Stack0507 and Stack0507.install then Stack0507.install() end
end)

-- 0.1.508: recovery is no longer a movement owner. Loaded after the
-- action-stack contract so valid same-surface priests are passively validated
-- instead of being recalled, while direct acquisition owns a visible movement
-- lease and waits for adjacency before mining.
do
  local ok, err = pcall(function()
    local Move0508 = require("scripts.core.movement_recovery_authority_0508")
    if Move0508 and Move0508.install then Move0508.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.508] movement_recovery_authority_0508 failed to install: " .. tostring(err)) end
end

-- 0.1.509: behavior stack cleanup. Loaded after 0.1.508 so it can
-- decommission the old 0.1.502 station-side executor, keep direct acquisition
-- physical/adjacent-only, debounce UI order refreshes, and rely on explicit
-- prototype AI settings so command failure cannot delete scripted priests.
do
  local ok, err = pcall(function()
    local Cleanup0509 = require("scripts.core.behavior_stack_cleanup_0509")
    if Cleanup0509 and Cleanup0509.install then Cleanup0509.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.509] behavior_stack_cleanup_0509 failed to install: " .. tostring(err)) end
end


-- 0.1.510: first authoritative dispatcher refactor pass. Loaded after the
-- behavior cleanup layer so it can make scheduler -> action -> executor the
-- visible path for direct acquisition and station craft while legacy tick_pair is
-- gated only for dispatcher-owned action families.
do
  local ok, err = pcall(function()
    local Dispatcher0510 = require("scripts.core.single_dispatcher_0510")
    if Dispatcher0510 and Dispatcher0510.install then Dispatcher0510.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.510] single_dispatcher_0510 failed to install: " .. tostring(err)) end
end


-- 0.1.511: movement bounds contract. Loaded after the dispatcher so it can
-- keep direct acquisition movement local, decommission the old 0.1.273 hard
-- direct-gather kick, and walk overleashed priests home instead of letting a
-- Planetary Magos chase fallback targets into the wilderness.
do
  local ok, err = pcall(function()
    local Bounds0511 = require("scripts.core.movement_bounds_contract_0511")
    if Bounds0511 and Bounds0511.install then Bounds0511.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.511] movement_bounds_contract_0511 failed to install: " .. tostring(err)) end
end

-- 0.1.512: scheduler contract pass. Loaded after movement bounds so the order
-- queue becomes a stable intent authority: active orders receive leases,
-- passive UI/radar/mouse-over refreshes cannot churn current work, and senior
-- strategic cascade pulses cool down while dispatcher-owned work is underway.
do
  local ok, err = pcall(function()
    local Scheduler0512 = require("scripts.core.scheduler_contract_0512")
    if Scheduler0512 and Scheduler0512.install then Scheduler0512.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.512] scheduler_contract_0512 failed to install: " .. tostring(err)) end
end

-- 0.1.513: direct acquisition executor migration. Loaded after the scheduler
-- contract so dispatcher-owned acquisition becomes an explicit phase machine:
-- bounded target -> walk adjacent -> work over time -> deposit/return. Legacy
-- direct-mining functions are blocked while the dispatcher owns the direct task.
do
  local ok, err = pcall(function()
    local Direct0513 = require("scripts.core.direct_acquisition_executor_0513")
    if Direct0513 and Direct0513.install then Direct0513.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.513] direct_acquisition_executor_0513 failed to install: " .. tostring(err)) end
end

-- 0.1.514: emergency production executor migration. Loaded after direct
-- acquisition so item production follows scheduler -> dispatcher -> executor:
-- check inventory, prefer Martian emergency facilities, wait/collect machine
-- output, and only then use timed station fallback crafting.
do
  local ok, err = pcall(function()
    local Prod0514 = require("scripts.core.emergency_production_executor_0514")
    if Prod0514 and Prod0514.install then Prod0514.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.514] emergency_production_executor_0514 failed to install: " .. tostring(err)) end
end


-- 0.1.515: consecration executor migration. Loaded after emergency production
-- so Tech-Priest machine maintenance follows scheduler -> dispatcher -> executor:
-- choose useful machine, walk to rite/capsule range, spend visible rite time,
-- consume station-supplied capsule item, and record priest/station source context.
do
  local ok, err = pcall(function()
    local Cons0515 = require("scripts.core.consecration_executor_0515")
    if Cons0515 and Cons0515.install then Cons0515.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.515] consecration_executor_0515 failed to install: " .. tostring(err)) end
end

-- 0.1.516: repair executor migration. Loaded after consecration so Tech-Priest
-- repair work follows scheduler -> dispatcher -> executor: choose useful damaged
-- target, reserve it to avoid dogpiles, walk to repair range, spend timed repair
-- packs, and repair to full rather than waiting for maximum pack efficiency.
do
  local ok, err = pcall(function()
    local Repair0516 = require("scripts.core.repair_executor_0516")
    if Repair0516 and Repair0516.install then Repair0516.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.516] repair_executor_0516 failed to install: " .. tostring(err)) end
end

-- 0.1.517: combat repair doctrine. Loaded after the ordinary repair executor so
-- tactical wall-under-fire repair can route through repair_executor_0516 while
-- the dispatcher decides whether combat repair is safer than direct firing.
do
  local ok, err = pcall(function()
    local CombatRepair0517 = require("scripts.core.combat_repair_doctrine_0517")
    if CombatRepair0517 and CombatRepair0517.install then CombatRepair0517.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.517] combat_repair_doctrine_0517 failed to install: " .. tostring(err)) end
end
-- 0.1.518: movement cadence/task-churn contract. Loaded after combat repair so
-- all dispatcher-owned long actions can request travel leases, while older
-- scheduler/legacy refreshes cannot constantly replace a still-valid route.
do
  local ok, err = pcall(function()
    local Cadence0518 = require("scripts.core.movement_cadence_contract_0518")
    if Cadence0518 and Cadence0518.install then Cadence0518.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.518] movement_cadence_contract_0518 failed to install: " .. tostring(err)) end
end



-- 0.1.519: logistics/construction physical-access contract. Loaded after
-- movement cadence so item pickup, remote inventory withdrawal, construction
-- placement, and station-expansion ghost planning can follow the dispatcher
-- doctrine: priests must walk to sources/sites, construction from available
-- stock is high priority, and expansion ghosts are deferred until the station
-- item is available or actually producible by unlocked/station-known means.
do
  local ok, err = pcall(function()
    local LogBuild0519 = require("scripts.core.logistics_construction_contract_0519")
    if LogBuild0519 and LogBuild0519.install then LogBuild0519.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.519] logistics_construction_contract_0519 failed to install: " .. tostring(err)) end
end


-- 0.1.520: persistent portrait assignment. Loaded after the behavior/logistics
-- refactor layers because it is UI identity state only: it slices portrait sheets
-- into data-stage cells, assigns stable portrait IDs to station/priest pairs,
-- and exposes the assigned cell to the Work State identity plaque.
do
  local ok, err = pcall(function()
    local Portrait0520 = require("scripts.core.portrait_assignment_0520")
    if Portrait0520 and Portrait0520.install then Portrait0520.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.520] portrait_assignment_0520 failed to install: " .. tostring(err)) end
end

-- 0.1.525: expanded persistent priest identity/background dossiers. Loaded after
-- the Work-State/portrait UI passes because it is lore/persona state only: it
-- widens origin, former-assignment, service-history, status, augmentation,
-- preference, and biographical pools without touching behavior authority.
do
  local ok, err = pcall(function()
    local Identity0525 = require("scripts.core.priest_identity_background_0525")
    if Identity0525 and Identity0525.install then Identity0525.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.525] priest_identity_background_0525 failed to install: " .. tostring(err)) end
end

-- 0.1.526: physical known-storage logistics fetch. Loaded after identity/UI
-- passes so dispatcher-owned logistics can prefer already-scanned nearby storage
-- items, such as starting-vessel ammunition, before raw acquisition or emergency
-- crafting. Items are only credited to station inventory after the priest walks
-- to the source and withdraws them.
do
  local ok, err = pcall(function()
    local Fetch0527 = require("scripts.core.logistics_fetch_executor_0527")
    if Fetch0527 and Fetch0527.install then Fetch0527.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.527] logistics_fetch_executor_0527 failed to install: " .. tostring(err)) end
end


-- 0.1.528: dispatcher-owned machine logistics fulfillment. Loaded after the
-- universal known-source fetch wrapper so it can express exact ingredient/fuel
-- needs and then let 0.1.527 fetch them physically before raw acquisition.
-- This services only non-automated local assemblers/furnaces by default: clear
-- outputs, route detritus to an internal waste box, and supply fuel/ingredients.
do
  local ok, err = pcall(function()
    local MachineLogistics0528 = require("scripts.core.logistics_machine_fulfillment_0528")
    if MachineLogistics0528 and MachineLogistics0528.install then MachineLogistics0528.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.528] logistics_machine_fulfillment_0528 failed to install: " .. tostring(err)) end
end

-- 0.1.529: unified scan beam authority and loose-item hoover doctrine. Loaded
-- after machine logistics so all old scan/mining/combat beam calls resolve
-- through one visual controller, and dropped items become physical pickup/storage
-- tasks before ordinary acquisition when safe.
do
  local ok, err = pcall(function()
    local ScanBeams0529 = require("scripts.core.scan_beam_controller_0529")
    if ScanBeams0529 and ScanBeams0529.install then ScanBeams0529.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.529] scan_beam_controller_0529 failed to install: " .. tostring(err)) end
end

do
  local ok, err = pcall(function()
    local GroundHoover0529 = require("scripts.core.ground_item_hoover_0529")
    if GroundHoover0529 and GroundHoover0529.install then GroundHoover0529.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.529] ground_item_hoover_0529 failed to install: " .. tostring(err)) end
end


-- 0.1.530: deterministic conversation voice-bark audio. Loaded after the
-- unified sound manager and chatter systems so floating conversation lines can
-- request a short non-lexical voice clip when their typewriter line begins, and
-- research selection can play the dedicated technology bark. Audio only; no
-- behavior authority.
do
  local ok, err = pcall(function()
    local Voice0530 = require("scripts.core.conversation_voice_0530")
    if Voice0530 and Voice0530.install then Voice0530.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.530] conversation_voice_0530 failed to install: " .. tostring(err)) end
end

-- 0.1.531: operational/mechanical sound reporter. Loaded after voice barks and
-- the unified sound manager so custom machine sounds, BIOS key-clatter, GUI
-- click cues, and occasional Tech-Priest respirator barks stay audio-only and
-- do not become another behavior controller.
do
  local ok, err = pcall(function()
    local OperationalSounds0531 = require("scripts.core.operational_sounds_0531")
    if OperationalSounds0531 and OperationalSounds0531.install then OperationalSounds0531.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.531] operational_sounds_0531 failed to install: " .. tostring(err)) end
end

-- 0.1.532: task/status churn damper and overhead lease. Loaded last so it can
-- protect the existing scheduler/order queue/action-arbiter authorities without
-- becoming a new behavior controller. It blocks passive mouse-over/radar refresh
-- churn, holds active order visual state, deduplicates same-tick heartbeat spam,
-- and gives overhead text a short stability lease.
do
  local ok, err = pcall(function()
    local StatusChurn0532 = require("scripts.core.status_churn_damper_0532")
    if StatusChurn0532 and StatusChurn0532.install then StatusChurn0532.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.532] status_churn_damper_0532 failed to install: " .. tostring(err)) end
end


-- 0.1.533: functional placeholder audio integration. Loaded after the sound
-- manager, operational sound reporter, and status-churn damper so placeholder
-- cues remain reporter-only and cooldown-governed rather than behavior owners.
do
  local ok, err = pcall(function()
    local PlaceholderAudio0533 = require("scripts.core.placeholder_audio_0533")
    if PlaceholderAudio0533 and PlaceholderAudio0533.install then PlaceholderAudio0533.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.533] placeholder_audio_0533 failed to install: " .. tostring(err)) end
end


-- 0.1.534: filtered stone-cache steward. Loaded after audio/status reporters;
-- it is an inventory constraint/reporting layer only and does not create orders,
-- move priests, or claim behavior authority.
do
  local ok, err = pcall(function()
    local StoneCache0534 = require("scripts.core.stone_cache_filter_0534")
    if StoneCache0534 and StoneCache0534.install then StoneCache0534.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.534] stone_cache_filter_0534 failed to install: " .. tostring(err)) end
end

-- 0.1.556: efficiency economy governor. Loaded last so it can cool down repeated
-- rejected target scans, passive order refreshes, duplicate submissions,
-- verbose diagnostics, and legacy service pulses without becoming a behavior
-- controller or bypassing dispatcher/order-queue authority.
do
  local ok, err = pcall(function()
    local Economy0556 = require("scripts.core.efficiency_economy_0556")
    if Economy0556 and Economy0556.install then Economy0556.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.556] efficiency_economy_0556 failed to install: " .. tostring(err)) end
end


-- 0.1.557: second efficiency economy review.  Loaded after 0.1.556 so it can
-- memoize radar detections and share resource-expansion ghost plans without
-- becoming a behavior authority or bypassing the order/dispatcher stack.
do
  local ok, err = pcall(function()
    local Economy0557 = require("scripts.core.efficiency_economy_0557")
    if Economy0557 and Economy0557.install then Economy0557.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.557] efficiency_economy_0557 failed to install: " .. tostring(err)) end
end

-- 0.1.558: Conclave Center physical management anchor and doctrine governance scaffold.
-- Loaded last as a GUI/research-governance reporter. It gates remote Shift+Y access
-- behind a placed Conclave Center, opens the existing management overview from the
-- console, and tracks doctrine-family vote/loyalty state without creating priest
-- movement, construction, acquisition, consecration, or combat work.
do
  local ok, err = pcall(function()
    local Conclave0558 = require("scripts.core.conclave_center_0558")
    if Conclave0558 and Conclave0558.install then Conclave0558.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.558] conclave_center_0558 failed to install: " .. tostring(err)) end
end

-- 0.1.561: Sanctioned order history and authority ledger. Loaded after the
-- Conclave Center so the conclave can display completed writ totals and
-- authority/order-capacity without adding a movement or work controller.
do
  local ok, err = pcall(function()
    local History0561 = require("scripts.core.sanctioned_order_history_0561")
    if History0561 and History0561.install then History0561.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.561] sanctioned_order_history_0561 failed to install: " .. tostring(err)) end
end


-- 0.1.566: movement enforcement governor. Loaded after all dispatcher,
-- economy, and GUI/conclave reporters so it can reject stale far movement
-- requests and return overleashed priests without becoming a work selector.
do
  local ok, err = pcall(function()
    local Move0566 = require("scripts.core.movement_enforcement_0566")
    if Move0566 and Move0566.install then Move0566.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.566] movement_enforcement_0566 failed to install: " .. tostring(err)) end
end


-- 0.1.568: economy/efficiency governor. Loaded after movement enforcement so it can
-- compact diagnostics, rate-limit noisy heartbeat/order-refresh log writes, phase
-- resource-expansion scans, and stagger selected non-critical service loops without
-- becoming a task selector or bypassing dispatcher/order-queue authority.
do
  local ok, err = pcall(function()
    local Economy0568 = require("scripts.core.efficiency_economy_0568")
    if Economy0568 and Economy0568.install then Economy0568.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.568] efficiency_economy_0568 failed to install: " .. tostring(err)) end
end


-- 0.1.569: budgeted economy governor. Loaded last so it can convert the
-- dispatcher and selected reporter/recovery services into rolling buckets, and
-- begin dirty-region tracking for later event-driven scan queues without
-- creating a new task selector or bypassing scheduler/dispatcher authority.
do
  local ok, err = pcall(function()
    local Economy0569 = require("scripts.core.efficiency_economy_0569")
    if Economy0569 and Economy0569.install then Economy0569.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.569] efficiency_economy_0569 failed to install: " .. tostring(err)) end
end


-- 0.1.570: dirty-aware scan economy. Loaded after the rolling dispatcher
-- buckets so resource fallback scans can reuse negative results briefly and
-- catalog sweeps can skip clean unchanged station regions without creating a
-- new behavior controller.
do
  local ok, err = pcall(function()
    local Economy0570 = require("scripts.core.efficiency_economy_0570")
    if Economy0570 and Economy0570.install then Economy0570.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.570] efficiency_economy_0570 failed to install: " .. tostring(err)) end
end

-- 0.1.571: maintenance scan economy. Loaded after dirty-aware scan economy so
-- repair and consecration executors can briefly skip repeated no-work scans in
-- clean station regions, while damage events mark dirty cells for immediate
-- reconsideration. This remains a governor, not a behavior controller.
do
  local ok, err = pcall(function()
    local Economy0571 = require("scripts.core.efficiency_economy_0571")
    if Economy0571 and Economy0571.install then Economy0571.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.571] efficiency_economy_0571 failed to install: " .. tostring(err)) end
end



-- 0.1.572: unobserved transit economy. Loaded after maintenance scan economy
-- so offscreen, in-radius work travel can be collapsed into a same-surface
-- teleport instead of an expensive pathing request. This remains a movement
-- governor only; executors still own actual work completion.
do
  local ok, err = pcall(function()
    local Economy0572 = require("scripts.core.efficiency_economy_0572")
    if Economy0572 and Economy0572.install then Economy0572.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.572] efficiency_economy_0572 failed to install: " .. tostring(err)) end
end


-- 0.1.573: authority-corridor logistics and crafting scaffold. Loaded after
-- unobserved transit economy so inventory/crafting source resolution follows
-- the same writ doctrine: subordinates may borrow superior supply authority
-- only while carrying active work orders, while deposits remain home-local.
do
  local ok, err = pcall(function()
    local Corr0573 = require("scripts.core.authority_corridor_logistics_0573")
    if Corr0573 and Corr0573.install then Corr0573.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.573] authority_corridor_logistics_0573 failed to install: " .. tostring(err)) end
end

-- 0.1.574: Cogitator corridor pathing guard. Loaded after the authority-corridor
-- logistics/crafting scaffold so movement obeys the same writ doctrine:
-- home-local movement by default, superior-station coverage only under active
-- writ/order authority, and long authorized moves decomposed through station
-- corridor waypoints rather than one unbounded wilderness path request.
do
  local ok, err = pcall(function()
    local CorrPath0574 = require("scripts.core.authority_corridor_pathing_0574")
    if CorrPath0574 and CorrPath0574.install then CorrPath0574.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.574] authority_corridor_pathing_0574 failed to install: " .. tostring(err)) end
end

-- 0.1.575: corridor cache and phased path-economy pass. Loaded after the
-- authority corridor pathing guard so repeated same-priest/same-target corridor
-- authorization checks reuse short-lived results, old writ state is cleaned in
-- buckets, and corridor audits do not scan every pair in one synchronized pulse.
do
  local ok, err = pcall(function()
    local Economy0575 = require("scripts.core.efficiency_economy_0575")
    if Economy0575 and Economy0575.install then Economy0575.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.575] efficiency_economy_0575 failed to install: " .. tostring(err)) end
end

-- 0.1.576: diagnostics/budget/machine-reservation economy. Loaded last so it can
-- keep diagnostics quiet by default, expose a per-tick budget scaffold, retire
-- the old Micro-Miner doctrine popup, and put visible/reserved claims around
-- Tech-Priest recipe mutations without becoming a work selector.
do
  local ok, err = pcall(function()
    local Economy0576 = require("scripts.core.efficiency_economy_0576")
    if Economy0576 and Economy0576.install then Economy0576.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.576] efficiency_economy_0576 failed to install: " .. tostring(err)) end
end

-- 0.1.577: enforced global runtime budgets. Loaded after the 0.1.576
-- budget scaffold so expensive executor pulses and low-priority movement
-- requests consume real per-tick budgets and spill deferred work forward rather
-- than hammering the same tick. This remains a governor, not a controller.
do
  local ok, err = pcall(function()
    local Economy0577 = require("scripts.core.efficiency_economy_0577")
    if Economy0577 and Economy0577.install then Economy0577.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.577] efficiency_economy_0577 failed to install: " .. tostring(err)) end
end



-- 0.1.578: station catalog prototype-cache economy. Loaded after global budgets
-- so catalog sweeps stop rediscovering stable prototype facts such as supported
-- inventories and mineable products for every identical entity in every sweep.
do
  local ok, err = pcall(function()
    local Economy0578 = require("scripts.core.efficiency_economy_0578")
    if Economy0578 and Economy0578.install then Economy0578.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.578] efficiency_economy_0578 failed to install: " .. tostring(err)) end
end

-- 0.1.579: event-indexed catalog economy. Loaded after prototype-cache economy
-- so station catalog sweeps can reuse known clean cell contents and fall back
-- to surface.find_entities_filtered only when a cell is dirty or unknown.
do
  local ok, err = pcall(function()
    local Economy0579 = require("scripts.core.efficiency_economy_0579")
    if Economy0579 and Economy0579.install then Economy0579.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.579] efficiency_economy_0579 failed to install: " .. tostring(err)) end
end


-- 0.1.580: consecration economy pass. Loaded after the catalog economy so
-- machine-spirit maintenance is budgeted and dirty-aware instead of polling
-- every sanctifiable machine on every legacy consecration pulse. This remains
-- a governor around the existing consecration pipeline, not a new rite
-- controller.
do
  local ok, err = pcall(function()
    local Economy0580 = require("scripts.core.efficiency_economy_0580")
    if Economy0580 and Economy0580.install then Economy0580.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.580] efficiency_economy_0580 failed to install: " .. tostring(err)) end
end

-- 0.1.581: legacy wrapper consolidation economy. Loaded after consecration
-- economy so old generated helper routes keep their public names but reuse
-- short-lived pair/radius caches instead of repeatedly walking reverse maps and
-- recalculating stable station facts. This is a compatibility shim, not a new
-- behavior controller.
do
  local ok, err = pcall(function()
    local Economy0581 = require("scripts.core.efficiency_economy_0581")
    if Economy0581 and Economy0581.install then Economy0581.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.581] efficiency_economy_0581 failed to install: " .. tostring(err)) end
end



-- 0.1.582: grand behavior-tree economy. Loaded after wrapper consolidation
-- so repeated idle/no-work dispatcher and legacy tick_pair passes sleep briefly
-- instead of re-running the whole behavior stack when nothing changed. This is
-- a cache/governor shim, not a new behavior controller.
do
  local ok, err = pcall(function()
    local Economy0582 = require("scripts.core.efficiency_economy_0582")
    if Economy0582 and Economy0582.install then Economy0582.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.582] efficiency_economy_0582 failed to install: " .. tostring(err)) end
end


-- 0.1.583: visual/render economy. Loaded after behavior-tree economy so
-- offscreen transient render objects are not created when no connected player
-- can plausibly observe them. This is a render governor only, not behavior.
do
  local ok, err = pcall(function()
    local Economy0583 = require("scripts.core.efficiency_economy_0583")
    if Economy0583 and Economy0583.install then Economy0583.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.583] efficiency_economy_0583 failed to install: " .. tostring(err)) end
end


-- 0.1.584: obstacle slap-fight guard. Loaded after visual/render economy so
-- movement-owned priests that begin punching neutral rocks/trees while pathing
-- are stopped and routed through budgeted obstruction clearing instead of
-- spending hours using their vestigial unit melee attack.
do
  local ok, err = pcall(function()
    local Guard0584 = require("scripts.core.obstacle_attack_guard_0584")
    if Guard0584 and Guard0584.install then Guard0584.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.584] obstacle_attack_guard_0584 failed to install: " .. tostring(err)) end
end

-- 0.1.585: event/dirty-mark coalescing economy. Loaded after catalog,
-- consecration, render, and obstacle governors so bursty build/damage/remove
-- events do not repeatedly dirty the same entity/cell/machine in the same few
-- ticks. This is a dirty-work coalescer only, not a behavior controller.
do
  local ok, err = pcall(function()
    local Economy0585 = require("scripts.core.efficiency_economy_0585")
    if Economy0585 and Economy0585.install then Economy0585.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.585] efficiency_economy_0585 failed to install: " .. tostring(err)) end
end


-- 0.1.587: logistics/supply cache economy. Loaded after graphics/dirty-event
-- economy so repeated same-priest/same-item source and inventory count queries
-- reuse short-lived authority/source/count answers instead of rewalking the
-- same station/stash lists many times in one work burst. This is a cache
-- governor only; it does not choose work, craft, mine, move, or deposit.
do
  local ok, err = pcall(function()
    local Economy0587 = require("scripts.core.efficiency_economy_0587")
    if Economy0587 and Economy0587.install then Economy0587.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.587] efficiency_economy_0587 failed to install: " .. tostring(err)) end
end

-- 0.1.593: hard runtime performance firewall. Loaded after all earlier economy
-- shims so legacy debug output and the oldest direct-acquisition movement loop
-- cannot bypass the normal-play quiet mode or hammer pathing with repeated
-- same-target movement reissues.
do
  local ok, err = pcall(function()
    local Economy0593 = require("scripts.core.efficiency_economy_0593")
    if Economy0593 and Economy0593.install then Economy0593.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.593] efficiency_economy_0593 failed to install: " .. tostring(err)) end
end


-- 0.1.594: adaptive runtime route economy. Loaded after the hard performance
-- firewall so registered nth-tick routes can be wrapped in-place. This lets
-- non-critical diagnostics/visual/audio/passive background services skip
-- deterministic pulses under large priest counts while movement/combat/recovery
-- and dispatcher authority remain immediate.
do
  local ok, err = pcall(function()
    local Economy0594 = require("scripts.core.efficiency_economy_0594")
    if Economy0594 and Economy0594.install then Economy0594.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.594] efficiency_economy_0594 failed to install: " .. tostring(err)) end
end



-- 0.1.595: dormant runtime gate. Loaded after the adaptive route economy and
-- hooked through the runtime registry dispatcher so passive nth-tick services do
-- not wake before any Tech-Priest pair/station/conclave/consecration system
-- exists in the world. Events still run and can wake the runtime immediately.
do
  local ok, err = pcall(function()
    local Economy0595 = require("scripts.core.efficiency_economy_0595")
    if Economy0595 and Economy0595.install then Economy0595.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.595] efficiency_economy_0595 failed to install: " .. tostring(err)) end
end



-- 0.1.596: passive-service austerity command/telemetry install. The early
-- hook above already wrapped raw nth-tick registration before legacy services
-- loaded; this late call only exposes diagnostics for the wrapper.
do
  local ok, err = pcall(function()
    local Economy0596 = require("scripts.core.efficiency_economy_0596")
    if Economy0596 and Economy0596.install then Economy0596.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.596] efficiency_economy_0596 failed to install: " .. tostring(err)) end
end

-- 0.1.597: order orchestrator and resource-target reservation economy. Loaded
-- after passive-service austerity so many priests requesting the same resource
-- coordinate through reserved source tiles and short-lived station/item caches
-- instead of each independently scanning and pathing to the same target.
do
  local ok, err = pcall(function()
    local Orchestrator0597 = require("scripts.core.order_orchestrator_0597")
    if Orchestrator0597 and Orchestrator0597.install then Orchestrator0597.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.597] order_orchestrator_0597 failed to install: " .. tostring(err)) end
end

-- 0.1.598: cooperative parallelization route economy. Loaded after the
-- order orchestrator so non-critical registry routes are phase-sliced across
-- ticks based on active priest load. This is deterministic scheduling, not a
-- new behavior controller and not true OS threading.
do
  local ok, err = pcall(function()
    local Economy0598 = require("scripts.core.efficiency_economy_0598")
    if Economy0598 and Economy0598.install then Economy0598.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.598] efficiency_economy_0598 failed to install: " .. tostring(err)) end
end

-- 0.1.599: adaptive priest sleep states. Loaded after cooperative route
-- economy so fully idle priests progressively sleep instead of repeatedly
-- re-entering the legacy tick_pair chain while nothing around them changes.
-- Damage/build/research/player interaction wakes them immediately.
do
  local ok, err = pcall(function()
    local Economy0599 = require("scripts.core.efficiency_economy_0599")
    if Economy0599 and Economy0599.install then Economy0599.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.599] efficiency_economy_0599 failed to install: " .. tostring(err)) end
end

