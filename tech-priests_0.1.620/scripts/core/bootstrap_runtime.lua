-- Tech Priests bootstrap runtime extraction.
-- 0.1.421: migrated late patch/install spine out of control.lua so control.lua
-- can return to being a bootstrap/orchestration file instead of absorbing every
-- newly-added runtime authority.  This module intentionally preserves the old
-- installer order and global compatibility names while moving the text weight out
-- of the entrypoint.

local M = {}

-- Load common helper library early so static audits know these are intentional
-- shared utilities rather than orphaned files. Existing legacy call sites will be
-- migrated onto them gradually.
local _tp_common_entity = require("scripts.core.common.entity_utils")
local _tp_common_math = require("scripts.core.common.math_utils")
local _tp_common_storage = require("scripts.core.common.storage_utils")
local _tp_common_pair = require("scripts.core.common.pair_utils")
local _tp_common_debug = require("scripts.core.common.debug_utils")


function M.install()
-- ============================================================================
-- 0.1.448: runtime-safe floating text bridge.
-- ============================================================================
function TECH_PRIESTS_0448_INSTALL_SAFE_FLOATING_TEXT()
  local ft = require("scripts.core.safe_floating_text")
  if ft and ft.install then ft.install() end
end
TECH_PRIESTS_0448_INSTALL_SAFE_FLOATING_TEXT()
TECH_PRIESTS_0448_INSTALL_SAFE_FLOATING_TEXT = nil

-- ============================================================================
-- 0.1.321 Canonical Scheduler / Action Pipeline Spine + Supply Resolver
-- supply resolver shim migration pass 1 + main-chunk local-limit repair
-- ============================================================================
-- This installer intentionally keeps new module locals inside a short-lived
-- function body. control.lua is already near Factorio/Lua's 200-local main chunk
-- ceiling, so new top-level locals here can break fresh-world startup even if
-- the main menu loads. Do not add new top-level locals below this point.
function TECH_PRIESTS_0321_INSTALL_PIPELINE_SPINE()
  local pipeline = require("scripts.core.task_scheduler")
  local supply_resolver = require("scripts.core.supply_resolver")

  TECH_PRIESTS_0318_PRE_TICK_PAIR = tick_pair
  function tick_pair(pair)
    return pipeline.tick_pair(pair, TECH_PRIESTS_0318_PRE_TICK_PAIR)
  end

  if supply_resolver and supply_resolver.install_legacy_shims then
    supply_resolver.install_legacy_shims({
      build_supply_request = build_supply_request,
      maybe_start_supply_scavenge = maybe_start_supply_scavenge,
      issue_station_logistic_request = issue_station_logistic_request,
      handle_logistic_inventory_scan = handle_logistic_inventory_scan,
      handle_priest_cram_task = handle_priest_cram_task,
      maybe_start_cram_mode = maybe_start_cram_mode,
      handle_priest_scavenge_task = handle_priest_scavenge_task,
      start_logistic_scavenge_inventory_scan = start_logistic_scavenge_inventory_scan,
      find_scavenge_source_for_request = find_scavenge_source_for_request,
      tech_priests_clear_interruptible_supply_work = tech_priests_clear_interruptible_supply_work,
      tech_priests_abort_if_supply_request_obsolete = tech_priests_abort_if_supply_request_obsolete,
      tech_priests_station_inventory_has_requested_supply_0173 = tech_priests_station_inventory_has_requested_supply_0173,
      tech_priests_clear_supply_search_because_station_was_supplied_0173 = tech_priests_clear_supply_search_because_station_was_supplied_0173,
      tech_priests_interrupt_supply_search_if_station_supplied_0173 = tech_priests_interrupt_supply_search_if_station_supplied_0173,
      tech_priests_interrupt_cram_if_station_item_removed_0174 = tech_priests_interrupt_cram_if_station_item_removed_0174
    })
  end

  if pipeline and pipeline.register_commands then
    pipeline.register_commands()
  end
  if supply_resolver and supply_resolver.register_commands then
    supply_resolver.register_commands()
  end

  if log then log("[Tech-Priests 0.1.321] canonical scheduler/action pipeline spine + supply resolver shim migration pass 1 loaded with main-chunk local-limit repair") end
end

TECH_PRIESTS_0321_INSTALL_PIPELINE_SPINE()
TECH_PRIESTS_0321_INSTALL_PIPELINE_SPINE = nil


-- ============================================================================
-- 0.1.322 Friendly-fire combat target safety gate
-- ============================================================================
-- New locals are kept inside this short-lived installer. This patch refuses
-- same-force/allied/cease-fire/neutral combat targets before target acquisition,
-- proxy turret assignment, direct attack commands, and laser fallback damage.
function TECH_PRIESTS_0322_INSTALL_COMBAT_SAFETY_GATE()
  local combat_safety = require("scripts.core.combat_safety")
  if combat_safety and combat_safety.install then combat_safety.install() end
end

TECH_PRIESTS_0322_INSTALL_COMBAT_SAFETY_GATE()
TECH_PRIESTS_0322_INSTALL_COMBAT_SAFETY_GATE = nil


-- ============================================================================
-- 0.1.323 Subordinate-aware task assignment + visible priest work feedback
-- ============================================================================
-- Keep new locals inside this short-lived installer. The main control.lua chunk
-- is still at risk of the Lua 200-local ceiling, so new systems must live in
-- modules and be required from installer functions only.
function TECH_PRIESTS_0323_INSTALL_TASK_ASSIGNMENT_AND_WORK_VISUALS()
  local subordinate_scheduler = require("scripts.core.subordinate_scheduler")
  local work_visuals = require("scripts.core.work_visuals")
  if subordinate_scheduler and subordinate_scheduler.install then subordinate_scheduler.install() end
  if work_visuals and work_visuals.install then work_visuals.install() end
  if log then log("[Tech-Priests 0.1.323] subordinate-aware assignment + visible work-state feedback loaded") end
end

TECH_PRIESTS_0323_INSTALL_TASK_ASSIGNMENT_AND_WORK_VISUALS()
TECH_PRIESTS_0323_INSTALL_TASK_ASSIGNMENT_AND_WORK_VISUALS = nil


