-- Auto-split control.lua fragment 021 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.

-- 0.1.674-dev: visible-grid reading is consolidated into canonical 0305.
-- 0306 retains GUI and bay presentation only; it no longer replaces 0305
-- and its diagnostic command is retired by runtime_command_cleanup_0720.
TECH_PRIESTS_0306_REFRESH_OVERRIDE_RETIRED = true
TECH_PRIESTS_0306_DEBUG_COMMAND_RETIRED = true
tech_priests_0306_log("visible Cogitator equipment grid + honest direct mining damage loaded")


-- ============================================================================
-- 0.1.307 Priest ambient/mode glow doctrine
-- Adds a soft white cogitator-lantern glow to every active Tech-Priest and a
-- second colored glow keyed to the current task/mode.  Render objects are
-- refreshed on a slow cadence and TTL-expire, so stale lights do not linger if
-- a priest dies, re-imprints, or gets replaced.
-- ============================================================================
TECH_PRIESTS_GLOW_VERSION_0307 = "0.1.307"
TECH_PRIESTS_GLOW_REFRESH_TICKS_0307 = 19
TECH_PRIESTS_GLOW_TTL_0307 = 34
TECH_PRIESTS_WHITE_GLOW_COLOR_0307 = { r = 1.0, g = 0.96, b = 0.86, a = 0.62 }

function tech_priests_0307_log(msg)
  if log then log("[Tech-Priests 0.1.307] " .. tostring(msg)) end
end

function tech_priests_0307_safe_destroy_render(id)
  tech_priests_0309_destroy_render_object(id)
end

function tech_priests_0307_pair_live_priest(pair)
  if not (pair and pair.priest and pair.priest.valid) then return nil end
  if is_priest then
    local ok, result = pcall(is_priest, pair.priest)
    if ok and not result then return nil end
  end
  return pair.priest
end

