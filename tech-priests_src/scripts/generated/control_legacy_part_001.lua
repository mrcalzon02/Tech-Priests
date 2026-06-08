-- Auto-split control.lua fragment 001 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.

-- Tech Priests - runtime script entry point.
-- 0.1.247: crash-safe station creation diagnostics and Planetary Magos prototype restoration.
-- 0.1.30: mirror vanilla substation death explosion on scripted Cogitator collapse.

-- 0.1.440: runtime prototype compatibility shim.  Must load before any
-- legacy fragment/module can touch Factorio 1.x game.*_prototypes keys.
TechPriestsPrototypeCompat = require("scripts.core.prototype_compat")

-- 0.1.424: debug/event registration switchboards.
TechPriestsDebugCommandRegistry = require("scripts.core.debug.debug_command_registry")
TechPriestsRuntimeEventRegistry = require("scripts.core.runtime_event_registry")
TechPriestsGuiRouter = require("scripts.gui.gui_router")
if TechPriestsGuiRouter and TechPriestsGuiRouter.install then TechPriestsGuiRouter.install() end

-- 0.1.430: documented special-case movement/alignment authorities.
TechPriestsPlatformMovementAuthority = require("scripts.core.platform_movement_authority")
if TechPriestsPlatformMovementAuthority and TechPriestsPlatformMovementAuthority.install then TechPriestsPlatformMovementAuthority.install() end
TechPriestsProxyTurretAlignment = require("scripts.core.proxy_turret_alignment")
if TechPriestsProxyTurretAlignment and TechPriestsProxyTurretAlignment.install then TechPriestsProxyTurretAlignment.install() end
TechPriestsHiddenSupportAlignment = require("scripts.core.hidden_support_alignment")
if TechPriestsHiddenSupportAlignment and TechPriestsHiddenSupportAlignment.install then TechPriestsHiddenSupportAlignment.install() end

-- 0.1.425: event-switchboard runtime diagnostic command.  Registered early so
-- registry health can be queried even while later legacy command blocks remain
-- in control.lua pending extraction.
pcall(function()
  TechPriestsDebugCommandRegistry.add("tp-event-registry-0425", "Tech Priests: print runtime event/nth-tick switchboard summary.", function(command)
    local player = command and command.player_index and game.get_player(command.player_index) or nil
    if player and TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.print_summary then
      TechPriestsRuntimeEventRegistry.print_summary(player)
    elseif game then
      game.print("[Tech Priests] Event registry diagnostic requires a valid player.")
    end
  end)
end)

-- 0.1.430: special movement/alignment authority diagnostic.
pcall(function()
  TechPriestsDebugCommandRegistry.add("tp-special-movement-0430", "Tech Priests: report selected pair platform/proxy/hidden-support special movement authority state.", function(command)
    local player = command and command.player_index and game.get_player(command.player_index) or nil
    if not player then return end
    local selected = player.selected
    local pair = nil
    if selected then
      if tech_priests_pair_by_station_0206 then pair = tech_priests_pair_by_station_0206(selected) end
      if not pair and tech_priests_pair_by_priest_0206 then pair = tech_priests_pair_by_priest_0206(selected) end
      if not pair and selected.unit_number and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
        for _, p in pairs(storage.tech_priests.pairs_by_station) do
          if p and p.station and p.station.valid and p.station.unit_number == selected.unit_number then pair = p break end
          if p and p.priest and p.priest.valid and p.priest.unit_number == selected.unit_number then pair = p break end
        end
      end
    end
    if not pair then
      player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest to inspect special movement authority.")
      return
    end
    local platform = tech_priests_platform_movement_summary_0430 and tech_priests_platform_movement_summary_0430(pair) or "platform summary unavailable"
    local proxy = tech_priests_proxy_alignment_summary_0430 and tech_priests_proxy_alignment_summary_0430(pair) or "proxy summary unavailable"
    local hidden = pair.last_hidden_support_alignment_0430
    local hidden_line = hidden and ("tick=" .. tostring(hidden.tick) .. " reason=" .. tostring(hidden.reason) .. " hidden=" .. tostring(hidden.hidden) .. " anchor=" .. tostring(hidden.anchor)) or "no-hidden-support-record"
    player.print("[Tech Priests] special movement 0.1.430 :: platform={" .. platform .. "} proxy={" .. proxy .. "} hidden={" .. hidden_line .. "}")
  end)
end)


PROXY_NAME = "tech-priest-small-arms-proxy"
COGITATOR_DYING_EXPLOSION = "substation-explosion"

TIER_CONFIGS = {
  ["junior-cogitator-station"] = {
    tier = "junior",
    priest_name = "junior-tech-priest",
    immune_priest_name = "junior-tech-priest-belt-immune",
    base_radius = 25
  },
  ["intermediate-cogitator-station"] = {
    tier = "intermediate",
    priest_name = "intermediate-tech-priest",
    immune_priest_name = "intermediate-tech-priest-belt-immune",
    base_radius = 30
  },
  ["senior-cogitator-station"] = {
    tier = "senior",
    priest_name = "senior-tech-priest",
    immune_priest_name = "senior-tech-priest-belt-immune",
    base_radius = 35
  },
  ["planetary-magos-cogitator-station"] = {
    tier = "planetary-magos",
    priest_name = "planetary-magos-tech-priest",
    immune_priest_name = "planetary-magos-tech-priest-belt-immune",
    base_radius = 35
  },
  ["void-cogitator-station"] = {
    tier = "void",
    priest_name = "void-tech-priest",
    immune_priest_name = "void-tech-priest-belt-immune",
    base_radius = 41
  }
}

PRIEST_TO_STATION = {
  ["junior-tech-priest"] = "junior-cogitator-station",
  ["intermediate-tech-priest"] = "intermediate-cogitator-station",
  ["senior-tech-priest"] = "senior-cogitator-station",
  ["planetary-magos-tech-priest"] = "planetary-magos-cogitator-station",
  ["void-tech-priest"] = "void-cogitator-station",
  ["junior-tech-priest-belt-immune"] = "junior-cogitator-station",
  ["intermediate-tech-priest-belt-immune"] = "intermediate-cogitator-station",
  ["senior-tech-priest-belt-immune"] = "senior-cogitator-station",
  ["planetary-magos-tech-priest-belt-immune"] = "planetary-magos-cogitator-station",
  ["void-tech-priest-belt-immune"] = "void-cogitator-station"
}

TECH_PRIEST_BELT_IMMUNITY_TECH = "tech-priest-rite-of-kinetic-exemption"
COGITATOR_LOGISTIC_REQUISITION_TECH = "cogitator-logistic-requisition"

RANGE_TECH_BONUSES = {
  ["cogitator-operating-radius-1"] = 1,
  ["cogitator-operating-radius-2"] = 2,
  ["cogitator-operating-radius-3"] = 2,
  ["planetary-magos-command-range-1"] = 2,
  ["planetary-magos-command-range-2"] = 2,
  ["planetary-magos-command-range-3"] = 4,
  ["planetary-magos-command-range-4"] = 4
}

STARTING_SANCTIFICATION_TECH_BONUSES = {
  ["machine-spirit-initial-consecration-1"] = 20,
  ["machine-spirit-initial-consecration-2"] = 20
}

MAX_SANCTIFICATION_TECH_BONUSES = {
  ["machine-spirit-capacity-1"] = 10,
  ["machine-spirit-capacity-2"] = 10
}

SANCTIFICATION_START_TECHS = {
  "machine-spirit-initial-consecration-1",
  "machine-spirit-initial-consecration-2"
}

SANCTIFICATION_MAX_TECHS = {
  "machine-spirit-capacity-1",
  "machine-spirit-capacity-2"
}

-- Standard quality levels use level values that top out at 5 for legendary.
-- We use that level directly as the station operating-radius bonus, clamped
-- to +5 so a legendary station adds exactly another five tiles.
MAX_QUALITY_RADIUS_BONUS = 5