-- ============================================================================
-- 0.1.324 Startup provisioning module + inventory scan player-target safety
-- ============================================================================
-- Keep new locals inside this short-lived installer. Startup/player-created logic
-- is being extracted from control.lua, and inventory scans must not target live
-- player character inventories as salvage/search containers.
function TECH_PRIESTS_0324_INSTALL_STARTUP_AND_SCAN_SAFETY()
  local inventory_target_safety = require("scripts.core.inventory_target_safety")
  local startup_provisioning = require("scripts.core.startup_provisioning")
  if inventory_target_safety and inventory_target_safety.install then inventory_target_safety.install() end
  if startup_provisioning and startup_provisioning.install then startup_provisioning.install() end
  if log then log("[Tech-Priests 0.1.324] startup provisioning + inventory target safety loaded") end
end

TECH_PRIESTS_0324_INSTALL_STARTUP_AND_SCAN_SAFETY()
TECH_PRIESTS_0324_INSTALL_STARTUP_AND_SCAN_SAFETY = nil

-- ============================================================================
-- 0.1.325 Resource Doctrine Acquisition Chain
-- ============================================================================
-- Keep new locals inside this short-lived installer. This module patches the
-- existing supply/emergency acquisition behaviors so a failed exact-source scan
-- falls forward into dependency ingredients, mineable-result scanning, rocks,
-- trees, and primitive fallback harvesting instead of standing idle forever.
function TECH_PRIESTS_0325_INSTALL_RESOURCE_DOCTRINE_CHAIN()
  local resource_doctrine = require("scripts.core.resource_doctrine")
  if resource_doctrine and resource_doctrine.install then resource_doctrine.install() end
  if log then log("[Tech-Priests 0.1.325] source doctrine acquisition chain installed") end
end

TECH_PRIESTS_0325_INSTALL_RESOURCE_DOCTRINE_CHAIN()
TECH_PRIESTS_0325_INSTALL_RESOURCE_DOCTRINE_CHAIN = nil

-- ============================================================================
-- 0.1.326 Station Known-Resource Catalog + Emergency Cascade Doctrine
-- ============================================================================
-- Keep new locals inside this short-lived installer. Stations now maintain a
-- radar-style catalog of local active resources, entities, stored items, and
-- subordinate station trees; emergency mode cascades from senior+ stations into
-- subordinate stations and immediately applies acquisition pressure.
function TECH_PRIESTS_0326_INSTALL_STATION_CATALOG_AND_EMERGENCY_CASCADE()
  local station_catalog = require("scripts.core.station_catalog")
  local emergency_cascade = require("scripts.core.emergency_cascade")
  if station_catalog and station_catalog.install then station_catalog.install() end
  if emergency_cascade and emergency_cascade.install then emergency_cascade.install() end
  if log then log("[Tech-Priests 0.1.326] station catalog + emergency cascade installed") end
end

TECH_PRIESTS_0326_INSTALL_STATION_CATALOG_AND_EMERGENCY_CASCADE()
TECH_PRIESTS_0326_INSTALL_STATION_CATALOG_AND_EMERGENCY_CASCADE = nil

-- ============================================================================
-- 0.1.327 Radar-sweep catalog snapshots + known-resource tags + GUI bus
-- ============================================================================
-- Keep new locals inside this short-lived installer. The station catalog now
-- refreshes on full radar-sweep cadence, owns resource tags/de-duplication, and
-- the GUI bus becomes the final GUI event owner for known-resource panels.
function TECH_PRIESTS_0327_INSTALL_RADAR_CATALOG_TAGS_AND_GUI_BUS()
  local station_catalog = require("scripts.core.station_catalog")
  local gui_bus = require("scripts.core.gui_bus")
  if station_catalog and station_catalog.install then station_catalog.install() end
  if gui_bus and gui_bus.install then gui_bus.install() end
  if log then log("[Tech-Priests 0.1.327] radar-sweep station catalog + resource tags + GUI bus installed") end
end

TECH_PRIESTS_0327_INSTALL_RADAR_CATALOG_TAGS_AND_GUI_BUS()
TECH_PRIESTS_0327_INSTALL_RADAR_CATALOG_TAGS_AND_GUI_BUS = nil


-- 0.1.328 placement/network visual quality-of-life installer.
-- Keep requires inside this short-lived function so control.lua does not gain
-- additional main-chunk locals and re-trigger Lua's 200-local ceiling.
function TECH_PRIESTS_0328_INSTALL_NETWORK_VISUALS()
  local visuals = require("scripts.core.network_visuals")
  local catalog = require("scripts.core.station_catalog")
  if catalog and catalog.install then catalog.install() end
  if visuals and visuals.install then visuals.install() end
end

TECH_PRIESTS_0328_INSTALL_NETWORK_VISUALS()
TECH_PRIESTS_0328_INSTALL_NETWORK_VISUALS = nil


-- ============================================================================
-- 0.1.330 Radar afterglow + hierarchy visual repair installer
-- ============================================================================
-- Keep requires inside this short-lived function so control.lua does not gain
-- additional main-chunk locals and re-trigger Lua's 200-local ceiling.
function TECH_PRIESTS_0330_INSTALL_VISUAL_REPAIR_PASS()
  local catalog = require("scripts.core.station_catalog")
  local visuals = require("scripts.core.network_visuals")
  local afterglow = require("scripts.core.radar_afterglow")
  if catalog and catalog.install then catalog.install() end
  if visuals and visuals.install then visuals.install() end
  if afterglow and afterglow.install then afterglow.install() end
  if log then log("[Tech-Priests 0.1.330] radar afterglow + hierarchy visuals + belt catalog guardrails loaded") end
end

TECH_PRIESTS_0330_INSTALL_VISUAL_REPAIR_PASS()
TECH_PRIESTS_0330_INSTALL_VISUAL_REPAIR_PASS = nil

-- ============================================================================
-- 0.1.331 Background Chatter + Visual Alignment Repair
-- ============================================================================
-- Keep requires inside this short-lived function so control.lua does not gain
-- additional main-chunk locals and re-trigger Lua's 200-local ceiling.
function TECH_PRIESTS_0331_INSTALL_CHATTER_AND_VISUAL_REPAIRS()
  local chatter = require("scripts.core.chatter")
  local visuals = require("scripts.core.network_visuals")
  local afterglow = require("scripts.core.radar_afterglow")
  local glow_boost = require("scripts.core.glow_boost")
  if chatter and chatter.install then chatter.install() end
  if visuals and visuals.install then visuals.install() end
  if afterglow and afterglow.install then afterglow.install() end
  if glow_boost and glow_boost.install then glow_boost.install() end
  if log then log("[Tech-Priests 0.1.331] background chatter + lower-right radar afterglow anchor + peer dashed lines + glow boost loaded") end