function tech_priests_0307_pair_mode_text(pair)
  if not pair then return "idle" end
  local active = pair.active_task or pair.active_task_0285 or nil
  local parts = {}
  local function add(v)
    if v ~= nil then parts[#parts + 1] = string.lower(tostring(v)) end
  end
  add(pair.mode)
  add(pair.phase)
  add(pair.current_task)
  add(pair.priority)
  if active then
    add(active.type)
    add(active.kind)
    add(active.item)
    add(active.reason)
  end
  if pair.inventory_scan then add("inventory-scan") end
  if pair.scavenge then add("scavenge") end
  if pair.emergency_craft then add("craft") end
  if pair.reimprinting_0298 or pair.reimprint_0298 then add("reimprinting") end
  return table.concat(parts, " ")
end

function tech_priests_0307_mode_color(pair)
  local mode = tech_priests_0307_pair_mode_text(pair)

  -- Emergency/independent doctrines are intentionally alarming.
  if string.find(mode, "pinned") or string.find(mode, "no%-ammo") then
    return { r = 1.00, g = 0.08, b = 0.02, a = 0.78 }, "pinned/no-ammo"
  end
  if string.find(mode, "emergency") or string.find(mode, "independent") or string.find(mode, "survival") then
    return { r = 1.00, g = 0.10, b = 0.02, a = 0.70 }, "emergency"
  end
  if string.find(mode, "retreat") or string.find(mode, "reimprint") or string.find(mode, "recover") or string.find(mode, "healing") then
    return { r = 0.92, g = 0.15, b = 1.00, a = 0.66 }, "recovery"
  end

  -- Combat should read as weapon discipline rather than logistic work.
  if string.find(mode, "combat") or string.find(mode, "defend") or string.find(mode, "attack") or string.find(mode, "enemy") then
    return { r = 1.00, g = 0.22, b = 0.02, a = 0.70 }, "combat"
  end

  -- Service tasks.
  if string.find(mode, "repair") then
    return { r = 0.20, g = 1.00, b = 0.24, a = 0.64 }, "repair"
  end
  if string.find(mode, "sanct") or string.find(mode, "consecr") or string.find(mode, "oil") then
    return { r = 0.00, g = 0.95, b = 0.34, a = 0.64 }, "sanctification"
  end

  -- Radar/scanning/inventory reads are blue.
  if string.find(mode, "scan") or string.find(mode, "inventory") or string.find(mode, "radar") or string.find(mode, "survey") then
    return { r = 0.05, g = 0.42, b = 1.00, a = 0.62 }, "scan"
  end

  -- Acquisition/quarry/mining/scavenging are work lights: orange/amber.
  if string.find(mode, "mine") or string.find(mode, "quarry") or string.find(mode, "gather") or string.find(mode, "scavenge") or string.find(mode, "resource") or string.find(mode, "acquisition") then
    return { r = 1.00, g = 0.54, b = 0.05, a = 0.64 }, "acquisition"
  end
  if string.find(mode, "craft") or string.find(mode, "logistic") or string.find(mode, "supply") or string.find(mode, "request") or string.find(mode, "assignment") then
    return { r = 1.00, g = 0.74, b = 0.04, a = 0.62 }, "logistics/craft"
  end

  -- Idle/ordinary duty: muted Mechanicus green.
  return { r = 0.16, g = 0.88, b = 0.20, a = 0.50 }, "idle"
end

function tech_priests_0307_draw_light(pair, priest, color, scale, intensity, minimum_darkness)
  if not (rendering and rendering.draw_light and priest and priest.valid) then return nil end
  local ok, id = pcall(function()
    return rendering.draw_light{
      sprite = "utility/light_medium",
      target = priest,
      surface = priest.surface,
      color = color,
      scale = scale or 3.0,
      intensity = intensity or 0.35,
      minimum_darkness = minimum_darkness or 0.0,
      time_to_live = TECH_PRIESTS_GLOW_TTL_0307,
      forces = { priest.force },
      draw_on_ground = true,
    }
  end)
  if ok then return id end
  return nil
end

function tech_priests_0307_refresh_pair_glow(pair)
  if not pair then return end
  local priest = tech_priests_0307_pair_live_priest(pair)
  local destroy = tech_priests_0315_destroy_render or tech_priests_0307_safe_destroy_render
  destroy(pair.glow_ambient_0307)
  destroy(pair.glow_mode_0307)
  destroy(pair.glow_day_ambient_0310)
  destroy(pair.glow_day_mode_0310)
  pair.glow_ambient_0307 = nil
  pair.glow_mode_0307 = nil
  pair.glow_day_ambient_0310 = nil
  pair.glow_day_mode_0310 = nil
  if not priest then
    pair.glow_mode_name_0307 = nil
    pair.glow_mode_color_0307 = nil
    return
  end

  local mode_color, mode_name = tech_priests_0307_mode_color(pair)
  if tech_priests_0315_soft_color then
    mode_color = tech_priests_0315_soft_color(mode_color, 0.22)
  else
    mode_color = mode_color or { r = 0.3, g = 1.0, b = 0.25, a = 0.22 }
    mode_color = {
      r = mode_color.r or 0.3,
      g = mode_color.g or 1.0,
      b = mode_color.b or 0.25,
      a = 0.22,
    }
  end
  pair.glow_mode_name_0307 = mode_name or "idle"
  pair.glow_mode_color_0307 = mode_color
  pair.glow_last_tick_0307 = game and game.tick or 0

  if rendering and rendering.draw_light then
    pcall(function()
      pair.glow_ambient_0307 = rendering.draw_light{
        sprite = "utility/light_medium",
        target = priest,
        surface = priest.surface,
        color = { r = 1.0, g = 0.96, b = 0.86, a = 0.16 },
        scale = 1.50,
        intensity = TECH_PRIESTS_0315_AMBIENT_GLOW_INTENSITY or 0.07,
        minimum_darkness = 0.45,
        time_to_live = 36,
        forces = { priest.force },
      }
    end)
    pcall(function()
      pair.glow_mode_0307 = rendering.draw_light{
        sprite = "utility/light_medium",
        target = priest,
        surface = priest.surface,
        color = mode_color,
        scale = 2.30,
        intensity = TECH_PRIESTS_0315_MODE_GLOW_INTENSITY or 0.13,
        minimum_darkness = 0.35,
        time_to_live = 36,
        forces = { priest.force },
      }
    end)
  end
end

function tech_priests_0307_refresh_all_glows()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    tech_priests_0307_refresh_pair_glow(pair)
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(TECH_PRIESTS_GLOW_REFRESH_TICKS_0307, function()
  tech_priests_0307_refresh_all_glows()
end)

TECH_PRIESTS_0307_DEBUG_COMMAND_RETIRED = true

tech_priests_0307_log("ambient white priest glow + mode-colored operating aura loaded")


-- 0.1.308 LuaRendering validity crash guard
TECH_PRIESTS_0308_DEBUG_COMMAND_RETIRED = true

if log then log("[Tech-Priests 0.1.308] LuaRendering-safe glow destroy guard loaded") end


-- ============================================================================
-- 0.1.309 LuaRendering destroy/clear guard
-- ============================================================================
if log then log("[Tech-Priests 0.1.309] LuaRendering destroy/clear guard loaded") end


-- ============================================================================
-- 0.1.310 Station inventory reopening, ranked priest names, daytime glow shim,
-- and station-damage defensive guards.
-- This pass repairs the 0.1.306 GUI registration that replaced older GUI
-- handlers and stole the normal chest/opened inventory by setting player.opened
-- to the scripted equipment frame.
-- ============================================================================
TECH_PRIESTS_PATCH_VERSION_0310 = "0.1.310"

function tech_priests_0310_log(msg)
  if log then log("[Tech-Priests 0.1.310] " .. tostring(msg)) end
end

function tech_priests_0310_rank_title_for_pair(pair)
  local name = nil
  if pair and pair.priest and pair.priest.valid then name = pair.priest.name end
  if not name and pair and pair.rank_key then name = tostring(pair.rank_key) end
  name = tostring(name or "")
  if string.find(name, "planetary%-magos") or string.find(name, "planetary_magos") then return "Planetary Magos" end
  if string.find(name, "void") then return "Void Tech-Priest" end
  if string.find(name, "senior") then return "Senior Tech-Priest" end
  if string.find(name, "intermediate") then return "Intermediate Tech-Priest" end
  if string.find(name, "junior") then return "Junior Tech-Priest" end
  return "Tech-Priest"
end

function tech_priests_0310_strip_old_priest_rank_prefix(text)
  text = tostring(text or "")
  local patterns = {
    "^Junior Tech%-Priest%s+", "^Intermediate Tech%-Priest%s+", "^Senior Tech%-Priest%s+",
    "^Planetary Magos%s+", "^Void Tech%-Priest%s+", "^Tech%-Priest%s+"
  }
  for _, pat in pairs(patterns) do text = string.gsub(text, pat, "") end
  return text
end

TECH_PRIESTS_PRE_RANKED_NAMES_0310 = apply_pair_display_names
function apply_pair_display_names(pair)
  if TECH_PRIESTS_PRE_RANKED_NAMES_0310 then pcall(function() TECH_PRIESTS_PRE_RANKED_NAMES_0310(pair) end) end
  if not pair then return end
  local cell_name = get_pair_display_name and get_pair_display_name(pair) or pair.cell_name or "Uncatalogued"
  if not pair.station_display_name or tostring(pair.station_display_name) == "" then
    pair.station_display_name = "Cogitator Station " .. tostring(cell_name)
  end
  local title = tech_priests_0310_rank_title_for_pair(pair)
  local base = tech_priests_0310_strip_old_priest_rank_prefix(pair.priest_display_name or pair.cell_name or cell_name)
  if base == "" then base = tostring(cell_name) end
  pair.priest_display_name = title .. " " .. base
  pair.player_facing_priest_name_0218 = pair.priest_display_name
  pair.player_facing_station_name_0218 = pair.station_display_name
  if pair.station and pair.station.valid then pcall(function() pair.station.backer_name = pair.station_display_name end) end
  if pair.priest and pair.priest.valid then pcall(function() pair.priest.backer_name = pair.priest_display_name end) end
end

-- 0.1.674-dev: the 0310 side-panel replacement is retired.
TECH_PRIESTS_0310_GRID_SIDE_PANEL_OVERRIDE_RETIRED = true

function tech_priests_0310_find_pair_from_event_entity(entity)
  if not (entity and entity.valid) then return nil end
  if find_pair_for_entity then
    local ok, pair = pcall(function() return find_pair_for_entity(entity) end)
    if ok and pair then return pair end
  end
  if is_station and is_station(entity) and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
    return storage.tech_priests.pairs_by_station[entity.unit_number]
  end
  return nil
end

function tech_priests_0310_handle_overview_click(event)
  local element = event and event.element
  if not (element and element.valid) then return false end
  local name = element.name or ""
  local player = event.player_index and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return false end
  if not (TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 and tech_priests_build_command_overview_0189) then return false end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_CLOSE_0189 then
    if tech_priests_destroy_command_overview_0189 then tech_priests_destroy_command_overview_0189(player) end
    return true
  end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_REFRESH_0189 then
    tech_priests_build_command_overview_0189(player)
    return true
  end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_TOGGLE_0190 then
    local rows = tech_priests_valid_pairs_for_player_0189(player)
    local pair = tech_priests_get_selected_pair_0189(player, rows)
    if pair and tech_priests_set_emergency_operation_0184 and tech_priests_get_emergency_operation_0184 then
      local enable = tech_priests_get_emergency_operation_0184(pair) == nil
      if tech_priests_set_emergency_operation_0184(pair, enable, "overview-ui") then
        player.print({ "", "[Tech-Priest Command] Independent / emergency doctrine ", enable and "enabled" or "disabled", " for ", tech_priests_station_name_0189(pair), "." })
      end
    end
    tech_priests_build_command_overview_0189(player)
    return true
  end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_AUTO_0190 then
    local rows = tech_priests_valid_pairs_for_player_0189(player)
    local pair = tech_priests_get_selected_pair_0189(player, rows)
    if pair then
      pair.emergency_operation_auto_allowed_0190 = true
      player.print({ "", "[Tech-Priest Command] Frustration auto-enable is authorized for ", tech_priests_station_name_0189(pair), "." })
    end
    tech_priests_build_command_overview_0189(player)
    return true
  end
  if string.sub(name, 1, #TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189) == TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 then
    local rest = string.sub(name, #TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 + 1)
    local center = false
    if string.sub(rest, -7) == "_center" then center = true; rest = string.sub(rest, 1, -8) end
    local station_unit = tonumber(rest)
    if station_unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
      local pair = storage.tech_priests.pairs_by_station[station_unit]
      if pair and pair.station and pair.station.valid and pair.station.force == player.force then
        tech_priests_command_overview_storage_0189()[player.index] = station_unit
        if tech_priests_command_overview_set_selected_tab_0371 then tech_priests_command_overview_set_selected_tab_0371(player, "roster") end
        if center then
          local loc_entity = pair.priest and pair.priest.valid and pair.priest or pair.station
          player.print({ "", "[Tech-Priest Command] ", tech_priests_pair_name_0189(pair), " is on ", loc_entity.surface.name, " at ", tech_priests_entity_coord_0189(loc_entity), "." })
        end
        tech_priests_build_command_overview_0189(player)
      end
    end
    return true
  end
  return false
end

-- 0.1.674-dev: canonical 0306 owns the sole generated GUI router family.
TECH_PRIESTS_0310_GUI_ROUTER_WRAPPERS_RETIRED = true

-- 0.1.674-dev: the 0310 daylight sprite-aura wrapper is retired.
-- Canonical 0307 owns the final night-clamped light behavior directly.
TECH_PRIESTS_0310_DAYLIGHT_GLOW_WRAPPER_RETIRED = true

-- 0.1.674-dev: 0310 station bookkeeping is integrated into canonical 0305.
-- Its wrapper and second on_entity_damaged registration are retired.
TECH_PRIESTS_0310_DAMAGE_WRAPPER_RETIRED = true

-- 0.1.674-dev: manual 0310 GUI command is retired; automatic GUI routing remains.
TECH_PRIESTS_0310_DEBUG_COMMAND_RETIRED = true

tech_priests_0310_log("station inventory + side equipment grid GUI chain, ranked priest names, daytime glow shim, and station-damage guard loaded")


-- 0.1.311: station/chest GUI and glow syntax crash repair marker.
TECH_PRIESTS_0311_DEBUG_COMMAND_RETIRED = true

-- -----------------------------------------------------------------------------
-- 0.1.312 mining-laser fallback weapon + preserved cell display labels
-- -----------------------------------------------------------------------------
-- The Tech-Priest quarry/mining beam should be the same family of effect as the
-- personal point-defense laser: a small, slow laser pulse that actually damages
-- what it is pointing at.  It also becomes the no-ammunition fallback weapon so
-- priests are never completely helpless when their Cogitator shrine is empty of
-- magazines.  This is intentionally weak and cadence-limited.

TECH_PRIESTS_PATCH_0312 = "0.1.312-mining-laser-fallback-weapon"
TECH_PRIESTS_0312_MINING_LASER_DAMAGE = 5
TECH_PRIESTS_0312_MINING_LASER_TICKS = 15
TECH_PRIESTS_0312_FALLBACK_LASER_TICKS = 30
TECH_PRIESTS_0312_FALLBACK_LASER_RANGE = TECH_PRIESTS_POINT_BLANK_LASER_RANGE or 1.5

function tech_priests_0312_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.312] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.312] " .. tostring(msg))
  end
end

function tech_priests_0312_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0312_item_exists(name)
  if not (name and name ~= "") then return false end
  if prototypes then
    local ok, proto = pcall(function() return prototypes.item[name] end)
    if ok and proto then return true end
  end
  if tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(name) then return true end
  return false
end

function tech_priests_0312_station_has_ammo(pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  if count_station_ammo_items then
    local ok, n = pcall(function() return count_station_ammo_items(pair.station) end)
    if ok and n and n > 0 then return true end
  end
  local inv = get_station_inventory and get_station_inventory(pair.station) or nil
  if inv and find_ammo_item then
    local ok, ammo = pcall(function() return find_ammo_item(inv) end)
    if ok and ammo then return true end
  end
  if inv then
    local common = { "firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine" }
    for _, item in pairs(common) do
      if tech_priests_0312_item_exists(item) then
        local ok, count = pcall(function() return inv.get_item_count(item) end)
        if ok and count and count > 0 then return true end
      end
    end
  end
  return false
end

function tech_priests_0312_proxy_has_ammo(pair)
  if not (pair and pair.proxy and pair.proxy.valid) then return false end
  if get_turret_ammo_inventory and turret_inventory_has_ammo then
    local ok, inv = pcall(function() return get_turret_ammo_inventory(pair.proxy) end)
    if ok and inv then
      local ok2, has = pcall(function() return turret_inventory_has_ammo(inv) end)
      if ok2 and has then return true end
    end
  end
  return false
end

function tech_priests_0312_has_ballistic_ammo(pair)
  return tech_priests_0312_station_has_ammo(pair) or tech_priests_0312_proxy_has_ammo(pair)
end

function tech_priests_0312_radius(pair)
  if refresh_pair_radius then
    local ok, r = pcall(function() return refresh_pair_radius(pair) end)
    if ok and r then return r end
  end
  return pair and (pair.radius or COMBAT_FIRE_RANGE or TECH_PRIESTS_0312_FALLBACK_LASER_RANGE) or TECH_PRIESTS_0312_FALLBACK_LASER_RANGE
end

function tech_priests_0312_is_hostile(entity, force)
  if not (entity and entity.valid and entity.force and force) then return false end
  if entity.force == force then return false end
  local hostile = false
  local ok = pcall(function() hostile = force.is_enemy and force.is_enemy(entity.force) end)
  if ok and hostile then return true end
  ok = pcall(function() hostile = entity.force.is_enemy and entity.force.is_enemy(force) end)
  if ok and hostile then return true end
  return entity.force ~= force
end

function tech_priests_0312_find_enemy(pair, radius)
  if not tech_priests_0312_valid_pair(pair) then return nil end
  local priest = pair.priest
  local old = pair.combat_target or pair.target
  if old and old.valid and tech_priests_0312_is_hostile(old, priest.force) then return old end
  if find_enemy_target then
    local ok, target = pcall(function() return find_enemy_target(pair.station, radius or tech_priests_0312_radius(pair), priest) end)
    if ok and target and target.valid then return target end
  end
  local found = nil
  local ok = pcall(function()
    found = priest.surface.find_entities_filtered({ position = priest.position, radius = radius or tech_priests_0312_radius(pair), type = { "unit", "unit-spawner", "turret", "spider-vehicle" }, limit = 64 })
  end)
  if ok and found then
    local best, best_d2 = nil, nil
    for _, e in pairs(found) do
      if e and e.valid and tech_priests_0312_is_hostile(e, priest.force) then
        local dx = (e.position.x or 0) - (priest.position.x or 0)
        local dy = (e.position.y or 0) - (priest.position.y or 0)
        local d2 = dx * dx + dy * dy
        if not best_d2 or d2 < best_d2 then best, best_d2 = e, d2 end
      end
    end
    return best
  end
  return nil
end

function tech_priests_0312_fire_laser(priest, target, damage, reason, color)
  if not (priest and priest.valid and target and target.valid) then return false end
  damage = math.max(1, damage or TECH_PRIESTS_0312_MINING_LASER_DAMAGE)
  color = color or { r = 0.95, g = 0.25, b = 0.05, a = 0.75 }
  local ok_damage = pcall(function()
    if target.valid and target.health and target.health > 0 then
      target.damage(damage, priest.force, "laser", priest)
    elseif target.valid and target.type == "resource" then
      local amount = target.amount or 0
      if amount > 1 then target.amount = math.max(1, amount - damage) end
    end
  end)
  if rendering then
    pcall(function()
      rendering.draw_line({ color = color, width = 2, from = priest.position, to = target.position, surface = priest.surface, time_to_live = 12, forces = { priest.force } })
    end)
    pcall(function()
      rendering.draw_circle({ color = { r = color.r or 1, g = color.g or 0.5, b = color.b or 0.1, a = 0.18 }, radius = 0.35, width = 1, filled = true, target = target, surface = priest.surface, time_to_live = 8, forces = { priest.force } })
    end)
  end
  if spawn_emergency_craft_smoke then
    pcall(function() spawn_emergency_craft_smoke({ priest = priest, station = nil }, target.position, false) end)
  elseif priest.surface and priest.surface.create_trivial_smoke then
    pcall(function() priest.surface.create_trivial_smoke({ name = "smoke-fast", position = target.position }) end)
  end
  return ok_damage
end

function tech_priests_0312_service_direct_current(pair, task)
  local cur = task and task.current or nil
  if not cur then return false end
  if cur.kind ~= "direct-mine-0273" and cur.kind ~= "direct-dirt-0273" then return false end
  if not tech_priests_0312_valid_pair(pair) then return false end
  local priest = pair.priest
  local pos = cur.position or (cur.entity and cur.entity.valid and cur.entity.position) or pair.station.position
  local dx = priest.position.x - pos.x
  local dy = priest.position.y - pos.y
  if dx * dx + dy * dy > (EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ or 2.25) then
    pcall(function()
      if tech_priests_request_movement_0418 then
        tech_priests_request_movement_0418(pair, pos, "legacy-direct-gather-0312", { radius = 0.75, owner = "direct-gather-0312", priority = 55, distraction = defines.distraction.by_enemy })
      else
        priest.set_command({ type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.by_enemy })
      end
    end)
    pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"
    return true
  end
  if not task.direct_due_tick_0312 then
    task.direct_due_tick_0312 = (game and game.tick or 0) + (TECH_PRIESTS_DIRECT_GATHER_TICKS_0273 or 60)
    task.direct_due_tick_0273 = task.direct_due_tick_0312
  end
  pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"

  local tick = game and game.tick or 0
  if cur.entity and cur.entity.valid then
    if draw_emergency_craft_scan_line then pcall(function() draw_emergency_craft_scan_line(pair, cur.entity) end) end
    if tick >= (task.next_direct_laser_tick_0312 or 0) then
      task.next_direct_laser_tick_0312 = tick + TECH_PRIESTS_0312_MINING_LASER_TICKS
      tech_priests_0312_fire_laser(priest, cur.entity, TECH_PRIESTS_0312_MINING_LASER_DAMAGE, "direct-mining", { r = 1.0, g = 0.45, b = 0.05, a = 0.75 })
    end
  elseif cur.position and spawn_emergency_craft_smoke and tick >= (task.next_direct_laser_tick_0312 or 0) then
    task.next_direct_laser_tick_0312 = tick + TECH_PRIESTS_0312_MINING_LASER_TICKS
    pcall(function() spawn_emergency_craft_smoke(pair, cur.position, false) end)
  end

  if tick < (task.direct_due_tick_0312 or task.direct_due_tick_0273 or tick) then return true end

  -- Final extraction: the laser does a slightly heavier finishing cut and then
  -- the existing emergency craft doctrine receives one unit of the requested output.
  if cur.entity and cur.entity.valid then
    local e = cur.entity
    tech_priests_0312_fire_laser(priest, e, math.max(10, TECH_PRIESTS_0312_MINING_LASER_DAMAGE * 3), "direct-mining-final", { r = 1.0, g = 0.65, b = 0.1, a = 0.95 })
    pcall(function()
      if e.valid and e.type == "resource" then
        local amount = e.amount or 0
        if amount > 1 then e.amount = math.max(1, amount - 25) else e.destroy() end
      elseif e.valid and e.health and e.health <= 1 then
        e.destroy()
      end
    end)
  end

  local output = cur.output_item or (tech_priests_0273_output_from_task and tech_priests_0273_output_from_task(task)) or task.item_name or task.output_item or "stone"
  if not tech_priests_0312_item_exists(output) then output = "stone" end
  if tech_priests_0273_deposit then
    pcall(function() tech_priests_0273_deposit(pair, output, 1) end)
  else
    local inv = get_station_inventory and get_station_inventory(pair.station) or pair.station.get_inventory(defines.inventory.chest)
    if inv and inv.can_insert({ name = output, count = 1 }) then inv.insert({ name = output, count = 1 }) end
  end
  pair.last_direct_mining_laser_0312 = { tick = tick, output = output, source = cur.item_name or (cur.entity and cur.entity.name) or cur.kind }
  pair.emergency_craft = nil
  pair.mode = "returning"
  pair.target = nil
  if return_to_station then pcall(function() return_to_station(priest, pair.station) end) end
  return true
end

TECH_PRIESTS_0312_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT = handle_emergency_desperation_craft
function handle_emergency_desperation_craft(pair)
  if pair and pair.emergency_craft and pair.emergency_craft.current and (pair.emergency_craft.current.kind == "direct-mine-0273" or pair.emergency_craft.current.kind == "direct-dirt-0273") then
    return tech_priests_0312_service_direct_current(pair, pair.emergency_craft)
  end
  return TECH_PRIESTS_0312_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT and TECH_PRIESTS_0312_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT(pair) or false
end

function tech_priests_0423_point_blank_laser_range()
  local pickup_sq = tonumber(EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ) or tonumber(TECH_PRIESTS_0315_MINING_LOCK_RADIUS_SQ) or 2.25
  local range = tonumber(TECH_PRIESTS_POINT_BLANK_LASER_RANGE) or math.sqrt(math.max(0.01, pickup_sq))
  return math.max(0.75, math.min(2.0, range))
end

function tech_priests_0312_fallback_combat_laser(pair, target, reason)
  if not tech_priests_0312_valid_pair(pair) then return false end
  target = (target and target.valid and target) or tech_priests_0312_find_enemy(pair, tech_priests_0312_radius(pair))
  if not (target and target.valid) then return false end

  local tick = game and game.tick or 0
  local priest = pair.priest
  local dx = (priest.position.x or 0) - (target.position.x or 0)
  local dy = (priest.position.y or 0) - (target.position.y or 0)
  local d2 = dx * dx + dy * dy
  local point_blank = tech_priests_0423_point_blank_laser_range()

  pair.task_kind = "combat"
  pair.target = target
  pair.combat_target = target
  pair.last_combat_fallback_0312 = { tick = tick, target = target.name, reason = reason or "no-ammo", dist_sq = d2, point_blank = point_blank }

  -- 0.1.423: the ammo-less combat laser is a desperate close-quarters cutter,
  -- not a 16-tile ranged weapon.  It uses the same near-point-blank band as
  -- direct mining.  If the priest is too far away, the movement controller owns
  -- approach; the laser does not fire until the priest is actually close.
  if d2 > point_blank * point_blank then
    pair.mode = "moving-to-laser-fallback"
    pair.next_fallback_laser_tick_0312 = math.max(pair.next_fallback_laser_tick_0312 or 0, tick + 10)
    if tech_priests_request_movement_0418 then
      pcall(function()
        tech_priests_request_movement_0418(pair, target.position, "fallback-combat-point-blank", {
          radius = math.max(0.55, point_blank * 0.65),
          owner = "fallback-combat-laser-0423",
          priority = 92,
          ttl = 60 * 4,
          distraction = defines and defines.distraction and defines.distraction.by_enemy or nil
        })
      end)
    elseif issue_priest_command then
      pcall(function()
        issue_priest_command(priest, { type = defines.command.go_to_location, destination = target.position, radius = math.max(0.55, point_blank * 0.65), distraction = defines.distraction.by_enemy })
      end)
    end
    return true
  end

  if tick < (pair.next_fallback_laser_tick_0312 or 0) then return true end
  pair.next_fallback_laser_tick_0312 = tick + TECH_PRIESTS_0312_FALLBACK_LASER_TICKS
  pair.mode = "defending-laser-fallback"
  tech_priests_0312_fire_laser(pair.priest, target, TECH_PRIESTS_0312_MINING_LASER_DAMAGE, "fallback-combat-point-blank", { r = 1.0, g = 0.15, b = 0.05, a = 0.75 })
  return true
end

TECH_PRIESTS_0312_PRE_PRIME_PROXY_ATTACK = tech_priests_0293_prime_proxy_attack
function tech_priests_0293_prime_proxy_attack(pair, target, reason)
  if tech_priests_0312_valid_pair(pair) and target and target.valid and not tech_priests_0312_has_ballistic_ammo(pair) then
    return tech_priests_0312_fallback_combat_laser(pair, target, reason or "proxy-no-ammo")
  end
  return TECH_PRIESTS_0312_PRE_PRIME_PROXY_ATTACK and TECH_PRIESTS_0312_PRE_PRIME_PROXY_ATTACK(pair, target, reason) or false
end

TECH_PRIESTS_0312_PRE_FORCE_COMBAT_TICK = tech_priests_0293_force_combat_tick
function tech_priests_0293_force_combat_tick(pair, reason, force)
  if tech_priests_0312_valid_pair(pair) and not tech_priests_0312_has_ballistic_ammo(pair) then
    local target = tech_priests_0312_find_enemy(pair, tech_priests_0312_radius(pair))
    if target and target.valid then
      return tech_priests_0312_fallback_combat_laser(pair, target, reason or "force-no-ammo")
    end
  end
  return TECH_PRIESTS_0312_PRE_FORCE_COMBAT_TICK and TECH_PRIESTS_0312_PRE_FORCE_COMBAT_TICK(pair, reason, force) or false
end
tech_priests_0292_force_combat_tick = tech_priests_0293_force_combat_tick

-- Preservation display polish: item-with-tags may or may not expose a visible
-- label in every Factorio context, so write every safe display field we can.
TECH_PRIESTS_0312_PRE_APPLY_RECORD_TO_STACK = tech_priests_0301_apply_record_to_stack
function tech_priests_0301_apply_record_to_stack(stack, record)
  local ok = TECH_PRIESTS_0312_PRE_APPLY_RECORD_TO_STACK and TECH_PRIESTS_0312_PRE_APPLY_RECORD_TO_STACK(stack, record) or false
  if stack and stack.valid_for_read and record then
    local display = record.station_display_name or (record.cell_name and ("Cogitator Station " .. tostring(record.cell_name))) or "Named Cogitator Station"
    local priest = record.priest_display_name or (record.cell_name and ("Tech-Priest " .. tostring(record.cell_name))) or "Linked Tech-Priest"
    pcall(function() stack.label = display end)
    pcall(function() stack.custom_description = display .. "\nLinked unit: " .. priest .. "\nPreserved cell: inventory and re-imprinting identity retained." end)
    pcall(function()
      local tags = stack.tags or {}
      tags[TECH_PRIESTS_PRESERVATION_TAG_0301] = record
      tags.display_name_0312 = display
      tags.priest_display_name_0312 = priest
      stack.tags = tags
    end)
  end
  return ok
end

TECH_PRIESTS_0312_DEBUG_COMMAND_RETIRED = true

tech_priests_0312_log("mining laser fallback weapon + preserved item display labels loaded")


-- ============================================================================
-- 0.1.313 Research-bonus doctrine; equipment-grid experiment abandoned.
-- ============================================================================
-- The scripted Cogitator sub-equipment grid proved to be the wrong abstraction:
-- it behaved like an inventory, fought the station inventory UI, and created
-- active-defense lifecycle crashes when priests died or re-imprinted.  From this
-- point the Cogitator Station has ONE meaningful storage surface: its normal
-- inventory.  Priest bonuses are force-wide research unlocks.

TECH_PRIESTS_PATCH_0313 = "0.1.313-research-bonuses-no-equipment-grid"

function tech_priests_0313_log(msg)
  if log then log("[Tech-Priests 0.1.313] " .. tostring(msg)) end
end

function tech_priests_0313_force_researched(force, tech_name)
  if not (force and tech_name) then return false end
  local ok, tech = pcall(function() return force.technologies and force.technologies[tech_name] end)
  return ok and tech and tech.researched == true
end

function tech_priests_0313_any_researched(force, names)
  for _, name in pairs(names or {}) do
    if tech_priests_0313_force_researched(force, name) then return true, name end
  end
  return false, nil
end

function tech_priests_0313_force_upgrade_profile(force)
  local exo, exo_tech = tech_priests_0313_any_researched(force, { "exoskeleton-equipment", "exoskeleton-mk2-equipment", "exoskeleton-mk3-equipment" })
  local battery, battery_tech = tech_priests_0313_any_researched(force, { "battery-equipment", "battery-mk2-equipment", "battery-mk3-equipment" })
  local pld, pld_tech = tech_priests_0313_any_researched(force, { "personal-laser-defense-equipment", "personal-laser-defense-mk2-equipment" })
  local belt, belt_tech = tech_priests_0313_any_researched(force, { "belt-immunity-equipment" })
  return {
    exoskeleton = exo,
    exoskeleton_tech = exo_tech,
    battery = battery,
    battery_tech = battery_tech,
    personal_laser_defense = pld,
    personal_laser_defense_tech = pld_tech,
    belt_immunity = belt,
    belt_immunity_tech = belt_tech,
    movement_speed_multiplier = exo and 1.35 or 1.0,
    mining_laser_damage = pld and 15 or 5,
    fallback_laser_damage = pld and 15 or 5,
    mining_laser_ticks = battery and 8 or 15,
    fallback_laser_ticks = battery and 15 or 30,
    mining_pulse_smoke = battery and 3 or 1
  }
end

function tech_priests_0313_global_upgrade_profile()
  local profile = {
    exoskeleton = false,
    battery = false,
    personal_laser_defense = false,
    belt_immunity = false,
    movement_speed_multiplier = 1.0,
    mining_laser_damage = 5,
    fallback_laser_damage = 5,
    mining_laser_ticks = 15,
    fallback_laser_ticks = 30,
    mining_pulse_smoke = 1
  }
  if game and game.forces then
    for _, force in pairs(game.forces) do
      local f = tech_priests_0313_force_upgrade_profile(force)
      profile.exoskeleton = profile.exoskeleton or f.exoskeleton
      profile.battery = profile.battery or f.battery
      profile.personal_laser_defense = profile.personal_laser_defense or f.personal_laser_defense
      profile.belt_immunity = profile.belt_immunity or f.belt_immunity
      profile.movement_speed_multiplier = math.max(profile.movement_speed_multiplier, f.movement_speed_multiplier or 1.0)
      profile.mining_laser_damage = math.max(profile.mining_laser_damage, f.mining_laser_damage or 5)
      profile.fallback_laser_damage = math.max(profile.fallback_laser_damage, f.fallback_laser_damage or 5)
      profile.mining_laser_ticks = math.min(profile.mining_laser_ticks, f.mining_laser_ticks or 15)
      profile.fallback_laser_ticks = math.min(profile.fallback_laser_ticks, f.fallback_laser_ticks or 30)
      profile.mining_pulse_smoke = math.max(profile.mining_pulse_smoke, f.mining_pulse_smoke or 1)
    end
  end
  return profile
end

function tech_priests_0313_refresh_research_bonuses(reason)
  local profile = tech_priests_0313_global_upgrade_profile()
  global = global or _G.global
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.research_bonuses_0313 = profile
  -- 0.1.312 functions read these globals at call-time, so the unified research
  -- profile can safely tune the existing mining/fallback laser cadence.
  TECH_PRIESTS_0312_MINING_LASER_DAMAGE = profile.mining_laser_damage
  TECH_PRIESTS_0312_MINING_LASER_TICKS = profile.mining_laser_ticks
  TECH_PRIESTS_0312_FALLBACK_LASER_TICKS = profile.fallback_laser_ticks
  storage.tech_priests.research_bonuses_0313_reason = reason or "refresh"
  storage.tech_priests.research_bonuses_0313_tick = game and game.tick or 0
  return profile
end

function tech_priests_0313_profile_for_pair(pair)
  if pair and pair.priest and pair.priest.valid and pair.priest.force then
    return tech_priests_0313_force_upgrade_profile(pair.priest.force)
  end
  if pair and pair.station and pair.station.valid and pair.station.force then
    return tech_priests_0313_force_upgrade_profile(pair.station.force)
  end
  return (storage and storage.tech_priests and storage.tech_priests.research_bonuses_0313) or tech_priests_0313_global_upgrade_profile()
end

-- 0.1.674-dev: final research-bonus equipment doctrine is integrated into
-- canonical 0305/0306. 0313 retains research policy helpers only.
TECH_PRIESTS_0313_EQUIPMENT_OVERRIDE_RETIRED = true
TECH_PRIESTS_0313_ACTIVE_DEFENSE_OVERRIDE_RETIRED = true
TECH_PRIESTS_0313_PERIODIC_ROUTE_RETIRED = true
TECH_PRIESTS_0313_DAMAGE_ROUTE_RETIRED = true
TECH_PRIESTS_0313_GUI_ROUTE_RETIRED = true

-- Make the glow sane after the daylight-visible aura test.  Keep mode colour,
-- but stop painting the whole screen like an overzealous saint projector.
TECH_PRIESTS_WHITE_GLOW_COLOR_0307 = { r = 1.0, g = 0.96, b = 0.86, a = 0.16 }
TECH_PRIESTS_GLOW_TTL_0307 = 28

function tech_priests_0313_soften_color(c)
  c = c or { r = 0.2, g = 1.0, b = 0.2, a = 0.25 }
  return { r = c.r or 0.2, g = c.g or 1.0, b = c.b or 0.2, a = math.min(0.22, (c.a or 0.5) * 0.25) }
end

TECH_PRIESTS_0313_GLOW_PREDECESSOR_CAPTURE_RETIRED = true

-- Faster/more emphatic mining pulses with impact smoke, but no laser-work on
-- loose item-on-ground stacks. They should simply be picked up by existing ground
-- stockpile acquisition.
TECH_PRIESTS_0313_PRE_FIRE_LASER = tech_priests_0312_fire_laser

-- Best-effort movement speed bonus. Unit prototypes do not expose a clean
-- per-force exoskeleton modifier, so this is intentionally conservative and
-- protected. If Factorio exposes LuaEntity.speed for this unit, it nudges it;
-- otherwise it records the bonus for later native use without crashing.
function tech_priests_0313_apply_pair_research_bonuses(pair)
  if not (pair and pair.priest and pair.priest.valid) then return end
  local profile = tech_priests_0313_force_upgrade_profile(pair.priest.force)
  pair.research_bonuses_0313 = profile
  if profile.exoskeleton then
    pcall(function()
      local current = pair.priest.speed or 0
      if current and current > 0 then pair.priest.speed = math.min(current * 1.08, current + 0.015) end
    end)
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(37, function()
  tech_priests_0313_refresh_research_bonuses("movement-service")
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  local processed = 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    tech_priests_0313_apply_pair_research_bonuses(pair)
    processed = processed + 1
    if processed >= 64 then break end
  end
end)

TechPriestsRuntimeEventRegistry.on_init(function() tech_priests_0313_refresh_research_bonuses("init") end)
TechPriestsRuntimeEventRegistry.on_configuration_changed(function() tech_priests_0313_refresh_research_bonuses("configuration-changed") end)

if defines and defines.events then
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_research_finished, function(event)
    tech_priests_0313_refresh_research_bonuses("research-finished:" .. tostring(event and event.research and event.research.name or "unknown"))
  end)
  if defines.events.on_technology_effects_reset then
    TechPriestsRuntimeEventRegistry.on_event(defines.events.on_technology_effects_reset, function(event)
      tech_priests_0313_refresh_research_bonuses("technology-effects-reset")
    end)
  end
end

TECH_PRIESTS_0313_DEBUG_COMMAND_RETIRED = true

tech_priests_0313_log("equipment-grid experiment disabled; station inventory only; research-unlocked priest bonuses active")


-- -----------------------------------------------------------------------------
-- 0.1.315 - movement-locked mining beam origin repair + glow clamp
-- -----------------------------------------------------------------------------
-- The direct mining beam was still being drawn by two different systems: the old
-- emergency scan line and the newer damage pulse.  This made the visible line and
-- the actual damage hit disagree.  This layer makes direct mining use one beam:
-- the damage beam.  It emits from the same raised priest origin as the scan line,
-- pulses faster, makes impact smoke at the target, and locks the priest in place
-- once he has reached the quarry target unless combat interrupts the task.

TECH_PRIESTS_PATCH_0315 = "0.1.316-mining-lockdown-unified-beam-local-limit-fix"
TECH_PRIESTS_0315_MINING_LOCK_RADIUS_SQ = 2.25
TECH_PRIESTS_0315_MINING_PULSE_TICKS = 5
TECH_PRIESTS_0315_MINING_FINISH_TICKS = 60
TECH_PRIESTS_0315_INTERRUPT_RADIUS = 2.25
TECH_PRIESTS_0315_BEAM_WIDTH = 2
TECH_PRIESTS_0315_MODE_GLOW_INTENSITY = 0.13
TECH_PRIESTS_0315_AMBIENT_GLOW_INTENSITY = 0.07

function tech_priests_0315_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.315] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.315] " .. tostring(msg))
  end
