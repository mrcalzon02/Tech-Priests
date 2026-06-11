-- scripts/core/efficiency_economy_0572.lua
-- Tech Priests 0.1.572 unobserved transit economy.
--
-- This is a governor over the existing movement request API, not a new task
-- controller.  When no player can see a Tech-Priest or his destination, and the
-- requested work destination is inside the owning station's operating radius,
-- the visible walk command is replaced with a same-surface teleport.  The work
-- executor still owns the actual repair/consecration/mining/logistics action.

local M = {}
M.version = "0.1.572"
M.storage_key = "efficiency_economy_0572"

M.observation_radius = 96
M.teleport_search_radius = 3.0
M.teleport_search_precision = 0.25
M.station_radius_pad = 2.0
M.cooldown_ticks = 30

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function dist_sq(a,b)
  if not (a and b) then return 1/0 end
  local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0)
  return dx*dx+dy*dy
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = { version=M.version, enabled=true, stats={}, recent={}, pair_cooldown={} }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.pair_cooldown = r.pair_cooldown or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root()
  r.recent[#r.recent+1] = { tick=now(), action=tostring(action or "event"), detail=tostring(detail or "") }
  while #r.recent > 40 do table.remove(r.recent, 1) end
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function pair_key(pair)
  local u = station_unit(pair)
  if u then return tostring(u) end
  if pair and valid(pair.priest) and pair.priest.unit_number then return "p"..tostring(pair.priest.unit_number) end
  return nil
end

local function operating_radius(pair)
  local r = tonumber(pair and (pair.radius or pair.scan_radius or pair.station_radius)) or nil
  if (not r) and pair and valid(pair.station) and _G.get_station_operating_radius then
    local ok, got = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(got) then r = tonumber(got) end
  end
  return math.max(8, math.min(256, tonumber(r) or 32))
end

local function is_space_pair(pair)
  if _G.tech_priests_pair_on_space_platform_0204 then
    local ok, result = pcall(_G.tech_priests_pair_on_space_platform_0204, pair)
    if ok and result then return true end
  end
  return false
end

local function same_surface(pair, destination)
  return pair and valid(pair.station) and valid(pair.priest)
    and pair.station.surface == pair.priest.surface
    and destination and pair.station.surface
end

local function inside_station_radius(pair, destination)
  if not same_surface(pair, destination) then return false end
  local r = operating_radius(pair) + M.station_radius_pad
  return dist_sq(pair.station.position, destination) <= r*r
end

local function hostile_or_visible_reason(reason, opts)
  local s = lower(reason) .. " " .. lower(opts and opts.owner)
  if s:find("combat",1,true) or s:find("enemy",1,true) or s:find("attack",1,true) then return true end
  if s:find("retreat",1,true) or s:find("flee",1,true) or s:find("panic",1,true) then return true end
  if s:find("conversation",1,true) or s:find("player",1,true) or s:find("follow",1,true) then return true end
  return false
end

local function player_can_observe_position(player, surface, pos, radius_sq)
  if not (player and player.valid and surface and pos) then return false end
  if player.surface ~= surface then return false end
  local ppos = player.position
  if not ppos then return false end
  return dist_sq(ppos, pos) <= radius_sq
end

local function observed_by_any_player(pair, destination)
  if not (game and game.connected_players and pair and valid(pair.station) and valid(pair.priest)) then return false end
  local surface = pair.station.surface
  local radius_sq = M.observation_radius * M.observation_radius
  for _, player in pairs(game.connected_players) do
    if player and player.valid and player.surface == surface then
      -- Treat direct proximity to the priest, the destination, or the owning
      -- station as observation.  In remote-view contexts Factorio presents the
      -- player's current viewed surface/position through player.surface/position,
      -- so this also catches map/remote inspection in practice.
      if player_can_observe_position(player, surface, pair.priest.position, radius_sq)
        or player_can_observe_position(player, surface, destination, radius_sq)
        or player_can_observe_position(player, surface, pair.station.position, radius_sq) then
        return true
      end
      local sel = player.selected
      if sel and sel.valid and (sel == pair.priest or sel == pair.station) then return true end
    end
  end
  return false
end

local function stop_priest(priest)
  if not (valid(priest) and defines and defines.command) then return end
  pcall(function()
    if priest.commandable and priest.commandable.valid then priest.commandable.set_command({ type = defines.command.stop }) end
  end)
  pcall(function() if priest.set_command then priest.set_command({ type = defines.command.stop }) end end)
  pcall(function() priest.walking_state = { walking=false } end)
end

local function clear_movement_request(pair)
  pair.movement_request_0418 = nil
  pair.movement_controller_state_0418 = "unobserved-transit-complete"
  pair.movement_controller_clamp_0418 = nil
  pair.movement_controller_reason_0418 = "unobserved-transit-0572"
  local root = storage and storage.tech_priests and storage.tech_priests.movement_controller_0419 or nil
  local key = pair_key(pair)
  if root and root.requests and key then root.requests[key] = nil end
end

local function find_teleport_position(pair, destination, radius)
  local surface = pair.station.surface
  local priest = pair.priest
  local pos = { x = destination.x, y = destination.y }
  if surface and surface.find_non_colliding_position and valid(priest) then
    local ok, found = pcall(function()
      return surface.find_non_colliding_position(priest.name, pos, M.teleport_search_radius, M.teleport_search_precision)
    end)
    if ok and found then return found end
  end
  return pos
end

local function align_proxy(pair)
  if not pair then return end
  if _G.tech_priests_align_proxy_to_priest_0430 and valid(pair.proxy) and valid(pair.priest) then
    pcall(_G.tech_priests_align_proxy_to_priest_0430, pair, pair.proxy, pair.priest, "unobserved-transit-0572")
  elseif valid(pair.proxy) and valid(pair.priest) then
    pcall(function() pair.proxy.teleport(pair.priest.position) end)
  end
end

local function maybe_unobserved_transit(pair, destination, reason, opts)
  local r = M.root()
  if r.enabled == false then return false, "disabled" end
  if not (pair and valid(pair.station) and valid(pair.priest) and destination and destination.x and destination.y) then return false, "invalid" end
  if is_space_pair(pair) then stat("skip_space"); return false, "space-pair" end
  if hostile_or_visible_reason(reason, opts) then stat("skip_hostile_reason"); return false, "hostile-or-visible-reason" end
  if not inside_station_radius(pair, destination) then stat("skip_outside_station_radius"); return false, "outside-station-radius" end
  if observed_by_any_player(pair, destination) then stat("skip_observed"); return false, "observed" end

  local key = pair_key(pair)
  if key and r.pair_cooldown[key] and r.pair_cooldown[key] > now() then
    stat("skip_cooldown")
    return false, "cooldown"
  end

  local pos = find_teleport_position(pair, destination, opts and opts.radius or nil)
  if not pos then stat("skip_no_position"); return false, "no-position" end
  local ok = false
  pcall(function() ok = pair.priest.teleport(pos) == true end)
  if ok then
    stop_priest(pair.priest)
    clear_movement_request(pair)
    align_proxy(pair)
    pair.last_unobserved_transit_0572 = {
      tick = now(), x = pos.x, y = pos.y, requested_x = destination.x, requested_y = destination.y,
      reason = tostring(reason or (opts and opts.owner) or "movement"), station = station_unit(pair), radius = operating_radius(pair)
    }
    if key then r.pair_cooldown[key] = now() + M.cooldown_ticks end
    stat("teleports")
    remember("teleport", "station="..safe(station_unit(pair)).." reason="..safe(reason).." pos="..string.format("%.1f,%.1f", pos.x or 0, pos.y or 0))
    return true, "teleported"
  end
  stat("teleport_failed")
  return false, "teleport-failed"
end

local function wrap_movement_request()
  if type(_G.tech_priests_request_movement_0418) ~= "function" then return false end
  if _G.TECH_PRIESTS_0572_PRE_REQUEST_MOVEMENT then return false end
  _G.TECH_PRIESTS_0572_PRE_REQUEST_MOVEMENT = _G.tech_priests_request_movement_0418
  _G.tech_priests_request_movement_0418 = function(pair, destination, reason, opts)
    local ok, result = pcall(maybe_unobserved_transit, pair, destination, reason, opts or {})
    if ok and result == true then return true end
    return _G.TECH_PRIESTS_0572_PRE_REQUEST_MOVEMENT(pair, destination, reason, opts)
  end
  remember("wrap-movement", "unobserved transit installed")
  return true
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0572") end end)
  commands.add_command("tp-efficiency-economy-0572", "Tech Priests 0.1.572 unobserved transit economy. Params: on/off/status", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r = M.root()
    if param == "on" then r.enabled = true elseif param == "off" then r.enabled = false end
    local msg = "[tp-efficiency-economy-0572] enabled="..safe(r.enabled).." teleports="..safe(r.stats.teleports or 0).." observed_skips="..safe(r.stats.skip_observed or 0).." radius_skips="..safe(r.stats.skip_outside_station_radius or 0).." hostile_skips="..safe(r.stats.skip_hostile_reason or 0).." failed="..safe(r.stats.teleport_failed or 0)
    if player and player.valid then
      player.print(msg)
      for i=math.max(1,#r.recent-5),#r.recent do local rec=r.recent[i]; if rec then player.print("  ["..safe(rec.tick).."] "..safe(rec.action).." "..safe(rec.detail)) end end
    elseif log then log(msg) end
  end)
end

function M.install()
  M.root()
  wrap_movement_request()
  install_command()
  if log then log("[Tech-Priests 0.1.572] unobserved transit economy installed; offscreen in-radius work travel may teleport instead of pathing") end
  return true
end

return M