end

TECH_PRIESTS_0331_INSTALL_CHATTER_AND_VISUAL_REPAIRS()
TECH_PRIESTS_0331_INSTALL_CHATTER_AND_VISUAL_REPAIRS = nil


-- ============================================================================
-- 0.1.332 Chatter Work-Safety + Radar Alignment + Visual Stability Repair
-- ============================================================================
-- Keep requires inside this short-lived function so control.lua does not gain
-- additional main-chunk locals and re-trigger Lua's 200-local ceiling.
function TECH_PRIESTS_0332_INSTALL_CHATTER_VISUAL_WORK_REPAIR()
  local chatter = require("scripts.core.chatter")
  local visuals = require("scripts.core.network_visuals")
  local afterglow = require("scripts.core.radar_afterglow")
  if chatter and chatter.install then chatter.install() end
  if visuals and visuals.install then visuals.install() end
  if afterglow and afterglow.install then afterglow.install() end
  if log then log("[Tech-Priests 0.1.332] chatter work-safety + direct tap + radar alignment + visual stability repair loaded") end
end

TECH_PRIESTS_0332_INSTALL_CHATTER_VISUAL_WORK_REPAIR()
TECH_PRIESTS_0332_INSTALL_CHATTER_VISUAL_WORK_REPAIR = nil


-- ============================================================================
-- 0.1.333 Visual Marker / Chatter Catalog / Acquisition Repair
-- ============================================================================
-- Keep requires inside this short-lived function so control.lua does not gain
-- additional main-chunk locals and re-trigger Lua's 200-local ceiling.
function TECH_PRIESTS_0333_INSTALL_VISUAL_CHATTER_ACQUISITION_REPAIR()
  local visuals = require("scripts.core.network_visuals")
  local chatter = require("scripts.core.chatter")
  local acquisition_repair = require("scripts.core.acquisition_repair")
  if visuals and visuals.install then visuals.install() end
  if chatter and chatter.install then chatter.install() end
  if acquisition_repair and acquisition_repair.install then acquisition_repair.install() end
  if log then log("[Tech-Priests 0.1.333] visual marker + chatter catalog + acquisition prototype repair loaded") end
end

TECH_PRIESTS_0333_INSTALL_VISUAL_CHATTER_ACQUISITION_REPAIR()
TECH_PRIESTS_0333_INSTALL_VISUAL_CHATTER_ACQUISITION_REPAIR = nil

-- ============================================================================
-- 0.1.336 Conversation Pointer Audit + Acquisition Unstick
-- ============================================================================
-- Keep requires inside this short-lived function so control.lua does not gain
-- additional main-chunk locals. This pass audits the legacy technology-aware
-- conversation doctrine and adds a non-invasive acquisition unstick pulse for
-- pairs that fall into idle/no-managed-priority-claimed while visibly needing
-- ammo or primitive resources.
function TECH_PRIESTS_0335_INSTALL_CONVERSATION_AND_UNSTICK_AUDIT()
  local conversation_audit = require("scripts.core.conversation_audit")
  local acquisition_unstick = require("scripts.core.acquisition_unstick")
  local chatter = require("scripts.core.chatter")
  if conversation_audit and conversation_audit.install then conversation_audit.install() end
  if acquisition_unstick and acquisition_unstick.install then acquisition_unstick.install() end
  if chatter and chatter.install then chatter.install() end
  if log then log("[Tech-Priests 0.1.336] conversation tech audit + acquisition unstick loaded") end
end

TECH_PRIESTS_0335_INSTALL_CONVERSATION_AND_UNSTICK_AUDIT()
TECH_PRIESTS_0335_INSTALL_CONVERSATION_AND_UNSTICK_AUDIT = nil

-- ============================================================================
-- 0.1.336 Direct Acquisition Executor / Anti-Loiter Mining Worker
-- ============================================================================
-- Keep requires inside this short-lived function so control.lua does not gain
-- additional main-chunk locals. This pass makes “I am mining ore” mean an
-- enforced move-to-target and mining loop, not a label while the priest loiters
-- around its Cogitator Station.
function TECH_PRIESTS_0336_INSTALL_DIRECT_ACQUISITION_EXECUTOR()
  local acquisition_executor = require("scripts.core.acquisition_executor")
  local acquisition_repair = require("scripts.core.acquisition_repair")
  local acquisition_unstick = require("scripts.core.acquisition_unstick")
  if acquisition_executor and acquisition_executor.install then acquisition_executor.install() end
  if acquisition_repair and acquisition_repair.install then acquisition_repair.install() end
  if acquisition_unstick and acquisition_unstick.install then acquisition_unstick.install() end
  if log then log("[Tech-Priests 0.1.336] direct acquisition executor + anti-loiter mining worker loaded") end
end

TECH_PRIESTS_0336_INSTALL_DIRECT_ACQUISITION_EXECUTOR()
TECH_PRIESTS_0336_INSTALL_DIRECT_ACQUISITION_EXECUTOR = nil


-- ============================================================================
-- 0.1.337 Station-Anchored Crafting Feedback / Success Diagnostics
-- ============================================================================
-- Keep requires inside this short-lived function so control.lua does not gain
-- additional main-chunk locals. Mining is performed at the mine; emergency
-- field-fabrication is performed back at the Cogitator Station with a visible
-- progress bar and explicit completion diagnostics.
function TECH_PRIESTS_0337_INSTALL_STATION_CRAFTING_EXECUTOR()
  local crafting_executor = require("scripts.core.crafting_executor")
  local work_visuals = require("scripts.core.work_visuals")
  local acquisition_executor = require("scripts.core.acquisition_executor")
  local acquisition_repair = require("scripts.core.acquisition_repair")
  if crafting_executor and crafting_executor.install then crafting_executor.install() end
  if work_visuals and work_visuals.install then work_visuals.install() end
  if acquisition_executor and acquisition_executor.install then acquisition_executor.install() end
  if acquisition_repair and acquisition_repair.install then acquisition_repair.install() end
  if log then log("[Tech-Priests 0.1.337] station-anchored crafting executor + progress/success diagnostics loaded") end