REPAIR_AMOUNT_PER_PACK = 75
HEALTH_LINK_EPSILON = 0.002
COMBAT_FIRE_RANGE = 15
COMBAT_APPROACH_RADIUS = 11
TECH_PRIESTS_POINT_BLANK_LASER_RANGE = 1.5
TECH_PRIESTS_POINT_BLANK_LASER_RANGE_SQ = TECH_PRIESTS_POINT_BLANK_LASER_RANGE * TECH_PRIESTS_POINT_BLANK_LASER_RANGE
PROXY_KEEPALIVE_TICKS = 120
RADIUS_RENDER_TTL = 40
RADIUS_RENDER_REFRESH_TICKS = 15
LINK_RENDER_TTL = 40
LINK_RENDER_REFRESH_TICKS = 15
PRIEST_SANITY_RECALL_TICKS = 60 * 120
PRIEST_LOST_RANGE_PADDING = 8
PRIEST_DEPLOYMENT_QUEUE_PROCESS_LIMIT = 3
DEPLOYMENT_OFFSET_DISTANCE = 2.75
COMBAT_DEBUG = false
COMBAT_DEBUG_COOLDOWN = 60

LOGISTIC_REQUISITION_INTERVAL_TICKS = 180
LOGISTIC_REQUISITION_REPAIR_TARGET_STOCK = 3
LOGISTIC_REQUISITION_CONSECRATION_TARGET_STOCK = 3
LOGISTIC_REQUISITION_AMMO_TARGET_STOCK = 20
LOGISTIC_REQUISITION_AMMO_BATCH_SIZE = 10
LOGISTIC_FRUSTRATION_THRESHOLD_TICKS = 60 * 10
LOGISTIC_SCAVENGE_RETRY_TICKS = 60 * 5
LOGISTIC_SCAVENGE_PICKUP_DISTANCE_SQ = 4
LOGISTIC_SCAVENGE_ITEM_BATCH_SIZE = 10
LOGISTIC_CRAM_SEARCH_BEFORE_DUMP_TICKS = 60 * 10
LOGISTIC_REQUESTER_CACHE_NAME = "tech-priests-cogitator-requester-cache"
LOGISTIC_RETURN_CACHE_NAME = "tech-priests-cogitator-return-cache"
LOGISTIC_REQUESTER_SLOT_COUNT = 6
LOGISTIC_RETURN_EJECT_BATCH_SIZE = 50

VOID_FUSION_THRUSTER_NAME = "void-fusion-thruster"
LARGE_VOID_FUSION_THRUSTER_NAME = "large-void-fusion-thruster"
VOID_FUSION_THRUSTER_POWER_SINK_NAME = "void-fusion-thruster-power-sink"
VOID_FUSION_THRUSTER_CHARGE_FLUID = "void-fusion-thruster-charge"
VOID_FUSION_THRUSTER_REACTION_FLUID = "void-fusion-thruster-reaction-mass"
VOID_FUSION_THRUSTER_MIN_BUFFER = 250000
VOID_FUSION_THRUSTER_FILL_AMOUNT = 100


FOOTSTEP_SOUND_PATH = "tech-priest-metal-footstep"
FOOTSTEP_INTERVAL_TICKS = 22
FOOTSTEP_MIN_MOVEMENT_SQ = 0.12

CONSECRATION_TARGET_NAME = "assembling-machine-1"
CONSECRATION_TARGET_NAME_LIST = {
  "assembling-machine-1",
  "assembling-machine-2",
  "assembling-machine-3",
  "oil-refinery",
  "chemical-plant",
  "centrifuge",
  "electromagnetic-plant",
  "cryogenic-plant",
  "boiler",
  "steam-engine",
  "nuclear-reactor",
  "steam-turbine",
  "roboport",
  "car",
  "tank",
  "spidertron",
  "locomotive"
}
CONSECRATION_TARGET_NAME_SET = {}
for _, tech_priests_consecration_target_name in pairs(CONSECRATION_TARGET_NAME_LIST) do
  CONSECRATION_TARGET_NAME_SET[tech_priests_consecration_target_name] = true
end

-- 0.1.446: the consecration system must not depend only on a short vanilla
-- name list.  Modded workstations, Space Age machines, furnaces, labs,
-- boilers/generators, reactors, roboports, and vehicles should be eligible for
-- machine-spirit tracking when they have a unit_number.  Name-list matching is
-- retained above for historical/precise compatibility; this type list is the
-- broad forward-facing tracker used by the registry scan and on-built checks.
CONSECRATION_TARGET_TYPE_LIST = {
  "assembling-machine",
  "furnace",
  "rocket-silo",
  "lab",
  "mining-drill",
  "boiler",
  "generator",
  "reactor",
  "roboport",
  "car",
  "spider-vehicle",
  "locomotive"
}
CONSECRATION_TARGET_TYPE_SET = {}
for _, tech_priests_consecration_target_type in pairs(CONSECRATION_TARGET_TYPE_LIST) do
  CONSECRATION_TARGET_TYPE_SET[tech_priests_consecration_target_type] = true
end
SACRED_OIL_NAME = "sacred-machine-oil"
STARTING_BONUS_STATION_NAME = "senior-cogitator-station"
STARTING_BONUS_MULTIPLAYER_REPAIR_PACKS = 25
STARTING_BONUS_MULTIPLAYER_SACRED_OIL = 25
STARTING_BONUS_AMMO_CANDIDATES = {
  "firearm-magazine",
  "piercing-rounds-magazine",
  "uranium-rounds-magazine",
  "bob-bullet-magazine",
  "bullet-magazine",
  "basic-bullet-magazine"
}

TECH_PRIESTS_EMERGENCY_MICRO_INDUSTRY_RECIPES = {
  "tech-priests-emergency-miner",
  "tech-priests-emergency-boiler",
  "tech-priests-atmospheric-water-condenser",
  "tech-priests-emergency-steam-engine",
  "tech-priests-emergency-assembler",
  "tech-priests-emergency-laboratorium",
  "tech-priests-emergency-power-grid"
}
TECH_PRIESTS_EMERGENCY_PLANETSIDE_ENTITIES = {
  ["tech-priests-emergency-miner"] = true,
  ["tech-priests-emergency-boiler"] = true,
  ["tech-priests-atmospheric-water-condenser"] = true,
  ["tech-priests-emergency-steam-engine"] = true,
  ["tech-priests-emergency-assembler"] = true,
  ["tech-priests-emergency-laboratorium"] = true,
  ["tech-priests-emergency-power-grid"] = true
}
TECH_PRIESTS_EMERGENCY_MINER_NAME = "tech-priests-emergency-miner"
TECH_PRIESTS_EMERGENCY_QUARRY_INTERVAL_TICKS = 60 * 180
TECH_PRIESTS_EMERGENCY_QUARRY_MODE_AUTO = "auto"
TECH_PRIESTS_EMERGENCY_QUARRY_MODE_PATCH = "patch"
TECH_PRIESTS_EMERGENCY_QUARRY_MODE_QUARRY = "quarry"

MACHINE_MAINTENANCE_LITANY_NAME = "machine-maintenance-litany"
RITUAL_OF_MACHINE_APPEASEMENT_NAME = "ritual-of-machine-appeasement"
SACRED_INCENSE_GRENADE_NAME = "sacred-incense-grenade"
SACRED_INCENSE_IMPACT_EFFECT_ID = "tech-priests-sacred-incense-impact"
DEFAULT_BASE_SANCTIFICATION_MAX = 100
DEFAULT_BASE_SANCTIFICATION_START = 50
DEFAULT_SACRED_OIL_RESTORE_AMOUNT = 1
DEFAULT_MIN_SANCTIFICATION_DECAY_PER_OPERATION = 3
DEFAULT_MAX_SANCTIFICATION_DECAY_PER_OPERATION = 10
DEFAULT_SANCTIFICATION_DECAY_RANDOM_JITTER_PERCENT = 35
DEFAULT_SHOW_SANCTIFICATION_DECAY_FLOATERS = true
DEFAULT_SANCTIFICATION_DECAY_FLOATER_MIN_AMOUNT = 0.25
SANCTIFICATION_RENDER_TTL = 180
SANCTIFICATION_OVERLAY_REFRESH_TICKS = 120
SANCTIFICATION_OVERLAY_BUCKETS = 12
SANCTIFICATION_GRIME_OVERLAY_SPRITE = "tech-priests-sanctification-grime-overlay"
SANCTIFICATION_SHEEN_OVERLAY_SPRITE = "tech-priests-sanctification-sheen-overlay"
SANCTIFICATION_VEHICLE_SLIME_OVERLAY_SPRITE = "tech-priests-sanctification-vehicle-slime-overlay"
SANCTIFICATION_VEHICLE_GLOW_OVERLAY_SPRITE = "tech-priests-sanctification-vehicle-glow-overlay"
SANCTIFICATION_OVERLAY_SCALE = 1.18

