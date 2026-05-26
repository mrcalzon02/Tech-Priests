-- scripts/core/obstacle_attack_guard_0584.lua
-- Tech Priests 0.1.584 obstacle slap-fight guard.
--
-- Priests sometimes inherit Factorio unit behavior while walking and begin
-- physically attacking a tree/rock/neutral obstruction with their weak unit
-- melee attack.  This module does not choose new work.  It watches existing
-- movement/work orders, detects neutral obstruction attack commands, stops the
-- pointless fistfight, and performs a budgeted obstruction-clearing pulse before
-- allowing the existing movement/executor stack to resume.

local M = {}
M.version = "0.1.584"
M.storage_key = "obstacle_attack_guard_0584"
M.service_interval = 17
M.max_pairs_per_pulse = 12
M.max_clears_per_pulse = 4
M.min_same_target_ticks = 45
M.clear_damage = 250
M.clear_damage_final = 500
M.log_interval = 1800

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) if not (a and b) then return nil end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function dist(a,b) local d2=dist_sq(a,b); return d2 and math.sqrt(d2) or nil end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = { version=M.version, enabled=true, clear_obstacles=true, stats={}, recent={}, last_log={}, cursor=0, active={} }
    storage.tech_priests[M.storage_key] = r
  end
  r.version=M.version
  if r.enabled == nil then r.enabled=true end
  if r.clear_obstacles == nil then r.clear_obstacles=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}; r.last_log=r.last_log or {}; r.active=r.active or {}; r.cursor=tonumber(r.cursor or 0) or 0
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(action, pair, detail, force)
  local r=M.root(); action=tostring(action or "event")
  stat(action)
  local rec={tick=now(), action=action, station=station_unit(pair), priest=priest_unit(pair), detail=tostring(detail or "")}
  r.recent[#r.recent+1]=rec; while #r.recent>80 do table.remove(r.recent,1) end
  local key=action..":"..safe(rec.station)..":"..safe(rec.priest)
  local last=tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now()-last >= M.log_interval then
    r.last_log[key]=now()
    if log then log("[Tech-Priests 0.1.584] "..action.." station="..safe(rec.station).." priest="..safe(rec.priest).." "..safe(detail)) end
  end
  return rec
end

local function stop_priest(pair, reason)
  if not valid_pair(pair) then return false end
  pcall(function()
    if pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command({ type=defines.command.stop })
    elseif pair.priest.set_command then pair.priest.set_command({ type=defines.command.stop }) end
  end)
  pair.movement_controller_clamp_0418 = tostring(reason or "obstacle-attack-guard-0584")
  pair.obstacle_attack_guard_until_0584 = now() + 90
  return true
end

local function get_command(priest)
  if not valid(priest) then return nil end
  local cmd=nil
  pcall(function() if priest.commandable and priest.commandable.valid then cmd = priest.commandable.command end end)
  if not cmd then pcall(function() cmd = priest.command end) end
  return type(cmd)=="table" and cmd or nil
end

local function command_target(cmd)
  if type(cmd)~="table" then return nil end
  local t = cmd.target or cmd.target_entity
  if valid(t) then return t end
  return nil
end

local function is_attack_command(cmd)
  return cmd and defines and defines.command and cmd.type == defines.command.attack
end

local function is_real_enemy(pair, entity)
  if not (valid_pair(pair) and valid(entity) and entity.force and pair.station.force) then return false end
  if entity.force == pair.station.force then return false end
  local ok, ce = pcall(function() return pair.station.force.get_cease_fire(entity.force) end)
  if ok and ce then return false end
  local ok2, friend = pcall(function() return pair.station.force.get_friend(entity.force) end)
  if ok2 and friend then return false end
  local name=lower(entity.force and entity.force.name)
  if name == "neutral" then return false end
  return true
end

local obstacle_types = {
  ["tree"] = true,
  ["simple-entity"] = true,
  ["simple-entity-with-owner"] = true,
  ["resource"] = true,
  ["cliff"] = true,
}

local function is_obstacle(pair, entity)
  if not (valid_pair(pair) and valid(entity)) then return false end
  if is_real_enemy(pair, entity) then return false end
  if obstacle_types[entity.type] then return true end
  local n = lower(entity.name)
  if n:find("tree",1,true) or n:find("rock",1,true) or n:find("boulder",1,true) or n:find("stone",1,true) then return true end
  return false
end

local function movement_context(pair)
  if not pair then return false end
  local mode=lower(pair.mode).." "..lower(pair.movement_controller_reason_0418).." "..lower(pair.movement_controller_state_0418)
  if mode:find("combat",1,true) or mode:find("retreat",1,true) or mode:find("defend",1,true) then return false end
  if pair.movement_request_0418 or pair.movement_lease_0518 or pair.move_target or pair.pathing_target_0418 then return true end
  if mode:find("travel",1,true) or mode:find("moving",1,true) or mode:find("acquisition",1,true) or mode:find("returning",1,true) then return true end
  if pair.emergency_craft and pair.emergency_craft.current then return true end
  return false
end

local function target_allowed(pair, entity)
  if not (valid_pair(pair) and valid(entity)) then return false end
  if entity.surface ~= pair.priest.surface then return false end
  if type(_G.tech_priests_0574_position_allowed) == "function" then
    local ok, allowed = pcall(_G.tech_priests_0574_position_allowed, pair, entity.position, "obstacle-clear-0584", { owner="obstacle-attack-guard-0584" })
    if ok and allowed == false then return false end
  end
  return true
end

local function mark_dirty_near(entity)
  if not valid(entity) then return end
  pcall(function()
    if type(_G.tech_priests_0579_mark_dirty_entity) == "function" then _G.tech_priests_0579_mark_dirty_entity(entity, "obstacle-clear-0584") end
  end)
  pcall(function()
    if type(_G.tech_priests_0580_mark_dirty_entity) == "function" then _G.tech_priests_0580_mark_dirty_entity(entity, "obstacle-clear-0584") end
  end)
end

local function inventory_for_pair(pair)
  if not valid_pair(pair) then return nil end
  local inv=nil
  pcall(function() inv = pair.station.get_inventory and pair.station.get_inventory(defines.inventory.chest) end)
  if inv and inv.valid then return inv end
  pcall(function() inv = pair.priest.get_main_inventory and pair.priest.get_main_inventory() end)
  if inv and inv.valid then return inv end
  return nil
end

function M.clear_obstacle(pair, entity, reason)
  local r=M.root()
  if r.clear_obstacles == false then return false end
  if not (valid_pair(pair) and valid(entity) and target_allowed(pair, entity)) then return false end
  local key=safe(station_unit(pair))..":"..safe(priest_unit(pair))..":"..safe(entity.unit_number or entity.name)..":"..safe(entity.position.x)..","..safe(entity.position.y)
  local a=r.active[key]
  if type(a)=="table" and a.target == entity and now() - (tonumber(a.tick or 0) or 0) < M.min_same_target_ticks then
    stat("same_obstacle_cooldown")
    return true
  end
  r.active[key]={tick=now(), target=entity, entity_unit=entity.unit_number, name=entity.name}
  stop_priest(pair, "obstacle-clear-0584")
  pair.obstacle_clear_target_0584 = entity
  pair.obstacle_clear_started_0584 = now()
  pair.obstacle_clear_reason_0584 = tostring(reason or "attack-command")

  local mined=false
  local inv=inventory_for_pair(pair)
  if entity.type ~= "resource" and inv then
    pcall(function() mined = entity.mine{inventory=inv, force=pair.station.force, raise_destroyed=true} end)
    if not mined then pcall(function() mined = entity.mine{inventory=inv} end) end
  end
  if not mined and valid(entity) then
    pcall(function() entity.damage(M.clear_damage, pair.station.force, "impact", pair.priest) end)
    if valid(entity) and entity.health and entity.health > 0 then pcall(function() entity.damage(M.clear_damage_final, pair.station.force, "explosion", pair.priest) end) end
  end
  mark_dirty_near(entity)
  record("obstacle-clear-0584", pair, "target="..safe(entity.name).." type="..safe(entity.type).." reason="..safe(reason))
  return true
end

function M.service_pair(pair)
  if M.root().enabled == false or not valid_pair(pair) then return false end
  if not movement_context(pair) then return false end
  local cmd=get_command(pair.priest)
  if not is_attack_command(cmd) then return false end
  local target=command_target(cmd)
  if not is_obstacle(pair, target) then return false end
  return M.clear_obstacle(pair, target, "unit-attack-during-move")
end

function M.service_all()
  local r=M.root(); if r.enabled == false then return end
  local pairs_list={}
  for _, pair in pairs(pair_map()) do if valid_pair(pair) then pairs_list[#pairs_list+1]=pair end end
  local n=#pairs_list; if n==0 then return end
  local processed=0; local cleared=0
  local start=(r.cursor % n)+1
  for i=0,n-1 do
    if processed >= M.max_pairs_per_pulse or cleared >= M.max_clears_per_pulse then break end
    local idx=((start+i-1)%n)+1
    processed=processed+1
    if M.service_pair(pairs_list[idx]) then cleared=cleared+1 end
  end
  r.cursor=(start+processed-1)%n
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-obstacle-guard-0584") end end)
  commands.add_command("tp-obstacle-guard-0584", "Tech Priests 0.1.584 obstacle slap-fight guard. Params: on/off/status/clear", function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil
    local param=lower(event and event.parameter or "status")
    local r=M.root()
    if param=="on" then r.enabled=true elseif param=="off" then r.enabled=false elseif param=="clear" then r.recent={}; r.stats={}; r.active={} end
    local msg="[tp-obstacle-guard-0584] enabled="..safe(r.enabled).." clears="..safe(r.stats["obstacle-clear-0584"] or 0).." cooldown="..safe(r.stats.same_obstacle_cooldown or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  _G.TECH_PRIESTS_OBSTACLE_ATTACK_GUARD_0584 = M
  install_command()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry=require("scripts.core.runtime_event_registry") end) end
  if registry and type(registry.on_nth_tick)=="function" then
    registry.on_nth_tick(M.service_interval, function() M.service_all() end, { owner="obstacle_attack_guard_0584", category="movement", priority="last", note="stop movement-related neutral obstacle slap-fights" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.service_interval, function() M.service_all() end)
  end
  record("install", nil, "obstacle attack guard installed", true)
  if log then log("[Tech-Priests 0.1.584] obstacle attack guard installed") end
  return true
end

return M