end

TECH_PRIESTS_0337_INSTALL_STATION_CRAFTING_EXECUTOR()
TECH_PRIESTS_0337_INSTALL_STATION_CRAFTING_EXECUTOR = nil


-- ============================================================================
-- 0.1.338 Construction Planner / Physical Build Task Scaffold
-- ============================================================================
-- Keep requires inside this short-lived function so control.lua does not gain
-- additional main-chunk locals.  This begins the long construction doctrine:
-- miners place on resources; furnaces/assemblers/labs search circular station
-- build sites; belts/pipes/poles/inserters are detected but deferred to their
-- own later network-placement submodules.
function TECH_PRIESTS_0338_INSTALL_CONSTRUCTION_PLANNER()
  local construction_planner = require("scripts.core.construction_planner")
  if construction_planner and construction_planner.install then construction_planner.install() end
  if log then log("[Tech-Priests 0.1.338] construction planner physical build scaffold loaded") end
end

TECH_PRIESTS_0338_INSTALL_CONSTRUCTION_PLANNER()
TECH_PRIESTS_0338_INSTALL_CONSTRUCTION_PLANNER = nil


-- 0.1.339/0.1.341 Martian emergency facility doctrine + immediate placed-facility tagging and faster emergency construction.
function TECH_PRIESTS_0339_INSTALL_EMERGENCY_FACILITY_DOCTRINE()
  local emergency_facilities = require("scripts.core.emergency_facility_doctrine")
  if emergency_facilities and emergency_facilities.install then emergency_facilities.install() end
  if log then log("[Tech-Priests 0.1.342] emergency facility doctrine installer complete") end
end

TECH_PRIESTS_0339_INSTALL_EMERGENCY_FACILITY_DOCTRINE()
TECH_PRIESTS_0339_INSTALL_EMERGENCY_FACILITY_DOCTRINE = nil


-- ============================================================================
-- 0.1.348 Consecration Application Repair / Prototype Follow-up
-- ============================================================================
-- Late wrapper so it sits after older selected-entity wrappers.  It does not
-- replace drag-select consecration; it adds a conservative close-range held-item
-- application path back into the modularized consecration API.
function TECH_PRIESTS_0348_INSTALL_CONSECRATION_APPLICATION_REPAIR()
  _G.TECH_PRIESTS_0348_PRE_ON_SELECTED_ENTITY_CHANGED = _G.on_selected_entity_changed
  _G.on_selected_entity_changed = function(event)
    if _G.TECH_PRIESTS_0348_PRE_ON_SELECTED_ENTITY_CHANGED then
      pcall(_G.TECH_PRIESTS_0348_PRE_ON_SELECTED_ENTITY_CHANGED, event)
    end
    -- 0.1.351: hover/selection application removed. Sacred Machine Oil is now
    -- explicitly applied through capsule use / on_player_used_capsule so merely
    -- waving the cursor across machines no longer consumes consecration items.
  end
  if script and defines and defines.events and defines.events.on_selected_entity_changed then
    script.on_event(defines.events.on_selected_entity_changed, _G.on_selected_entity_changed)
  end
  if commands then
    pcall(function() commands.remove_command("tp-consecration-0348") end)
    commands.add_command("tp-consecration-0348", "Tech Priests 0.1.348 consecration direct-apply diagnostic for selected entity.", function(command)
      local player = game.players[command.player_index]
      if not player then return end
      local ent = player.selected
      if not (ent and ent.valid) then player.print("[tp-consecration-0348] select a consecration target"); return end
      local rec = get_consecration_record and get_consecration_record(ent) or nil
      if not rec then player.print("[tp-consecration-0348] selected entity is not a consecration target: " .. tostring(ent.name)); return end
      player.print("[tp-consecration-0348] " .. tostring(ent.name) .. " sanctity=" .. tostring(rec.sanctification) .. "/" .. tostring(rec.max_sanctification) .. " direct-apply-ready=" .. tostring(tech_priests_0348_try_apply_cursor_consecration ~= nil))
    end)
  end
  if log then log("[Tech-Priests 0.1.348] consecration held-item application repair installed") end
end

TECH_PRIESTS_0348_INSTALL_CONSECRATION_APPLICATION_REPAIR()
TECH_PRIESTS_0348_INSTALL_CONSECRATION_APPLICATION_REPAIR = nil