SANCTIFICATION_VEHICLE_OVERLAY_NAMES = {
  car = true,
  tank = true,
  spidertron = true,
  locomotive = true
}

SANCTIFICATION_MACHINE_SPECIFIC_OVERLAY_NAMES = {
  "assembling-machine-1",
  "assembling-machine-2",
  "assembling-machine-3",
  "oil-refinery",
  "chemical-plant",
  "centrifuge",
  "electromagnetic-plant",
  "cryogenic-plant",
  "boiler",
  "steam-engine",
  "nuclear-reactor",
  "steam-turbine",
  "roboport"
}

SANCTIFICATION_MACHINE_OVERLAY_SPRITES = {}
for _, tech_priests_overlay_machine_name in pairs(SANCTIFICATION_MACHINE_SPECIFIC_OVERLAY_NAMES) do
  SANCTIFICATION_MACHINE_OVERLAY_SPRITES[tech_priests_overlay_machine_name] = {
    grime = "tech-priests-sanctification-grime-" .. tech_priests_overlay_machine_name,
    sheen = "tech-priests-sanctification-sheen-" .. tech_priests_overlay_machine_name
  }
end
SANCTIFICATION_GRIME_PATCH_BASE_SCALE = 0.66
SANCTIFICATION_GRIME_PATCH_COUNT_MAX = 12
SANCTIFICATION_BAR_WIDTH = 1.85
SANCTIFICATION_BAR_HEIGHT = 0.16
SANCTIFICATION_BAR_Y_OFFSET = -2.58
MINIMUM_SANCTIFICATION_EFFICIENCY = 0.05
DEFAULT_MINIMUM_SANCTIFICATION_VALUE_FRACTION = 0.05
SANCTIFICATION_THROTTLE_CYCLE_TICKS = 200
MECHANICAL_DETRITUS_NAME = "mechanical-detritus"
LOW_SANCTIFICATION_EXTRA_POLLUTION_PER_SECOND = 1.0
LOW_SANCTIFICATION_FUEL_LOSS_RATIO = 0.25
LOW_SANCTIFICATION_FUEL_LOSS_MAX_CHANCE = 0.45
LOW_SANCTIFICATION_OPERATOR_EJECT_RATIO = 0.15
LOW_SANCTIFICATION_CONTROL_MALFUNCTION_RATIO = 0.25
LOW_SANCTIFICATION_CONTROL_FLOOR_RATIO = 0.05
LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MAX_CHANCE = 0.18
LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MIN_TICKS = 60
LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MAX_TICKS = 120
VEHICLE_SANCTIFICATION_DISTANCE_OPERATION_TILES = 5.0
PRIEST_CONSECRATION_AMOUNT_PER_OIL = 1
MACHINE_MAINTENANCE_LITANY_RESTORE_AMOUNT = 10
RITUAL_OF_MACHINE_APPEASEMENT_RESTORE_AMOUNT = 20
SACRED_INCENSE_GRENADE_RESTORE_AMOUNT = 5
SACRED_INCENSE_GRENADE_RADIUS = 7
SACRED_INCENSE_CLOUD_VISUAL_PULSE_INTERVAL = 600
SACRED_INCENSE_CLOUD_MAX_VISUAL_PULSES = 1
SACRED_INCENSE_CLOUD_TICK_RESTORE_AMOUNT = 1
SACRED_INCENSE_CLOUD_DURATION_SECONDS = 20
SACRED_INCENSE_CLOUD_DURATION_TICKS = SACRED_INCENSE_CLOUD_DURATION_SECONDS * 60
SACRED_INCENSE_CLOUD_TICK_INTERVAL = 60
SACRED_INCENSE_CLOUD_ENTITY_NAME = "sacred-incense-cloud"
SACRED_INCENSE_CLOUD_SOFT_ENTITY_NAME = "sacred-incense-cloud-soft"
SACRED_INCENSE_CLOUD_FAINT_ENTITY_NAME = "sacred-incense-cloud-faint"
PRIEST_CONSECRATION_COOLDOWN_TICKS = 30
PRIEST_CONSECRATION_REACH_DISTANCE_SQ = 16
DEFAULT_SANCTIFICATION_DAMAGE_THRESHOLD = 35
DEFAULT_SANCTIFICATION_DAMAGE_MAX_CHANCE_PERCENT = 65
DEFAULT_SANCTIFICATION_DAMAGE_MIN_FRACTION_PERCENT = 0.2
DEFAULT_SANCTIFICATION_DAMAGE_MAX_FRACTION_PERCENT = 2.5
DEFAULT_SANCTIFICATION_MAX_DEGRADE_THRESHOLD = 50
DEFAULT_SANCTIFICATION_MAX_DEGRADE_MAX_CHANCE_PERCENT = 14
DEFAULT_SANCTIFICATION_MAX_DEGRADE_MIN_AMOUNT = 14
DEFAULT_SANCTIFICATION_MAX_DEGRADE_MAX_AMOUNT = 19
MACHINE_DAMAGE_SMOKE_ENTITY_NAME = "tech-priests-machine-damage-smoke"
MACHINE_DAMAGE_SMOKE_CLOUD_NAME = "tech-priests-machine-damage-smoke-cloud"
PRIEST_TRANSLOCATION_SMOKE_ENTITY_NAME = "tech-priests-priest-translocation-smoke"
PRIEST_STATUS_BUBBLE_UPDATE_TICKS = 30
DEFAULT_PRIEST_STATUS_BUBBLE_INTERVAL_TICKS = 180
DEFAULT_PRIEST_STATUS_BUBBLE_DURATION_TICKS = 90
DEFAULT_MIN_DEGRADED_SANCTIFICATION_MAX = 25
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: register_consecration_target
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: remove_consecration_target
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: is_consecration_target
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: draw_sanctification_label
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: get_consecration_record
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: normalise_consecration_record
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: get_current_crafting_progress
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: machine_has_waste_room
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: update_waste_jam_state
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: find_consecration_target_for_station
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: sanctify_target_with_priest
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: clear_machine_custom_status
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: find_priest_service_position
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: update_sanctification_overlay
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: clear_sanctification_overlay
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: find_pair_for_entity
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: create_pair
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: ensure_pair_priest
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: respawn_pair_priest
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: enqueue_priest_deployment
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: process_priest_deployment_queue


function read_global_double_setting(name, fallback)
  if settings and settings.global and settings.global[name] and settings.global[name].value ~= nil then
    local value = tonumber(settings.global[name].value)
    if value then return value end
  end
  return fallback
end

function read_global_bool_setting(name, fallback)
  if _G and _G.tech_priests_runtime_setting_bool_0626 then
    local ok, value = pcall(_G.tech_priests_runtime_setting_bool_0626, name, fallback)
    if ok then return value == true end
  end
  if settings and settings.global and settings.global[name] and settings.global[name].value ~= nil then
    return settings.global[name].value == true
  end
  return fallback
end

function read_global_string_setting(name, fallback)
  if _G and _G.TechPriestsRuntimeConfig0626 and _G.TechPriestsRuntimeConfig0626.setting_string then
    local ok, value = pcall(_G.TechPriestsRuntimeConfig0626.setting_string, name, fallback)
    if ok and value ~= nil then return value end
  end
  if settings and settings.global and settings.global[name] and settings.global[name].value ~= nil then
    local value = tostring(settings.global[name].value or "")
    if value ~= "" then return value end
  end
  return fallback
end

function get_base_sanctification_max(force)
  local setting_base = math.max(1, read_global_double_setting("tech-priests-base-max-sanctification", DEFAULT_BASE_SANCTIFICATION_MAX))
  return setting_base + get_force_technology_bonus(force, MAX_SANCTIFICATION_TECH_BONUSES)
