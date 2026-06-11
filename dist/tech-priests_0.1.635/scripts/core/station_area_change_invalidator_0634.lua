-- scripts/core/station_area_change_invalidator_0634.lua
-- Tech Priests 0.1.634
--
-- Event-driven freshness bridge for station catalogs, emergency supply state, and
-- logistics recognition. When the player/robot/scripts place or remove entities
-- near a station, or when the player directly inserts/removes items, stations in
-- that area must stop trusting old radar/catalog/emergency conclusions.

local M = {}
M.version = "0.1.634"
M.storage_key = "station_area_change_invalidator_0634"
M.radius_padding = 4
M.inventory_refresh_cooldown = 30
M.max_pairs_per_event = 24

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function dist_sq(a,b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, stats={}, recent={}, cooldowns={} }
  storage.tech_priests[M.storage_key] = r
  r.version=M.version
  if r.enabled == nil then r.enabled=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}; r.cooldowns=r.cooldowns or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(action, detail)
  local r=M.root(); stat(action)
  r.recent[#r.recent+1]={tick=now(), action=tostring(action or "event"), detail=tostring(detail or "")}
  while #r.recent>80 do table.remove(r.recent,1) end
end

local function runtime_radius(pair)
  local r=tonumber(pair and pair.radius) or tonumber(pair and pair.base_radius) or nil
  if type(_G.get_station_operating_radius)=="function" and valid(pair and pair.station) then local ok,got=pcall(_G.get_station_operating_radius,pair.station); if ok and tonumber(got) then r=tonumber(got) end end
  return math.max(8, tonumber(r) or 32)
end

local function clear_pair_state(pair, reason)
  if not valid_pair(pair) then return false end
  local su=station_unit(pair)
  local r=M.root()
  r.cooldowns[safe(su)] = now() + M.inventory_refresh_cooldown

  -- Force station catalog to rescan instead of reusing the clean 0570 snapshot.
  if storage and storage.tech_priests and storage.tech_priests.station_catalog_0327 then
    local catroot=storage.tech_priests.station_catalog_0327
    if catroot.next_scan then catroot.next_scan[su] = 0 end
    if catroot.stations then catroot.stations[su] = nil end
  end
  pair.known_resources_0326 = nil
  pair.known_resources_0327 = nil

  -- Clear common stale emergency/supply conclusions. These are conclusions, not
  -- durable orders; clearing them lets the dispatcher recalculate from inventory.
  pair.no_ammo_0295 = nil
  pair.needs_ammo_0295 = nil
  pair.need_ammo = nil
  pair.need_ammunition = nil
  pair.supply_blocker_0497 = nil
  pair.emergency_supply_shortage_0497 = nil
  pair.emergency_missing_item = nil
  pair.last_missing_item = nil
  pair.last_shortage_item = nil
  pair.logistic_requested_item = nil
  pair.active_supply_request = nil
  pair.station_area_dirty_0634 = { tick=now(), reason=tostring(reason or "area-change") }

  if type(_G.tech_priests_0575_invalidate_corridor_cache_for_pair)=="function" then pcall(_G.tech_priests_0575_invalidate_corridor_cache_for_pair,pair,"station-area-change-0634") end
  if type(_G.tech_priests_0327_scan_station_catalog)=="function" then pcall(_G.tech_priests_0327_scan_station_catalog,pair) end
  return true
end

function M.invalidate_near(surface, position, reason)
  local r=M.root()
  if r.enabled == false or not (surface and position) then return false end
  local changed=0
  for _, pair in pairs(pair_map()) do
    if changed >= M.max_pairs_per_event then break end
    if valid_pair(pair) and pair.station.surface == surface then
      local radius = runtime_radius(pair) + M.radius_padding
      if dist_sq(pair.station.position, position) <= radius * radius then
        if clear_pair_state(pair, reason) then changed=changed+1 end
      end
    end
  end
  if changed > 0 then record("station-area-invalidated-0634", "pairs="..safe(changed).." reason="..safe(reason)) end
  return changed > 0
end

local function entity_position(event)
  local e = event and (event.entity or event.created_entity or event.destination)
  if valid(e) then return e.surface, e.position end
  return nil, nil
end

function M.handle_entity_event(event, reason)
  local surface, pos = entity_position(event)
  if surface and pos then return M.invalidate_near(surface,pos,reason) end
  return false
end

function M.handle_player_inventory_event(event, reason)
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if player and player.valid and player.character and player.character.valid then
    return M.invalidate_near(player.character.surface, player.character.position, reason)
  end
  return false
end

local function install_events()
  if not (defines and defines.events) then return false end
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry=require("scripts.core.runtime_event_registry") end) end
  local function on_event(ids, handler, owner)
    if registry and type(registry.on_event)=="function" then registry.on_event(ids, handler, nil, {owner=owner, category="catalog", priority="last"}) elseif script and script.on_event then script.on_event(ids, handler) end
  end
  local build_events={}
  for _, name in ipairs({"on_built_entity","on_robot_built_entity","script_raised_built","script_raised_revive","on_entity_cloned"}) do if defines.events[name] then build_events[#build_events+1]=defines.events[name] end end
  if #build_events>0 then on_event(build_events,function(event) return M.handle_entity_event(event,"built/created") end,"station_area_change_invalidator_0634_build") end
  local remove_events={}
  for _, name in ipairs({"on_player_mined_entity","on_robot_mined_entity","on_entity_died","script_raised_destroy"}) do if defines.events[name] then remove_events[#remove_events+1]=defines.events[name] end end
  if #remove_events>0 then on_event(remove_events,function(event) return M.handle_entity_event(event,"removed/destroyed") end,"station_area_change_invalidator_0634_remove") end
  local inv_events={}
  for _, name in ipairs({"on_player_main_inventory_changed","on_player_cursor_stack_changed"}) do if defines.events[name] then inv_events[#inv_events+1]=defines.events[name] end end
  if #inv_events>0 then on_event(inv_events,function(event) return M.handle_player_inventory_event(event,"player-inventory-change") end,"station_area_change_invalidator_0634_inventory") end
  return true
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-area-invalidate-0634") end end)
  commands.add_command("tp-area-invalidate-0634", "Tech Priests 0.1.634: invalidate station area catalog/supply state near the player.", function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil
    local ok=false
    if player and player.valid and player.character and player.character.valid then ok=M.invalidate_near(player.character.surface, player.character.position, "manual-command") end
    if player and player.valid then player.print("[tp-area-invalidate-0634] invalidated="..safe(ok).." total="..safe(M.root().stats["station-area-invalidated-0634"] or 0)) end
  end)
end

function M.install()
  M.root()
  install_events()
  install_command()
  _G.TechPriestsStationAreaChangeInvalidator0634 = M
  if log then log("[Tech-Priests 0.1.634] station area change invalidator installed; built/removed/player inventory changes refresh nearby station catalogs and stale supply flags") end
  return true
end

return M