-- ============================================================================
-- 0.1.351 Explicit Sacred Machine Oil use handler / visual scale follow-up
-- ============================================================================
function TECH_PRIESTS_0351_INSTALL_EXPLICIT_CONSECRATION_USE()
  local function find_oil_target(player, position)
    if not (player and player.valid) then return nil end
    local selected = player.selected
    if selected and selected.valid and is_consecration_target and is_consecration_target(selected) then
      return selected
    end
    local surface = player.surface
    if not (surface and position) then return nil end
    local entities = surface.find_entities_filtered{ position = position, radius = 1.25, force = player.force }
    local best, best_dist
    for _, ent in pairs(entities or {}) do
      if ent and ent.valid and is_consecration_target and is_consecration_target(ent) then
        local dx = (ent.position.x or 0) - (position.x or 0)
        local dy = (ent.position.y or 0) - (position.y or 0)
        local d = dx * dx + dy * dy
        if not best_dist or d < best_dist then best, best_dist = ent, d end
      end
    end
    return best
  end

  local function on_used_capsule(event)
    if not event then return end
    local used_item = event.item
    local used_name = type(used_item) == "string" and used_item or (used_item and used_item.name)
    if used_name ~= "sacred-machine-oil" and used_name ~= "machine-maintenance-litany" and used_name ~= "ritual-of-machine-appeasement" then return end
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    local target = find_oil_target(player, event.position or (player.selected and player.selected.valid and player.selected.position) or player.position)
    if target and target.valid and tech_priests_0351_apply_consecration_no_consume then
      pcall(tech_priests_0351_apply_consecration_no_consume, player, target, used_name)
    else
      player.create_local_flying_text({ text = { "tech-priests-consecration.sanctification-invalid" }, position = event.position or player.position })
    end
  end

  if script and defines and defines.events and defines.events.on_player_used_capsule then
    script.on_event(defines.events.on_player_used_capsule, on_used_capsule)
  end

  if commands then
    pcall(function() commands.remove_command("tp-consecration-0351") end)
    commands.add_command("tp-consecration-0351", "Tech Priests 0.1.351/0.1.352 explicit consecration item application diagnostic.", function(command)
      local player = game.players[command.player_index]
      if not player then return end
      local ent = player.selected
      if not (ent and ent.valid) then player.print("[tp-consecration-0351] Select a consecration target; Sacred Machine Oil is now explicit capsule-use, not hover-use."); return end
      local rec = get_consecration_record and get_consecration_record(ent) or nil
      player.print("[tp-consecration-0351] selected=" .. tostring(ent.name) .. " target=" .. tostring(rec ~= nil) .. " sanctity=" .. tostring(rec and rec.sanctification or "?") .. "/" .. tostring(rec and rec.max_sanctification or "?") .. " capsule-use-handler=true")
    end)
  end
  if commands then
    pcall(function() commands.remove_command("tp-consecration-0352") end)
    commands.add_command("tp-consecration-0352", "Tech Priests 0.1.352 explicit consecration item application diagnostic.", function(command)
      local player = game.players[command.player_index]
      if not player then return end
      local ent = player.selected
      if not (ent and ent.valid) then player.print("[tp-consecration-0352] Select a consecration target; oil/litany/appeasement are explicit use items. Incense remains an area cloud grenade."); return end
      local rec = get_consecration_record and get_consecration_record(ent) or nil
      player.print("[tp-consecration-0352] selected=" .. tostring(ent.name) .. " target=" .. tostring(rec ~= nil) .. " sanctity=" .. tostring(rec and rec.sanctification or "?") .. "/" .. tostring(rec and rec.max_sanctification or "?") .. " explicit-use-handler=true")
    end)
  end
  if log then log("[Tech-Priests 0.1.351] explicit Sacred Machine Oil capsule-use handler loaded") end
end

TECH_PRIESTS_0351_INSTALL_EXPLICIT_CONSECRATION_USE()
TECH_PRIESTS_0351_INSTALL_EXPLICIT_CONSECRATION_USE = nil


-- ============================================================================
-- 0.1.354 Protected Station Network Overlay Repair
-- ============================================================================
-- Keep station radius and inter-station connection rendering in its own small
-- module so consecration, construction, chatter, and acquisition changes cannot
-- accidentally break these visual diagnostics again.
function TECH_PRIESTS_0355_INSTALL_STATION_NETWORK_OVERLAY()
  local overlay = require("scripts.core.station_network_overlay")
  if overlay and overlay.install then overlay.install() end
  if log then log("[Tech-Priests 0.1.354] protected station network overlay repair loaded") end
end

TECH_PRIESTS_0355_INSTALL_STATION_NETWORK_OVERLAY()
TECH_PRIESTS_0355_INSTALL_STATION_NETWORK_OVERLAY = nil


-- ============================================================================
-- 0.1.357 Station-Bound Inventory Steward Repair
-- ============================================================================
-- Tech-Priests do not own active inventory. The bound Cogitator Station is
-- their inventory; priest inventory is only transient cargo to evacuate.
function TECH_PRIESTS_0357_INSTALL_INVENTORY_STEWARD()
  local steward = require("scripts.core.inventory_steward")
  if steward and steward.install then steward.install() end
  if log then log("[Tech-Priests 0.1.357] station-bound inventory steward repair loaded") end
end

TECH_PRIESTS_0357_INSTALL_INVENTORY_STEWARD()
TECH_PRIESTS_0357_INSTALL_INVENTORY_STEWARD = nil

-- ============================================================================
-- 0.1.358 Station-Bound Work Doctrine Audit and GUI Panel
-- ============================================================================
-- The Cogitator Station is the inventory, memory, task owner, and doctrinal
-- authority.  The Tech-Priest is the mobile actuator and temporary carrier only.
-- This module exposes that state in a side panel and gives other modules a
-- single canonical station-bound inventory API to call.
function TECH_PRIESTS_0358_INSTALL_STATION_WORK_INVENTORY()
  local work = require("scripts.core.station_work_inventory")
  if work and work.install then work.install() end
  if log then log("[Tech-Priests 0.1.358] station-bound work doctrine audit panel loaded") end
end

TECH_PRIESTS_0358_INSTALL_STATION_WORK_INVENTORY()
TECH_PRIESTS_0358_INSTALL_STATION_WORK_INVENTORY = nil


-- ============================================================================
-- 0.1.360 Arterial Factory Planning Scaffold
-- ============================================================================
-- Begins station/subordinate-range-aware science/factory ghost planning.  This
-- is intentionally a planning scaffold: it creates a recipe-demand tree and a
-- minimal starter ghost layout without taking ownership of construction,
-- acquisition, rails, drones, roboports, or pipe routing yet.
function TECH_PRIESTS_0360_INSTALL_ARTERIAL_PLANNER()
  local arterial = require("scripts.core.arterial_planner")
  if arterial and arterial.install then arterial.install() end
  if log then log("[Tech-Priests 0.1.360] arterial factory planning scaffold loaded") end
end

TECH_PRIESTS_0360_INSTALL_ARTERIAL_PLANNER()
TECH_PRIESTS_0360_INSTALL_ARTERIAL_PLANNER = nil

-- ============================================================================
-- 0.1.361 Scheduler Behavior Tree / Ownership Map Audit
-- ============================================================================
-- This is a diagnostic and documentation-alignment layer.  It folds the current
-- task scheduler, station-bound inventory doctrine, acquisition, construction,
-- emergency facility, consecration, catalog, chatter, and arterial planning
-- modules into one visible ownership map.  It should not become a new behavior
-- executor; it identifies which existing module should own each behavior.
function TECH_PRIESTS_0361_INSTALL_SCHEDULER_BEHAVIOR_TREE()
  local tree = require("scripts.core.scheduler_behavior_tree")
  if tree and tree.install then tree.install() end
  if log then log("[Tech-Priests 0.1.361] scheduler behavior tree / ownership map audit loaded") end
end