end

function get_base_sanctification_start(force)
  local setting_start = math.max(0, read_global_double_setting("tech-priests-starting-sanctification", DEFAULT_BASE_SANCTIFICATION_START))
  local researched_start = setting_start + get_force_technology_bonus(force, STARTING_SANCTIFICATION_TECH_BONUSES)
  return math.max(0, math.min(get_base_sanctification_max(force), researched_start))
end

function get_minimum_sanctification_value_fraction()
  local percent = read_global_double_setting("tech-priests-minimum-sanctification-percent", DEFAULT_MINIMUM_SANCTIFICATION_VALUE_FRACTION * 100)
  return math.max(0, math.min(1, percent / 100))
end

function get_min_degraded_sanctification_max()
  return math.max(1, math.min(get_base_sanctification_max(), read_global_double_setting("tech-priests-min-degraded-max-sanctification", DEFAULT_MIN_DEGRADED_SANCTIFICATION_MAX)))
end

function get_sacred_oil_restore_amount()
  return math.max(0, read_global_double_setting("tech-priests-sacred-oil-restore-amount", DEFAULT_SACRED_OIL_RESTORE_AMOUNT))
end

function get_sanctification_decay_min_max()
  local min_decay = math.max(0, read_global_double_setting("tech-priests-min-sanctification-decay-per-operation", DEFAULT_MIN_SANCTIFICATION_DECAY_PER_OPERATION))
  local max_decay = math.max(0, read_global_double_setting("tech-priests-max-sanctification-decay-per-operation", DEFAULT_MAX_SANCTIFICATION_DECAY_PER_OPERATION))
  if max_decay < min_decay then
    min_decay, max_decay = max_decay, min_decay
  end
  return min_decay, max_decay
end

function get_sanctification_decay_random_jitter_fraction()
  local percent = read_global_double_setting("tech-priests-sanctification-decay-random-jitter-percent", DEFAULT_SANCTIFICATION_DECAY_RANDOM_JITTER_PERCENT)
  return math.max(0, percent / 100)
end

function get_show_sanctification_decay_floaters()
  return read_global_bool_setting("tech-priests-show-sanctification-decay-floaters", DEFAULT_SHOW_SANCTIFICATION_DECAY_FLOATERS)
end

function get_sanctification_decay_floater_min_amount()
  return math.max(0, read_global_double_setting("tech-priests-sanctification-decay-floater-min-amount", DEFAULT_SANCTIFICATION_DECAY_FLOATER_MIN_AMOUNT))
end

function get_physical_damage_config()
  local threshold = math.max(0, read_global_double_setting("tech-priests-physical-damage-threshold", DEFAULT_SANCTIFICATION_DAMAGE_THRESHOLD))
  local max_chance = math.max(0, math.min(1, read_global_double_setting("tech-priests-physical-damage-max-chance-percent", DEFAULT_SANCTIFICATION_DAMAGE_MAX_CHANCE_PERCENT) / 100))
  local min_fraction = math.max(0, read_global_double_setting("tech-priests-physical-damage-min-health-percent", DEFAULT_SANCTIFICATION_DAMAGE_MIN_FRACTION_PERCENT) / 100)
  local max_fraction = math.max(0, read_global_double_setting("tech-priests-physical-damage-max-health-percent", DEFAULT_SANCTIFICATION_DAMAGE_MAX_FRACTION_PERCENT) / 100)
  if max_fraction < min_fraction then
    min_fraction, max_fraction = max_fraction, min_fraction
  end
  return threshold, max_chance, min_fraction, max_fraction
end

function get_max_sanctification_degradation_config()
  local threshold = math.max(0, read_global_double_setting("tech-priests-max-sanctification-damage-threshold", DEFAULT_SANCTIFICATION_MAX_DEGRADE_THRESHOLD))
  local max_chance = math.max(0, math.min(1, read_global_double_setting("tech-priests-max-sanctification-damage-max-chance-percent", DEFAULT_SANCTIFICATION_MAX_DEGRADE_MAX_CHANCE_PERCENT) / 100))
  local min_amount = math.max(0, read_global_double_setting("tech-priests-max-sanctification-damage-min-amount", DEFAULT_SANCTIFICATION_MAX_DEGRADE_MIN_AMOUNT))
  local max_amount = math.max(0, read_global_double_setting("tech-priests-max-sanctification-damage-max-amount", DEFAULT_SANCTIFICATION_MAX_DEGRADE_MAX_AMOUNT))
  if max_amount < min_amount then
    min_amount, max_amount = max_amount, min_amount
  end
  return threshold, max_chance, min_amount, max_amount
end

function get_current_consecration_config_snapshot(force)
  local min_decay, max_decay = get_sanctification_decay_min_max()
  return {
    base_max = get_base_sanctification_max(force),
    base_start = get_base_sanctification_start(force),
    min_fraction = get_minimum_sanctification_value_fraction(),
    min_degraded_max = get_min_degraded_sanctification_max(),
    oil_restore = get_sacred_oil_restore_amount(),
    min_decay = min_decay,
    max_decay = max_decay,
    decay_jitter_fraction = get_sanctification_decay_random_jitter_fraction(),
    decay_floaters = get_show_sanctification_decay_floaters(),
    decay_floater_min_amount = get_sanctification_decay_floater_min_amount(),
    physical_damage_threshold = select(1, get_physical_damage_config()),
    physical_damage_max_chance = select(2, get_physical_damage_config()),
    max_sanctification_damage_threshold = select(1, get_max_sanctification_degradation_config()),
    max_sanctification_damage_max_chance = select(2, get_max_sanctification_degradation_config())
  }
end

function ensure_storage()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.pairs_by_station = storage.tech_priests.pairs_by_station or {}
  storage.tech_priests.station_by_priest = storage.tech_priests.station_by_priest or {}
  storage.tech_priests.busy = storage.tech_priests.busy or false
  storage.tech_priests.deployment_queue = storage.tech_priests.deployment_queue or {}
  storage.tech_priests.deployment_queue_set = storage.tech_priests.deployment_queue_set or {}
  storage.tech_priests.deployment_queue_force = storage.tech_priests.deployment_queue_force or {}
  storage.tech_priests.radius_rendering_by_player = storage.tech_priests.radius_rendering_by_player or {}
  storage.tech_priests.used_cell_names = storage.tech_priests.used_cell_names or {}
  storage.tech_priests.consecration = storage.tech_priests.consecration or {}
  storage.tech_priests.consecration.machines = storage.tech_priests.consecration.machines or {}
  storage.tech_priests.consecration.renders = storage.tech_priests.consecration.renders or {}
  storage.tech_priests.consecration.overlays = storage.tech_priests.consecration.overlays or {}
  storage.tech_priests.consecration.last_config = storage.tech_priests.consecration.last_config or get_current_consecration_config_snapshot()
  storage.tech_priests.active_incense_clouds = storage.tech_priests.active_incense_clouds or {}
  storage.tech_priests.priest_bubbles = storage.tech_priests.priest_bubbles or {}
  storage.tech_priests.void_fusion_thrusters = storage.tech_priests.void_fusion_thrusters or {}
  storage.tech_priests.starting_bonus_granted_by_player_index = storage.tech_priests.starting_bonus_granted_by_player_index or {}
end

function is_station(entity)
  return entity and entity.valid and TIER_CONFIGS[entity.name] ~= nil
end

function is_priest(entity)
  return entity and entity.valid and PRIEST_TO_STATION[entity.name] ~= nil
end

function get_station_config(station_or_name)
  local name = type(station_or_name) == "string" and station_or_name or (station_or_name and station_or_name.valid and station_or_name.name)
  if not name then return nil end
  return TIER_CONFIGS[name]
end

function force_has_priest_belt_immunity(force)
  if not (force and force.valid and force.technologies) then return false end
  local tech = force.technologies[TECH_PRIEST_BELT_IMMUNITY_TECH]
  return tech and tech.researched or false
end

function get_priest_name_for_force(config, force)
  if not config then return nil end
  if force_has_priest_belt_immunity(force) and config.immune_priest_name then
    return config.immune_priest_name
  end
  return config.priest_name