end

function tech_priests_0315_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0315_origin(priest)
  return { entity = priest, offset = TECH_PRIEST_SCAN_ORIGIN_OFFSET or { 0, -1.35 } }
end

function tech_priests_0315_target_position(target)
  if target and target.valid and target.position then return target.position end
  return target
end

function tech_priests_0315_destroy_render(obj)
  if tech_priests_0309_destroy_render_object then
    pcall(function() tech_priests_0309_destroy_render_object(obj) end)
    return
  end
  pcall(function() if obj and obj.valid and obj.destroy then obj.destroy() end end)
end

function tech_priests_0315_is_hostile_nearby(pair, radius)
  if not tech_priests_0315_valid_pair(pair) then return false end
  local priest = pair.priest
  local r = radius or TECH_PRIESTS_0315_INTERRUPT_RADIUS
  local found = nil
  local ok = pcall(function()
    found = priest.surface.find_entities_filtered({
      position = priest.position,
      radius = r,
      type = { "unit", "spider-unit", "spider-vehicle" },
      limit = 32
    })
  end)
  if not (ok and found) then return false end
  for _, e in pairs(found) do
    if e and e.valid and e.force and priest.force and e.force ~= priest.force then
      local hostile = false
      pcall(function() hostile = priest.force.is_enemy and priest.force.is_enemy(e.force) end)
      if hostile or e.force ~= priest.force then return true end
    end
  end
  return false