TECH_PRIESTS_0361_INSTALL_SCHEDULER_BEHAVIOR_TREE()
TECH_PRIESTS_0361_INSTALL_SCHEDULER_BEHAVIOR_TREE = nil

-- ============================================================================
-- 0.1.362 Station Pair State Ledger
-- ============================================================================
-- Per Cogitator Station / Tech-Priest logic dossier.  Stores identity,
-- hierarchy, station-bound logistics, transient cargo, planning summary,
-- scheduler observations, and diagnostics.  This module stores/reports state;
-- it does not become a new behavior executor.
function TECH_PRIESTS_0362_INSTALL_STATION_PAIR_STATE_LEDGER()
  local pair_state = require("scripts.core.station_pair_state")
  if pair_state and pair_state.install then pair_state.install() end
  if log then log("[Tech-Priests 0.1.362] station pair state ledger loaded") end
end

TECH_PRIESTS_0362_INSTALL_STATION_PAIR_STATE_LEDGER()
TECH_PRIESTS_0362_INSTALL_STATION_PAIR_STATE_LEDGER = nil

-- ============================================================================
-- 0.1.363 Station Pair State / Inventory Recovery Failsafe
-- ============================================================================
-- Validates and repairs the per-pair runtime dossier and station-bound inventory
-- supporting state.  Recovery mirrors pair creation/respawn initialization:
-- pair map, priest map, radius, display names, station inventory visibility,
-- logistic cache, stash root, and pair-state ledger are reasserted.  This is a
-- state repair/reporting module only, not a scheduler or executor.
function TECH_PRIESTS_0363_INSTALL_STATION_PAIR_RECOVERY()
  local recovery = require("scripts.core.station_pair_recovery")
  if recovery and recovery.install then recovery.install() end
  if log then log("[Tech-Priests 0.1.363] station pair state / inventory recovery failsafe loaded") end
end

TECH_PRIESTS_0363_INSTALL_STATION_PAIR_RECOVERY()
TECH_PRIESTS_0363_INSTALL_STATION_PAIR_RECOVERY = nil

-- ============================================================================
-- 0.1.371 Doctrine Argument Social Module / Embedded Conclave Statistics Tab
-- ============================================================================
-- Display/social-only doctrine argument layer. Priests may debate doctrine in
-- five statement/response rounds. The module tracks per-priest doctrine camp
-- alignment scores in the range -5..+5 and exposes the Conclave Statistics GUI
-- heat map as a tab inside the Shift+Y command overview. It does not alter force allegiance, targeting, scheduler priority,
-- construction, acquisition, inventory ownership, or hierarchy.
function TECH_PRIESTS_0371_INSTALL_DOCTRINE_ARGUMENTS()
  local doctrine_argument = require("scripts.core.doctrine_argument")
  if doctrine_argument and doctrine_argument.install then doctrine_argument.install() end
  if log then log("[Tech-Priests 0.1.371] doctrine argument social module and embedded Conclave Statistics tab loaded") end
end

TECH_PRIESTS_0371_INSTALL_DOCTRINE_ARGUMENTS()
TECH_PRIESTS_0371_INSTALL_DOCTRINE_ARGUMENTS = nil


-- ============================================================================
-- 0.1.409 Consecration visibility watchdog / emergency pole testing follow-up
-- ============================================================================
-- This is a narrow regression hardening pass.  The 0.1.408 font/chatter work did
-- not intentionally touch machine-spirit state, but live sandbox testing showed
-- newly placed machines were no longer visibly presenting consecration state.
-- Because this control.lua has many historical append-style event wrappers,
-- this final wrapper re-registers the current build/remove/selection chain and
-- explicitly reasserts consecration registration after the older handlers run.

TECH_PRIESTS_0409_PRE_ON_BUILT = on_built
function on_built(event)
  if TECH_PRIESTS_0409_PRE_ON_BUILT then
    pcall(TECH_PRIESTS_0409_PRE_ON_BUILT, event)
  end
  local entity = event and (event.entity or event.created_entity or event.destination)
  if entity and entity.valid and register_consecration_target then
    pcall(register_consecration_target, entity)
    if is_consecration_target and is_consecration_target(entity) then
      local record = get_consecration_record and get_consecration_record(entity) or nil
      if record then
        if update_sanctification_overlay then pcall(update_sanctification_overlay, record, true) end
      end
    end
  end
end

TECH_PRIESTS_0409_PRE_ON_REMOVED = on_removed
function on_removed(event)
  local entity = event and event.entity
  if TECH_PRIESTS_0409_PRE_ON_REMOVED then
    pcall(TECH_PRIESTS_0409_PRE_ON_REMOVED, event)
  end
  if entity and entity.valid and remove_consecration_target then
    pcall(remove_consecration_target, entity)
  end
end

function tech_priests_0409_refresh_selected_consecration_for_player(player)
  if not (player and player.valid and player.selected and player.selected.valid) then return false end
  local entity = player.selected
  if not (is_consecration_target and is_consecration_target(entity)) then return false end
  local record = get_consecration_record and get_consecration_record(entity) or nil
  if not record then return false end
  if draw_sanctification_label then pcall(draw_sanctification_label, record) end
  if update_sanctification_overlay then pcall(update_sanctification_overlay, record, false) end
  return true
end

TECH_PRIESTS_0409_PRE_ON_SELECTED_ENTITY_CHANGED = on_selected_entity_changed
function on_selected_entity_changed(event)
  if TECH_PRIESTS_0409_PRE_ON_SELECTED_ENTITY_CHANGED then
    pcall(TECH_PRIESTS_0409_PRE_ON_SELECTED_ENTITY_CHANGED, event)
  end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if player then tech_priests_0409_refresh_selected_consecration_for_player(player) end
end

if script and defines and defines.events then
  script.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
  }, on_built)

  script.on_event({
    defines.events.on_entity_died,
    defines.events.on_pre_player_mined_item,
    defines.events.on_robot_pre_mined,
    defines.events.script_raised_destroy
  }, on_removed)

  script.on_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)
end