end

function get_force_range_bonus(force)
  if not force then return 0 end
  local bonus = 0
  for tech_name, amount in pairs(RANGE_TECH_BONUSES) do
    local tech = force.technologies and force.technologies[tech_name]
    if tech and tech.researched then
      bonus = bonus + amount
    end
  end
  return bonus
end

function get_force_technology_bonus(force, bonus_table)
  if not (force and force.valid and force.technologies) then return 0 end
  local bonus = 0
  for tech_name, amount in pairs(bonus_table or {}) do
    local tech = force.technologies[tech_name]
    if tech and tech.researched then
      bonus = bonus + amount
    end
  end
  return bonus
end

function is_sanctification_baseline_technology(name)
  return STARTING_SANCTIFICATION_TECH_BONUSES[name] ~= nil or MAX_SANCTIFICATION_TECH_BONUSES[name] ~= nil
end

function get_entity_quality(entity)
  if not (entity and entity.valid) then return nil end
  local ok, quality = pcall(function() return entity.quality end)
  if ok and quality then return quality end
  return nil
end

function get_entity_quality_name(entity)
  local quality = get_entity_quality(entity)
  if quality and quality.valid and quality.name then
    return quality.name
  end
  return "normal"
end

function get_stack_quality_name(stack)
  if not (stack and stack.valid_for_read) then return "normal" end

  local ok, quality = pcall(function() return stack.quality end)
  if ok and quality and quality.valid and quality.name then
    return quality.name
  end

  return "normal"
end

function make_item_stack_identification(name, count, quality_name)
  local stack = { name = name, count = count or 1 }
  if quality_name and quality_name ~= "normal" then
    stack.quality = quality_name
  end
  return stack
end

function get_item_stack_size(name)
  if not name then return 1 end
  local prototype = get_item_prototype(name)
  if prototype and prototype.stack_size then
    return math.max(1, prototype.stack_size)
  end
  return 50
end

function get_insertable_item_count(inventory, item_name, desired_count, quality_name)
  if not (inventory and item_name and desired_count and desired_count > 0) then return 0 end
  local low = 0
  local high = math.max(1, desired_count)
  while low < high do
    local mid = math.ceil((low + high + 1) / 2)
    if inventory.can_insert(make_item_stack_identification(item_name, mid, quality_name)) then
      low = mid
    else
      high = mid - 1
    end
  end
  return low
end

function get_quality_radius_bonus(entity)
  local quality = get_entity_quality(entity)
  if not (quality and quality.valid and quality.level) then return 0 end
  return math.max(0, math.min(MAX_QUALITY_RADIUS_BONUS, quality.level))
end

function get_station_operating_radius(station)
  local config = get_station_config(station)
  if not config then return 20 end
  return config.base_radius + get_force_range_bonus(station.force) + get_quality_radius_bonus(station)
end

function refresh_pair_radius(pair)
  if not (pair and pair.station and pair.station.valid) then return 20 end
  pair.radius = get_station_operating_radius(pair.station)
  return pair.radius
end