end

function tech_priests_0315_soft_color(c, a)
  c = c or { r = 0.3, g = 1.0, b = 0.25, a = 0.25 }
  return { r = c.r or 0.3, g = c.g or 1.0, b = c.b or 0.25, a = a or math.min(0.12, (c.a or 0.4) * 0.18) }
end

-- 0.1.674-dev: the final 0315 glow clamp is integrated into canonical 0307.
TECH_PRIESTS_0315_GLOW_OVERRIDE_RETIRED = true

-- Direct scan-line override: for actual mining/quarry/dirt current tasks, do not
-- draw the old decorative scan beam.  The damage pulse below is now the one beam
-- used for visible mining and impact.  Inventory scans can still use the softer
-- old amber line.
TECH_PRIESTS_0315_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE = draw_emergency_craft_scan_line
function draw_emergency_craft_scan_line(pair, target_entity)
  local cur = pair and pair.emergency_craft and pair.emergency_craft.current or nil
  if cur and (cur.kind == "direct-mine-0273" or cur.kind == "direct-dirt-0273") then
    return nil
  end
  if target_entity and target_entity.valid and target_entity.type == "item-entity" then
    return nil
  end
  if TECH_PRIESTS_0315_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE then
    return TECH_PRIESTS_0315_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE(pair, target_entity)
  end