if script and script.on_nth_tick then
  script.on_nth_tick(149, function()
    if ensure_storage then pcall(ensure_storage) end
    if game and game.connected_players then
      for _, player in pairs(game.connected_players) do
        tech_priests_0409_refresh_selected_consecration_for_player(player)
      end
    end
    if storage and storage.tech_priests then
      local next_scan = storage.tech_priests.next_consecration_watchdog_scan_0409 or 0
      if game and game.tick >= next_scan then
        storage.tech_priests.next_consecration_watchdog_scan_0409 = game.tick + 1800
        if scan_existing_consecration_targets then pcall(scan_existing_consecration_targets) end
      end
    end
  end)
end

if commands then
  pcall(function() commands.remove_command("tp-consecration-0409") end)
  commands.add_command("tp-consecration-0409", "Inspect selected machine-spirit/consecration state after the 0.1.409 watchdog pass.", function(command)
    local player = command and command.player_index and game.get_player(command.player_index) or nil
    if not (player and player.valid) then return end
    local entity = player.selected
    if not (entity and entity.valid) then player.print("[tp-consecration-0409] select a machine"); return end
    local target = is_consecration_target and is_consecration_target(entity) or false
    local record = target and get_consecration_record and get_consecration_record(entity) or nil
    if record then
      player.print("[tp-consecration-0409] selected=" .. tostring(entity.name) .. " target=true sanctity=" .. tostring(record.sanctification) .. "/" .. tostring(record.max_sanctification) .. " unit=" .. tostring(entity.unit_number))
      tech_priests_0409_refresh_selected_consecration_for_player(player)
    else
      player.print("[tp-consecration-0409] selected=" .. tostring(entity.name) .. " target=" .. tostring(target) .. " unit=" .. tostring(entity.unit_number or "nil"))
    end
  end)
end

if log then log("[Tech-Priests 0.1.409] consecration visibility watchdog and emergency grid radius follow-up loaded") end


-- ============================================================================
-- 0.1.412: ground-priest movement anti-snap diagnostic.
-- ============================================================================
-- Ground priests should move by unit commands, not by conversation-lock snapping.
-- This command reports the selected pair's current movement/task state while the
-- tree/rock emergency gather path is under observation.
if commands then
  pcall(function() commands.remove_command("tp-movement-0412") end)
  pcall(function()
    commands.add_command("tp-movement-0412", "Tech Priests 0.1.412 movement/task diagnostic for selected priest/station.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local pair = nil
      if tech_priests_get_selected_pair_0247 then pcall(function() pair = tech_priests_get_selected_pair_0247(player) end) end
      if not pair and tech_priests_0264_find_pair_for_player then pcall(function() pair = tech_priests_0264_find_pair_for_player(player) end) end
      if not pair then player.print("[tp-movement-0412] Select a Cogitator Station or Tech-Priest."); return end
      local task = pair.emergency_craft
      local cur = task and task.current or nil
      local cur_pos = cur and ((cur.entity and cur.entity.valid and cur.entity.position) or cur.position) or nil
      player.print("[tp-movement-0412] mode=" .. tostring(pair.mode) .. " station=" .. tostring(pair.station and pair.station.unit_number) .. " priest=" .. tostring(pair.priest and pair.priest.valid and pair.priest.unit_number))
      player.print("  emergency_craft=" .. tostring(task ~= nil) .. " current_kind=" .. tostring(cur and cur.kind) .. " current_item=" .. tostring(cur and (cur.item_name or cur.output_item)))
      if cur_pos then player.print("  current_target_pos=" .. tostring(math.floor(cur_pos.x * 10) / 10) .. "," .. tostring(math.floor(cur_pos.y * 10) / 10)) end
      if pair.priest and pair.priest.valid then player.print("  priest_pos=" .. tostring(math.floor(pair.priest.position.x * 10) / 10) .. "," .. tostring(math.floor(pair.priest.position.y * 10) / 10)) end
      if pair.idle_conversation_lock_position_0179 then player.print("  conversation_pin=soft current-adopting; no ground teleport snap") end
    end)
  end)
end

if log then log("[Tech-Priests 0.1.412] ground priest conversation lock no longer teleports; direct gather repath/stall cadence slowed for tree/rock movement observation") end

-- ============================================================================
-- 0.1.413: consecration operation-counter diagnostic.
-- ============================================================================
-- Assembler sanctification decay now prefers LuaEntity.products_finished when
-- available, because fast recipes can complete between the older 10-tick
-- crafting_progress snapshots.  This command reports both sensors so live tests
-- can verify that crafting operations are being seen.
if commands then
  pcall(function() commands.remove_command("tp-consecration-0413") end)
  pcall(function()
    commands.add_command("tp-consecration-0413", "Inspect selected sanctified machine decay counters after the 0.1.413 operation sensor repair.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local entity = player.selected
      if not (entity and entity.valid) then player.print("[tp-consecration-0413] Select a sanctified machine."); return end
      local target = is_consecration_target and is_consecration_target(entity) or false
      local record = target and get_consecration_record and get_consecration_record(entity) or nil
      local progress = get_current_crafting_progress and get_current_crafting_progress(entity) or nil
      local products = get_current_products_finished and get_current_products_finished(entity) or nil
      if record then
        player.print("[tp-consecration-0413] selected=" .. tostring(entity.name) .. " sanctity=" .. tostring(record.sanctification) .. "/" .. tostring(record.max_sanctification))
        player.print("  products_finished=" .. tostring(products) .. " last_products=" .. tostring(record.last_products_finished) .. " progress=" .. tostring(progress) .. " last_progress=" .. tostring(record.last_progress))
        player.print("  completed_seen=" .. tostring(record.completed_operations_seen_0413 or 0) .. " last_decay_tick=" .. tostring(record.last_sanctification_decay_tick_0413 or "never"))
      else
        player.print("[tp-consecration-0413] selected=" .. tostring(entity.name) .. " target=" .. tostring(target) .. " products_finished=" .. tostring(products) .. " progress=" .. tostring(progress))
      end
    end)
  end)
end

if log then log("[Tech-Priests 0.1.413] assembler sanctification decay now watches products_finished; technology icons swept to in-mod Tech Priests doctrine icons") end