function get_random_supporter_name()
  -- Factorio exposes the same early-backer/supporter name list used by
  -- train stops, labs, locomotives, radars, and roboports as game.backer_names.
  if not (game and game.backer_names) then return nil end

  local count = 0
  pcall(function() count = #game.backer_names end)
  if count and count > 0 then
    local ok, name = pcall(function() return game.backer_names[math.random(1, count)] end)
    if ok and name and name ~= "" then return name end
  end

  -- LuaCustomTable implementations are not always friendly to # in every
  -- context, so keep a small pairs() fallback.
  local sampled = nil
  local seen = 0
  pcall(function()
    for _, name in pairs(game.backer_names) do
      if name and name ~= "" then
        seen = seen + 1
        if math.random(seen) == 1 then sampled = name end
      end
    end
  end)
  return sampled
end

function generate_cell_name()
  ensure_storage()
  local name = get_random_supporter_name()
  if not name or name == "" then
    name = "Adept-" .. tostring(game.tick % 100000)
  end

  -- Avoid obvious duplicates inside one save when possible. If the backer-name
  -- list repeats or the random draw collides, add a little Administratum suffix.
  local base = name
  local suffix = 1
  while storage.tech_priests.used_cell_names[name] do
    suffix = suffix + 1
    name = base .. "-" .. tostring(suffix)
    if suffix > 20 then break end
  end
  storage.tech_priests.used_cell_names[name] = true
  return name
end

function get_pair_display_name(pair)
  if not pair then return "Uncatalogued Cell" end
  ensure_storage()
  if not pair.cell_name then
    pair.cell_name = generate_cell_name()
  else
    storage.tech_priests.used_cell_names[pair.cell_name] = true
  end
  return pair.cell_name
end

function apply_pair_display_names(pair)
  if not pair then return end
  local cell_name = get_pair_display_name(pair)
  if not pair.station_display_name or string.find(pair.station_display_name, "Cogitator Cell", 1, true) == 1 then
    pair.station_display_name = "Cogitator Station " .. cell_name
  end
  pair.priest_display_name = pair.priest_display_name or ("Tech-Priest " .. cell_name)

  -- Only a few vanilla entity classes truly support backer_name. Containers
  -- and units generally do not, so this is a harmless best-effort write.
  if pair.station and pair.station.valid then
    pcall(function() pair.station.backer_name = pair.station_display_name end)
  end
  if pair.priest and pair.priest.valid then
    pcall(function() pair.priest.backer_name = pair.priest_display_name end)
  end
end

function get_station_inventory(station)
  if not (station and station.valid) then return nil end
  return station.get_inventory(defines.inventory.chest)
end

function get_item_prototype(item_name)
  if not item_name then return nil end

  if tech_priests_get_item_prototype_0440 then
    return tech_priests_get_item_prototype_0440(item_name)
  end
  return nil
end


function get_entity_prototype_safe(name)
  if not name then return nil end
  if tech_priests_get_entity_prototype_0440 then
    return tech_priests_get_entity_prototype_0440(name)
  end
  return nil
end

function iter_entity_prototypes_safe()
  if tech_priests_prototype_table_0440 then
    return tech_priests_prototype_table_0440("entity") or {}
  end
  return {}
end

function get_recipe_prototype_safe(name)
  if not name then return nil end
  if tech_priests_get_recipe_prototype_0440 then
    return tech_priests_get_recipe_prototype_0440(name)
  end
  return nil
end

function combat_debug(pair, message)
  if not COMBAT_DEBUG then return end
  if not (pair and pair.station and pair.station.valid) then return end
  if game.tick < (pair.next_combat_debug_tick or 0) then return end
  pair.next_combat_debug_tick = game.tick + COMBAT_DEBUG_COOLDOWN
  pair.station.force.print("[Tech Priests combat] " .. message)
end


function tech_priests_0309_rendering_method(name)
  if not rendering then return nil end
  local ok, method = pcall(function() return rendering[name] end)
  if ok and type(method) == "function" then return method end
  return nil
end

function tech_priests_0309_destroy_render_object(object)
  if not object then return end
  local ok_valid, valid = pcall(function() return object.valid end)
  if ok_valid and valid then
    pcall(function() object.destroy() end)
    return
  end
  local destroy = tech_priests_0309_rendering_method("destroy")
  if destroy then
    pcall(function() destroy(object) end)
  end
end

function tech_priests_0309_clear_rendering(mod_name)
  local clear = tech_priests_0309_rendering_method("clear")
  if clear then
    pcall(function() clear(mod_name or "tech-priests") end)
  end
end

function destroy_render_object(object)
  tech_priests_0309_destroy_render_object(object)
end

function destroy_render_objects(objects)
  if not objects then return end
  if type(objects) == "table" then
    if objects.objects then
      for _, object in pairs(objects.objects) do
        destroy_render_object(object)
      end
    elseif objects.object then
      destroy_render_object(objects.object)
    else
      for _, object in pairs(objects) do
        destroy_render_objects(object)
      end
    end
  else
    destroy_render_object(objects)
  end
end

function clear_all_runtime_rendering()
  -- Clears legacy/stacked render objects from older overlay experiments. This
  -- intentionally clears all rendering objects created by this mod, then the
  -- normal hover/overlay systems recreate only the current valid objects.
  tech_priests_0309_clear_rendering("tech-priests")
  if storage and storage.tech_priests then
    storage.tech_priests.radius_rendering_by_player = {}
    if storage.tech_priests.consecration then
      storage.tech_priests.consecration.renders = {}
      storage.tech_priests.consecration.overlays = {}
    end
    storage.tech_priests.priest_bubbles = {}
  end
end

function clear_radius_rendering(player_index)
  ensure_storage()
  local object = storage.tech_priests.radius_rendering_by_player[player_index]
  if object then
    destroy_render_object(object)
    storage.tech_priests.radius_rendering_by_player[player_index] = nil
  end
end

-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: get_station_deployment_vector
-- forward declaration moved to global scope to avoid Lua 200-local main-chunk limit: get_station_deployment_position

function classify_priest_visual_state(pair)
  if not pair then return "idle" end
  local mode = pair.mode or "idle"
  if mode == "defending" or mode == "moving-to-combat" then return "combat" end
  if mode == "repairing" or mode == "moving-to-repair" then return "repair" end
  if mode == "repair-waiting-usefulness" then return "repair-waiting" end
  if mode == "missing-repair-supplies" then return "repair-missing-supplies" end
  if mode == "consecrating" or mode == "moving-to-consecrate" then return "consecrate" end
  if mode == "consecrate-waiting-usefulness" then return "consecrate-waiting" end
  if mode == "missing-consecration-supplies" then return "consecrate-missing-supplies" end
  if mode == "missing-ammo-supplies" then return "ammo-missing-supplies" end
  if mode == "awaiting-logistics" then return "awaiting-logistics" end
  if mode == "logistics-requested" then return "logistics-requested" end
  if mode == "logistics-scavenge-countdown" then return "logistics-scavenge-countdown" end
  if mode == "logistics-clearing-space" then return "logistics-clearing-space" end
  if mode == "logistics-cram-countdown" then return "logistics-cram-countdown" end
  if mode == "logistics-no-network" then return "logistics-no-network" end
  if mode == "scavenging-supplies" or mode == "moving-to-scavenge" then return "scavenging-supplies" end
  if mode == "cramming-supplies" or mode == "moving-to-cram" then return "cramming-supplies" end
  if mode == "deploying" then return "deploy" end
  if mode == "returning" then return "returning" end
  return "idle"
end

function get_priest_status_setting_name(state)
  if state == "combat" then return "tech-priests-priest-status-symbol-combat" end
  if state == "repair" then return "tech-priests-priest-status-symbol-repair" end
  if state == "repair-waiting" then return "tech-priests-priest-status-symbol-repair-waiting" end
  if state == "repair-missing-supplies" then return "tech-priests-priest-status-symbol-repair-missing-supplies" end
  if state == "consecrate" then return "tech-priests-priest-status-symbol-consecrate" end
  if state == "consecrate-waiting" then return "tech-priests-priest-status-symbol-consecrate-waiting" end
  if state == "consecrate-missing-supplies" then return "tech-priests-priest-status-symbol-consecrate-missing-supplies" end
  if state == "ammo-missing-supplies" then return "tech-priests-priest-status-symbol-ammo-missing-supplies" end
  if state == "awaiting-logistics" then return "tech-priests-priest-status-symbol-awaiting-logistics" end
  if state == "logistics-requested" then return "tech-priests-priest-status-symbol-logistics-requested" end
  if state == "logistics-scavenge-countdown" then return "tech-priests-priest-status-symbol-logistics-scavenge-countdown" end
  if state == "logistics-clearing-space" then return "tech-priests-priest-status-symbol-logistics-clearing-space" end
  if state == "logistics-cram-countdown" then return "tech-priests-priest-status-symbol-logistics-cram-countdown" end
  if state == "logistics-no-network" then return "tech-priests-priest-status-symbol-logistics-no-network" end
  if state == "scavenging-supplies" then return "tech-priests-priest-status-symbol-scavenging-supplies" end
  if state == "cramming-supplies" then return "tech-priests-priest-status-symbol-cramming-supplies" end
  if state == "deploy" then return "tech-priests-priest-status-symbol-deploy" end
  if state == "returning" then return "tech-priests-priest-status-symbol-return" end
  return "tech-priests-priest-status-symbol-idle"
end

function get_priest_status_fallback_symbol(state)
  if state == "combat" then return "!" end
  if state == "repair" then return "+" end
  if state == "repair-waiting" then return "[item=repair-pack]?" end
  if state == "repair-missing-supplies" then return "[item=repair-pack]!" end
  if state == "consecrate" then return "[item=sacred-machine-oil]" end
  if state == "consecrate-waiting" then return "[item=sacred-machine-oil]?" end
  if state == "consecrate-missing-supplies" then return "[item=sacred-machine-oil]!" end
  if state == "ammo-missing-supplies" then return "[item=firearm-magazine]!" end
  if state == "awaiting-logistics" then return "?{seconds}" end
  if state == "logistics-requested" then return "[virtual-signal=signal-clock]{seconds}" end
  if state == "logistics-scavenge-countdown" then return "[virtual-signal=signal-clock]{seconds}" end
  if state == "logistics-clearing-space" then return "[virtual-signal=signal-trash]" end
  if state == "logistics-cram-countdown" then return "[virtual-signal=signal-trash]{seconds}" end
  if state == "logistics-no-network" then return "[virtual-signal=signal-deny]" end
  if state == "scavenging-supplies" then return "[item=steel-chest]?" end
  if state == "cramming-supplies" then return "[item=steel-chest]!" end
  if state == "deploy" then return "*" end
  if state == "returning" then return "<-" end
  return "..."
end

function trim_priest_status_variant(value)
  if not value then return "" end
  value = tostring(value)
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value
end

function collect_priest_status_variants(value)
  local variants = {}
  value = tostring(value or "")
  for part in string.gmatch(value, "[^|]+") do
    local trimmed = trim_priest_status_variant(part)
    if trimmed ~= "" then variants[#variants + 1] = trimmed end
  end
  if #variants == 0 and value ~= "" then
    variants[1] = value
  end
  return variants
end

function choose_priest_status_variant(raw_value, pair, state)
  local variants = collect_priest_status_variants(raw_value)
  if #variants == 0 then return get_priest_status_fallback_symbol(state) end
  if #variants == 1 then return variants[1] end

  -- Deterministic variation: no runtime math.random required, so multiplayer
  -- clients see the same symbol choice for the same priest and tick window.
  local interval = math.max(30, math.floor(read_global_double_setting("tech-priests-priest-status-bubble-interval-ticks", DEFAULT_PRIEST_STATUS_BUBBLE_INTERVAL_TICKS)))
  local station_unit = (pair and pair.station_unit) or (pair and pair.station and pair.station.valid and pair.station.unit_number) or 0
  local state_hash = 0
  for i = 1, #tostring(state or "") do
    state_hash = state_hash + string.byte(tostring(state), i)
  end
  local tick_bucket = game and game.tick and math.floor(game.tick / interval) or 0
  local index = ((station_unit * 31 + state_hash * 7 + tick_bucket) % #variants) + 1
  return variants[index]
end

function get_priest_status_symbol(pair)
  local state = classify_priest_visual_state(pair)
  local raw = read_global_string_setting(get_priest_status_setting_name(state), get_priest_status_fallback_symbol(state))
  local symbol = choose_priest_status_variant(raw, pair, state)
  local remaining = 0
  if pair and pair.logistic_frustration_due_tick then
    remaining = math.max(0, math.ceil((pair.logistic_frustration_due_tick - game.tick) / 60))
  end
  symbol = tostring(symbol or ""):gsub("{seconds}", tostring(remaining))
  symbol = symbol:gsub("{item}", tostring((pair and pair.logistic_requested_item) or ""))
  return symbol
end

function get_priest_target_line_color(pair)
  local state = classify_priest_visual_state(pair)
  if state == "combat" then return { r = 1.00, g = 0.18, b = 0.08, a = 0.82 } end
  if state == "repair" then return { r = 0.20, g = 0.80, b = 1.00, a = 0.80 } end
  if state == "repair-waiting" then return { r = 0.30, g = 0.65, b = 1.00, a = 0.52 } end
  if state == "repair-missing-supplies" then return { r = 0.18, g = 0.30, b = 1.00, a = 0.70 } end
  if state == "consecrate" then return { r = 1.00, g = 0.86, b = 0.20, a = 0.84 } end
  if state == "consecrate-waiting" then return { r = 1.00, g = 0.86, b = 0.20, a = 0.50 } end
  if state == "consecrate-missing-supplies" then return { r = 1.00, g = 0.42, b = 0.16, a = 0.72 } end
  if state == "awaiting-logistics" then return { r = 0.90, g = 0.80, b = 0.20, a = 0.70 } end
  if state == "logistics-requested" or state == "logistics-scavenge-countdown" then return { r = 0.35, g = 0.90, b = 1.00, a = 0.72 } end
  if state == "logistics-clearing-space" or state == "logistics-cram-countdown" then return { r = 1.00, g = 0.55, b = 0.18, a = 0.78 } end
  if state == "cramming-supplies" then return { r = 1.00, g = 0.35, b = 0.08, a = 0.82 } end
  if state == "logistics-no-network" then return { r = 0.95, g = 0.20, b = 0.20, a = 0.78 } end
  if state == "deploy" or state == "returning" then return { r = 0.65, g = 0.65, b = 0.65, a = 0.60 } end
  return { r = 0.45, g = 0.45, b = 0.45, a = 0.45 }
end

function get_priest_current_target(pair)
  if not pair then return nil end
  if pair.target and pair.target.valid then return pair.target end
  if pair.mode == "deploying" or pair.mode == "returning" then
    if pair.station and pair.station.valid then return pair.station end
  end
  return nil
end

function draw_priest_status_text(args)
  if not (rendering and rendering.draw_text and args) then return nil end
  local ok, object = pcall(function()
    args.use_rich_text = true
    return rendering.draw_text(args)
  end)
  if ok and object then return object end
  args.use_rich_text = nil
  ok, object = pcall(function() return rendering.draw_text(args) end)
  if ok and object then return object end
  return nil
end

function clear_priest_status_bubble(station_unit)
  ensure_storage()
  local existing = storage.tech_priests.priest_bubbles and storage.tech_priests.priest_bubbles[station_unit]
  if existing then
    destroy_render_object(existing)
    storage.tech_priests.priest_bubbles[station_unit] = nil
  end
end

function draw_priest_status_bubble(pair)
  if not read_global_bool_setting("tech-priests-enable-priest-status-bubbles", true) then return end
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid and pair.station.unit_number) then return end
  ensure_storage()
  clear_priest_status_bubble(pair.station.unit_number)
  local state = classify_priest_visual_state(pair)
  local symbol = get_priest_status_symbol(pair)
  local duration = math.max(15, math.floor(read_global_double_setting("tech-priests-priest-status-bubble-duration-ticks", DEFAULT_PRIEST_STATUS_BUBBLE_DURATION_TICKS)))
  local object = draw_priest_status_text({
    text = symbol,
    target = { entity = pair.priest, offset = { 0, -1.95 } },
    surface = pair.priest.surface,
    color = get_priest_target_line_color(pair),
    scale = 1.00,
    alignment = "center",
    time_to_live = duration
  })
  if object then
    storage.tech_priests.priest_bubbles[pair.station.unit_number] = object
  end
  pair.last_status_bubble_state = state
end

function update_priest_status_bubbles()
  if not read_global_bool_setting("tech-priests-enable-priest-status-bubbles", true) then return end
  ensure_storage()
  local interval = math.max(30, math.floor(read_global_double_setting("tech-priests-priest-status-bubble-interval-ticks", DEFAULT_PRIEST_STATUS_BUBBLE_INTERVAL_TICKS)))
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if pair.station and pair.station.valid and pair.priest and pair.priest.valid then
      local state = classify_priest_visual_state(pair)
      if state ~= pair.last_status_bubble_state or game.tick >= (pair.next_status_bubble_tick or 0) then
        draw_priest_status_bubble(pair)
        pair.next_status_bubble_tick = game.tick + interval
      end
    elseif pair.station_unit then
      clear_priest_status_bubble(pair.station_unit)
    end
  end
end

function draw_station_radius_for_player(player)
  if not (player and player.valid) then return end
  clear_radius_rendering(player.index)

  local selected = player.selected
  local pair = nil
  if is_station(selected) then
    pair = find_pair_for_entity and find_pair_for_entity(selected) or nil
  elseif is_priest(selected) then
    pair = find_pair_for_entity and find_pair_for_entity(selected) or nil
  end

  if is_station(selected) and not pair then
    create_pair(selected)
    pair = find_pair_for_entity and find_pair_for_entity(selected) or nil
  end

  if not (pair and pair.station and pair.station.valid) then return end

  ensure_pair_priest(pair, false, true)

  local station = pair.station
  local priest = pair.priest
  apply_pair_display_names(pair)

  local renders = {}

  -- 0.1.464: restore the selected-station operating radius as an outline-only
  -- circle.  This is not the failed green station-light disk; it is the readable
  -- perimeter reference the player wanted to keep.
  local ok_circle, circle = pcall(function()
    return rendering.draw_circle({
      color = { r = 0.95, g = 0.55, b = 0.10, a = 0.32 },
      radius = get_station_operating_radius(station),
      width = 2,
      filled = false,
      target = station,
      surface = station.surface,
      draw_on_ground = true,
      players = { player },
      time_to_live = RADIUS_RENDER_TTL
    })
  end)

  if priest and priest.valid then
    local ok_line, line = pcall(function()
      return rendering.draw_line({
        color = { r = 0.15, g = 0.95, b = 0.35, a = 0.80 },
        width = 3,
        from = { entity = station, offset = { 0, -0.25 } },
        to = { entity = priest, offset = { 0, -0.15 } },
        surface = station.surface,
        players = { player },
        time_to_live = LINK_RENDER_TTL
      })
    end)
    if ok_line and line then renders.link = line end

    local ok_station_text, station_text = pcall(function()
      return rendering.draw_text({
        text = pair.station_display_name,
        target = { entity = station, offset = { 0, -2.45 } },
        surface = station.surface,
        color = { r = 1.00, g = 0.78, b = 0.28, a = 0.95 },
        scale = 0.85,
        alignment = "center",
        players = { player },
        time_to_live = LINK_RENDER_TTL
      })
    end)
    if ok_station_text and station_text then renders.station_text = station_text end

    local ok_priest_text, priest_text = pcall(function()
      return rendering.draw_text({
        text = pair.priest_display_name,
        target = { entity = priest, offset = { 0, -1.45 } },
        surface = station.surface,
        color = { r = 0.85, g = 1.00, b = 0.85, a = 0.92 },
        scale = 0.75,
        alignment = "center",
        players = { player },
        time_to_live = LINK_RENDER_TTL
      })
    end)
    if ok_priest_text and priest_text then renders.priest_text = priest_text end

    local current_target = get_priest_current_target(pair)
    if current_target and current_target.valid and current_target ~= priest then
      local ok_target_line, target_line = pcall(function()
        return rendering.draw_line({
          color = get_priest_target_line_color(pair),
          width = 2,
          from = { entity = priest, offset = { 0, -0.15 } },
          to = { entity = current_target, offset = { 0, -0.15 } },
          surface = station.surface,
          players = { player },
          time_to_live = LINK_RENDER_TTL
        })
      end)
      if ok_target_line and target_line then renders.target_line = target_line end
    else
      local null_text = draw_priest_status_text({
        text = choose_priest_status_variant(read_global_string_setting("tech-priests-priest-status-symbol-idle", "..."), pair, "idle"),
        target = { entity = priest, offset = { 0, -2.05 } },
        surface = station.surface,
        color = { r = 0.55, g = 0.55, b = 0.55, a = 0.70 },
        scale = 0.70,
        alignment = "center",
        players = { player },
        time_to_live = LINK_RENDER_TTL
      })
      if null_text then renders.target_null_text = null_text end
    end
  end

  storage.tech_priests.radius_rendering_by_player[player.index] = renders
end
function on_selected_entity_changed(event)
  local player = game.get_player(event.player_index)
  if player then
    draw_station_radius_for_player(player)
    if player.selected and is_consecration_target(player.selected) then
      draw_sanctification_label(get_consecration_record(player.selected))
    end
  end
end

function refresh_radius_rendering_for_players()
  ensure_storage()
  for _, player in pairs(game.connected_players) do
    draw_station_radius_for_player(player)
  end
end

function is_ammo_item(item_name)
  local prototype = get_item_prototype(item_name)
  return prototype and prototype.type == "ammo"
end

function find_ammo_item(inventory)
  if not inventory then return nil end
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read and is_ammo_item(stack.name) then
      return stack.name
    end
  end
  return nil
end

function issue_priest_command(priest, command)
  if not (priest and priest.valid) then return false end
  local commandable = priest.commandable
  if commandable and commandable.valid then
    commandable.set_command(command)
    return true
  end
  return false
end

function return_to_station(priest, station)
  if not (priest and priest.valid) then return false end
  if not (station and station.valid and station.position) then
    if tech_priests_0247_diag then
      tech_priests_0247_diag("return_to_station rejected: missing/invalid station for priest " .. tostring(priest and priest.name or "nil") .. " unit=" .. tostring(priest and priest.unit_number or "nil"))
    end
    return false
  end
  return issue_priest_command(priest, {
    type = defines.command.go_to_location,
    destination = station.position,
    radius = 2,
    distraction = defines.distraction.by_enemy
  })
end

function update_priest_footsteps(pair)
  if not (pair and pair.priest and pair.priest.valid) then return end

  local priest = pair.priest
  local position = priest.position
  if not position then return end

  if not pair.last_footstep_position then
    pair.last_footstep_position = { x = position.x, y = position.y }
    pair.next_footstep_tick = game.tick + FOOTSTEP_INTERVAL_TICKS
    return
  end

  if pair.mode == "idle" or pair.mode == "repairing" or pair.mode == "defending" then
    pair.last_footstep_position = { x = position.x, y = position.y }
    return
  end

  if game.tick < (pair.next_footstep_tick or 0) then return end

  local dx = position.x - pair.last_footstep_position.x
  local dy = position.y - pair.last_footstep_position.y
  local moved_sq = dx * dx + dy * dy

  if moved_sq < FOOTSTEP_MIN_MOVEMENT_SQ then return end
  if moved_sq > 16 then
    -- Treat large discontinuities as teleport/correction rather than walking.
    pair.last_footstep_position = { x = position.x, y = position.y }
    pair.next_footstep_tick = game.tick + FOOTSTEP_INTERVAL_TICKS
    return
  end

  pcall(function()
    priest.surface.play_sound({
      path = FOOTSTEP_SOUND_PATH,
      position = position,
      volume_modifier = 0.55
    })
  end)

  pair.last_footstep_position = { x = position.x, y = position.y }
  pair.next_footstep_tick = game.tick + FOOTSTEP_INTERVAL_TICKS
end

function get_health_ratio(entity)
  if not (entity and entity.valid and entity.health and entity.max_health and entity.max_health > 0) then
    return nil
  end
  return math.max(0, math.min(1, entity.health / entity.max_health))
end

function set_health_ratio(entity, ratio)
  if not (entity and entity.valid and entity.health and entity.max_health and entity.max_health > 0) then
    return
  end
  local new_health = math.max(1, math.min(entity.max_health, entity.max_health * ratio))
  if entity.health ~= new_health then
    entity.health = new_health
  end
end

function sync_linked_health(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then
    return
  end

  local station_ratio = get_health_ratio(pair.station)
  local priest_ratio = get_health_ratio(pair.priest)
  if not (station_ratio and priest_ratio) then return end

  local last_ratio = pair.linked_health_ratio
  if not last_ratio then
    last_ratio = math.min(station_ratio, priest_ratio)
    pair.linked_health_ratio = last_ratio
    set_health_ratio(pair.station, last_ratio)
    set_health_ratio(pair.priest, last_ratio)
    return
  end

  local damage_detected = station_ratio < last_ratio - HEALTH_LINK_EPSILON or priest_ratio < last_ratio - HEALTH_LINK_EPSILON
  local repair_detected = station_ratio > last_ratio + HEALTH_LINK_EPSILON or priest_ratio > last_ratio + HEALTH_LINK_EPSILON

  local target_ratio = last_ratio
  if damage_detected then
    target_ratio = math.min(station_ratio, priest_ratio, last_ratio)
  elseif repair_detected then
    target_ratio = math.max(station_ratio, priest_ratio, last_ratio)
  else
    return
  end

  target_ratio = math.max(0, math.min(1, target_ratio))
  pair.linked_health_ratio = target_ratio
  set_health_ratio(pair.station, target_ratio)
  set_health_ratio(pair.priest, target_ratio)
end

function cleanup_pair(pair)
  if not pair then return end
  ensure_storage()
  if pair.proxy and pair.proxy.valid then
    pair.proxy.destroy({ raise_destroy = false })
  end
  if pair.logistic_requester and pair.logistic_requester.valid then
    pair.logistic_requester.destroy({ raise_destroy = false })
  end
  if pair.logistic_return_cache and pair.logistic_return_cache.valid then
    pair.logistic_return_cache.destroy({ raise_destroy = false })
  end
  if pair.station_unit then
    clear_priest_status_bubble(pair.station_unit)
    storage.tech_priests.pairs_by_station[pair.station_unit] = nil
  end
  if pair.priest_unit then
    storage.tech_priests.station_by_priest[pair.priest_unit] = nil
  end
end

function create_station_ruins_and_ghost(station)
  if not (station and station.valid) then return end

  local surface = station.surface
  local position = station.position
  local force = station.force
  local station_name = station.name

  pcall(function()
    surface.create_entity({
      name = COGITATOR_DYING_EXPLOSION,
      position = position,
      force = force
    })
  end)

  pcall(function()
    surface.create_entity({
      name = "medium-remnants",
      position = position,
      force = force
    })
  end)

  pcall(function()
    surface.create_entity({
      name = "entity-ghost",
      inner_name = station_name,
      position = position,
      quality = get_entity_quality_name(station),
      force = force,
      expires = false
    })
  end)
end

find_pair_for_entity = function(entity)
  if not (entity and entity.valid and entity.unit_number) then return nil end
  ensure_storage()
  if is_station(entity) then
    return storage.tech_priests.pairs_by_station[entity.unit_number]
  elseif is_priest(entity) then
    local station_unit = storage.tech_priests.station_by_priest[entity.unit_number]
    if station_unit then
      return storage.tech_priests.pairs_by_station[station_unit]
    end
  end
  return nil
end

function remove_pair_for_entity(entity, source_event)
  ensure_storage()
  if storage.tech_priests.busy then return end
  local pair = find_pair_for_entity(entity)
  if not pair then return end

  storage.tech_priests.busy = true

  local station = pair.station
  local priest = pair.priest
  local proxy = pair.proxy
  local triggering_entity_name = entity and entity.valid and entity.name or nil
  local is_death_event = source_event and source_event.name == defines.events.on_entity_died
  local should_create_station_ruins = is_death_event and PRIEST_TO_STATION[triggering_entity_name] and station and station.valid

  if priest and priest.valid then
    -- Real death/removal of a linked priest, or linked cleanup caused by station
    -- removal, gets a small ritual puff rather than silently vanishing.
    spawn_priest_smoke_for_entity(priest, is_death_event)
  end

  cleanup_pair(pair)

  if station and station.valid and station ~= entity then
    if should_create_station_ruins then
      create_station_ruins_and_ghost(station)
    end
    station.destroy({ raise_destroy = false })
  end
  if priest and priest.valid and priest ~= entity then
    if tech_priests_destroy_priest_0500 then
      tech_priests_destroy_priest_0500(priest, "station-cleanup-remove_pair_for_entity", pair, { allow_station_cleanup = is_station and is_station(entity) })
    else
      priest.destroy({ raise_destroy = false })
    end
  end
  if proxy and proxy.valid and proxy ~= entity then
    proxy.destroy({ raise_destroy = false })
  end

  storage.tech_priests.busy = false
end