end

function tech_priests_0315_effective_profile(force)
  if tech_priests_0313_force_upgrade_profile then
    local ok, profile = pcall(function() return tech_priests_0313_force_upgrade_profile(force) end)
    if ok and profile then return profile end
  end
  return { mining_laser_damage = TECH_PRIESTS_0312_MINING_LASER_DAMAGE or 5, mining_laser_ticks = TECH_PRIESTS_0315_MINING_PULSE_TICKS, mining_pulse_smoke = 2 }
end

-- Unified beam: one line, one source, one impact point, optional damage.  This is
-- used both by direct mining and by the no-ammo fallback weapon.
function tech_priests_0312_fire_laser(priest, target, damage, reason, color)
  if not (priest and priest.valid and target and target.valid) then return false end
  if target.type == "item-entity" then return false end
  local pos = tech_priests_0315_target_position(target)
  if not pos then return false end
  local force = priest.force
  local profile = tech_priests_0315_effective_profile(force)
  local d = math.max(1, damage or profile.mining_laser_damage or 5)
  color = color or { r = 1.0, g = 0.25, b = 0.05, a = 0.68 }

  local ok_damage = true
  pcall(function()
    if target.valid and target.type == "resource" then
      local amount = target.amount or 0
      if amount and amount > 1 then target.amount = math.max(1, amount - math.max(1, math.floor(d * 0.35))) end
    elseif target.valid and target.health and target.health > 0 then
      target.damage(d, force, "laser", priest)
    end
  end)

  if rendering and rendering.draw_line then
    pcall(function()
      rendering.draw_line({
        color = color,
        width = TECH_PRIESTS_0315_BEAM_WIDTH,
        from = tech_priests_0315_origin(priest),
        to = pos,
        surface = priest.surface,
        time_to_live = 7,
        forces = { force }
      })
    end)
    pcall(function()
      rendering.draw_circle({
        color = { r = color.r or 1, g = color.g or 0.4, b = color.b or 0.05, a = 0.24 },
        radius = 0.22,
        width = 1,
        filled = true,
        target = target,
        surface = priest.surface,
        time_to_live = 6,
        forces = { force }
      })
    end)
  end

  local smoke_count = math.max(2, profile.mining_pulse_smoke or 2)
  for i = 1, smoke_count do
    pcall(function()
      priest.surface.create_trivial_smoke({ name = "smoke-fast", position = { x = pos.x + (i - 1.5) * 0.07, y = pos.y + ((i % 2) - 0.5) * 0.08 } })
    end)
  end
  pcall(function() priest.surface.create_entity({ name = "spark-explosion", position = pos }) end)
  return ok_damage
end