-- ============================================================================
-- 0.1.417 / 0.1.419: movement hammer demotion.
-- ============================================================================
-- The 0.1.416/0.1.417 hammer was useful for proving that ground priests were
-- snapping, but it also became an active behavior owner: it cleared tasks, held
-- commands, and could leave priests inert.  0.1.419 demotes it from active
-- install.  Movement sovereignty belongs to scripts.core.movement_controller.
-- The old file remains in the tree for historical diagnostics/reference only.
function TECH_PRIESTS_0417_INSTALL_MOVEMENT_HAMMER()
  if log then log("[Tech-Priests 0.1.419] legacy movement hammer not installed; movement_controller is sole ground movement authority") end
end

TECH_PRIESTS_0417_INSTALL_MOVEMENT_HAMMER()
TECH_PRIESTS_0417_INSTALL_MOVEMENT_HAMMER = nil

-- ============================================================================
-- 0.1.418: unified ground movement controller.
-- ============================================================================
function TECH_PRIESTS_0418_INSTALL_MOVEMENT_CONTROLLER()
  local movement_controller = require("scripts.core.movement_controller")
  if movement_controller and movement_controller.install then movement_controller.install() end
  if log then log("[Tech-Priests 0.1.418] unified movement controller pass loaded") end
end

TECH_PRIESTS_0418_INSTALL_MOVEMENT_CONTROLLER()
TECH_PRIESTS_0418_INSTALL_MOVEMENT_CONTROLLER = nil


-- ============================================================================
-- 0.1.419: movement sovereignty audit and task-authority diagnostics.
-- ============================================================================
function TECH_PRIESTS_0419_INSTALL_MOVEMENT_AUTHORITY_AUDIT()
  local audit = require("scripts.core.movement_authority_audit")
  if audit and audit.install then audit.install() end
  if log then log("[Tech-Priests 0.1.419] movement sovereignty audit + scheduler authority diagnostics loaded") end
end

TECH_PRIESTS_0419_INSTALL_MOVEMENT_AUTHORITY_AUDIT()
TECH_PRIESTS_0419_INSTALL_MOVEMENT_AUTHORITY_AUDIT = nil

-- ============================================================================
-- 0.1.429: combat/movement leftovers audit and route-helper confirmation.
-- ============================================================================
function TECH_PRIESTS_0429_INSTALL_COMBAT_MOVEMENT_LEFTOVERS()
  local leftovers = require("scripts.core.combat_movement_leftovers")
  if leftovers and leftovers.install then leftovers.install() end
  if log then log("[Tech-Priests 0.1.429] combat/movement leftover audit loaded") end
end

TECH_PRIESTS_0429_INSTALL_COMBAT_MOVEMENT_LEFTOVERS()
TECH_PRIESTS_0429_INSTALL_COMBAT_MOVEMENT_LEFTOVERS = nil


-- ============================================================================
-- 0.1.444: hover-selection stability and movement churn throttle.
-- ============================================================================
function TECH_PRIESTS_0444_INSTALL_HOVER_MOVEMENT_STABILITY()
  local hover_stability = require("scripts.core.hover_movement_stability")
  if hover_stability and hover_stability.install then hover_stability.install() end
  if log then log("[Tech-Priests 0.1.444] hover-selection movement stability pass loaded") end
end

TECH_PRIESTS_0444_INSTALL_HOVER_MOVEMENT_STABILITY()
TECH_PRIESTS_0444_INSTALL_HOVER_MOVEMENT_STABILITY = nil

-- ============================================================================
-- 0.1.445: task-transition cogitation governor.
-- ============================================================================
function TECH_PRIESTS_0445_INSTALL_TASK_TRANSITION_GOVERNOR()
  local governor = require("scripts.core.task_transition_governor")
  if governor and governor.install then governor.install() end
  if log then log("[Tech-Priests 0.1.445] task-transition cogitation governor loaded") end
end

TECH_PRIESTS_0445_INSTALL_TASK_TRANSITION_GOVERNOR()
TECH_PRIESTS_0445_INSTALL_TASK_TRANSITION_GOVERNOR = nil

-- ============================================================================
-- 0.1.448: stale combat status sanity pass.
-- ============================================================================
function TECH_PRIESTS_0448_INSTALL_STATUS_STATE_SANITY()
  local sanity = require("scripts.core.status_state_sanity")
  if sanity and sanity.install then sanity.install() end
  if log then log("[Tech-Priests 0.1.448] stale combat/status sanity layer loaded") end
end

TECH_PRIESTS_0448_INSTALL_STATUS_STATE_SANITY()
TECH_PRIESTS_0448_INSTALL_STATUS_STATE_SANITY = nil

-- ============================================================================
-- 0.1.422: consecration operation-history GUI.
-- ============================================================================
function TECH_PRIESTS_0422_INSTALL_CONSECRATION_HISTORY_GUI()
  local history_gui = require("scripts.core.consecration.history_gui")
  if history_gui and history_gui.install then history_gui.install() end
  if log then log("[Tech-Priests 0.1.422] consecration current/max display + machine-open history graph loaded") end
end

TECH_PRIESTS_0422_INSTALL_CONSECRATION_HISTORY_GUI()
TECH_PRIESTS_0422_INSTALL_CONSECRATION_HISTORY_GUI = nil

-- ============================================================================
-- 0.1.426: station/priest pair lifecycle extraction.
-- ============================================================================
function TECH_PRIESTS_0426_INSTALL_PAIR_LIFECYCLE()
  local lifecycle = require("scripts.core.pair_lifecycle")
  if lifecycle and lifecycle.install then lifecycle.install() end
  if log then log("[Tech-Priests 0.1.426] station/priest lifecycle extracted to pair_lifecycle modules") end
end

TECH_PRIESTS_0426_INSTALL_PAIR_LIFECYCLE()
TECH_PRIESTS_0426_INSTALL_PAIR_LIFECYCLE = nil

-- ============================================================================
-- 0.1.428: duplicate behavior family guard / deletion staging map.
-- ============================================================================
function TECH_PRIESTS_0428_INSTALL_DUPLICATE_BEHAVIOR_GUARD()
  local guard = require("scripts.core.duplicate_behavior_family_guard")
  if guard and guard.install then guard.install() end
  if log then log("[Tech-Priests 0.1.428] duplicate behavior family guard + authority map loaded") end
end

TECH_PRIESTS_0428_INSTALL_DUPLICATE_BEHAVIOR_GUARD()
TECH_PRIESTS_0428_INSTALL_DUPLICATE_BEHAVIOR_GUARD = nil

end

return M
