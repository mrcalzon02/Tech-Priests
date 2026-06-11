-- scripts/core/bootstrap_resource_governor_0637.lua
-- Tech Priests 0.1.637
--
-- Emergency bootstrap governor.  The legacy survival-ammo/repair blockers can
-- leave a station claiming emergency=true while the priority stack falls through
-- to idle or keeps issuing single-item, literal-only requests.  This module gives
-- early emergency mode a productive default: build a local reserve of raw basics
-- before trying to solve every higher-level item directly.

local M = {}
M.version = "0.1.637"
M.storage_key = "bootstrap_resource_governor_0637"
M.service_interval = 73
M.max_pairs = 12
M.reserve_floor = 36
M.log_interval = 600

local RAW_RESERVES = {
  { item = "iron-ore", name = "iron-ore", type = "resource" },
  { item = "copper-ore", name = "copper-ore", type = "resource" },
  { item = "coal", name = "coal", type = "resource" },
  { item = "stone", name = "stone", type = "resource" },
  { item = "wood", name = nil, type = "tree" },
}

local CRITICAL_CLEAR = { "firearm-magazine", "repair-pack", "sacred-machine-oil" }

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and pair.station and pair.station.valid and pair.station.unit_number or nil end
local function priest_unit(pair) return pair and pair.priest and pair.priest.valid and pair.priest.unit_number or nil end
local function dist_sq(a,b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, stats={}, recent={}, last_log={} }
  storage.tech_priests[M.storage_key] = r
  r.version=M.version
  if r.enabled == nil then r.enabled=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}; r.last_log=r.last_log or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(action, pair, detail, force)
  local r=M.root(); action=tostring(action or "event"); stat(action)
  local ev={tick=now(), action=action, station=safe(station_unit(pair)), priest=safe(priest_unit(pair)), detail=tostring(detail or "")}
  r.recent[#r.recent+1]=ev
  while #r.recent>90 do table.remove(r.recent,1) end
  local key=action..":"..ev.station
  local last=tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now()-last >= M.log_interval then
    r.last_log[key]=now()
    if log then log("[Tech-Priests 0.1.637] "..action.." station="..ev.station.." priest="..ev.priest.." "..safe(detail)) end
  end
end

local function safe_inventory(entity, id)
  if not (valid(entity) and entity.get_inventory and id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function station_inventories(pair)
  local out = {}
  if not (valid_pair(pair) and defines and defines.inventory) then return out end
  for _, id in ipairs({ defines.inventory.chest, defines.inventory.assembling_machine_input, defines.inventory.assembling_machine_output, defines.inventory.furnace_source, defines.inventory.furnace_result, defines.inventory.fuel }) do
    local inv = safe_inventory(pair.station, id)
    if inv then out[#out+1]=inv end
  end
  return out
end

local function station_count(pair, item)
  local n = 0
  for _, inv in ipairs(station_inventories(pair)) do
    local ok, c = pcall(function() return inv.get_item_count(item) end)
    if ok then n = n + (tonumber(c) or 0) end
  end
  return n
end

local function emergencyish(pair)
  if not pair then return false end
  local mode = lower(pair.mode or "")
  if mode:find("emergency",1,true) or mode:find("resource%-doctrine",1,false) or mode:find("direct%-acquisition",1,false) then return true end
  local op = pair.independent_emergency_operation_0184 or pair.emergency_operation
  if type(op)=="table" then
    local phase = lower(op.phase or "")
    local blocker = lower(op.last_blocker_0264 or op.last_blocker_0266 or op.last_blocker_0267 or op.blocker or "")
    if phase:find("survival",1,true) or blocker:find("station lacks",1,true) then return true end
  end
  if pair.active_supply_request or pair.supply_request or pair.emergency_craft or pair.direct_acquisition_task_0336 then return true end
  return false
end

local function current_direct_task(pair)
  if not pair then return nil, nil, nil end
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair[key]
    local cur = type(task)=="table" and (task.current or task) or nil
    local kind = cur and tostring(cur.kind or "") or ""
    if kind == "direct-mine-0273" or kind == "direct-dirt-0273" or kind == "dirt" or kind == "direct-mine-0336" then return task, cur, key end
  end
  return nil,nil,nil
end

local function same_bootstrap_task(pair, item)
  local task, cur = current_direct_task(pair)
  if not (task and cur) then return false end
  local out = cur.output_item or cur.item_name or cur.wanted_item or task.output_item or task.item_name
  if out == item and (task.bootstrap_resource_0637 or cur.bootstrap_resource_0637) then return true end
  return false
end

local function operating_radius(pair)
  local r = tonumber(pair and pair.radius) or tonumber(pair and pair.base_radius) or 36
  if type(_G.get_station_operating_radius)=="function" then local ok, got = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(got) then r=tonumber(got) end end
  return math.max(12, r)
end

local function find_nearest_source(pair, spec)
  if not (valid_pair(pair) and pair.station.surface) then return nil end
  local r = operating_radius(pair)
  local opts = { position=pair.station.position, radius=r, force=pair.station.force }
  if spec.type == "resource" then opts.type = "resource"; opts.name = spec.name end
  if spec.type == "tree" then opts.type = "tree" end
  local ok, ents = pcall(function() return pair.station.surface.find_entities_filtered(opts) end)
  if not ok or not ents then return nil end
  local best, bestd = nil, nil
  for _, e in pairs(ents) do
    if valid(e) then
      local d = dist_sq(e.position, pair.station.position)
      if (not bestd) or d < bestd then best, bestd = e, d end
    end
  end
  return best
end

local function missing_reserve(pair)
  for _, spec in ipairs(RAW_RESERVES) do
    if prototypes and prototypes.item and prototypes.item[spec.item] then
      local have = station_count(pair, spec.item)
      if have < M.reserve_floor then return spec, have, M.reserve_floor - have end
    end
  end
  return nil,nil,nil
end

local function clear_stale_critical(pair)
  if not valid_pair(pair) then return false end
  local changed = false
  for _, item in ipairs(CRITICAL_CLEAR) do
    if station_count(pair, item) >= 1 then
      local op = pair.independent_emergency_operation_0184 or pair.emergency_operation
      if type(op)=="table" and (op.last_item == item or lower(op.phase or ""):find("survival",1,true)) then
        op.last_blocker_0264=nil; op.last_blocker_0266=nil; op.last_blocker_0267=nil; op.blocker=nil
        op.satisfied_item_0637=item; op.satisfied_tick_0637=now()
        if lower(op.phase or ""):find("survival",1,true) then op.phase="survival-satisfied" end
        changed = true
      end
      if pair.logistic_requested_item == item then pair.logistic_requested_item=nil; pair.logistic_requested_count=nil; changed=true end
      if pair.active_supply_request and tostring(pair.active_supply_request.item or pair.active_supply_request.item_name or pair.active_supply_request.kind or "") == item then pair.active_supply_request=nil; changed=true end
      if pair.supply_request and tostring(pair.supply_request.item or pair.supply_request.item_name or pair.supply_request.kind or "") == item then pair.supply_request=nil; changed=true end
    end
  end
  if changed then record("bootstrap-cleared-stale-critical-0637", pair, "station already holds critical reserve", true) end
  return changed
end

local function assign_direct(pair, spec, have, deficit)
  if same_bootstrap_task(pair, spec.item) then return false, "already-bootstrap" end
  local source = find_nearest_source(pair, spec)
  if not source then return false, "no-source-"..spec.item end
  local need = math.max(1, math.min(12, tonumber(deficit) or 1))
  local cur = { kind="direct-mine-0336", entity=source, output_item=spec.item, item_name=spec.item, requested_item=spec.item, bootstrap_resource_0637=true }
  local task = { kind="direct-mine-0336", current=cur, output_item=spec.item, item_name=spec.item, requested_item=spec.item, required_count=need, count=need, gathered_units=0, bootstrap_resource_0637=true, started_tick=now(), reason="bootstrap-resource-governor-0637" }
  pair.emergency_craft = task
  pair.direct_acquisition_task_0336 = task
  pair.active_acquisition_0333 = nil
  pair.mode = "bootstrap-resource-acquisition-0637"
  pair.bootstrap_mode_0637 = { tick=now(), item=spec.item, have=have or 0, floor=M.reserve_floor, source=source.name }
  local op = pair.independent_emergency_operation_0184 or pair.emergency_operation
  if type(op)=="table" then
    op.phase="bootstrap-reserve"
    op.last_item=spec.item
    op.last_blocker_0264="bootstrap reserve "..spec.item.." "..tostring(have or 0).."/"..tostring(M.reserve_floor)
  end
  record("bootstrap-assigned-direct-0637", pair, "item="..spec.item.." have="..safe(have).." need="..safe(need).." source="..safe(source.name), true)
  local okD, Direct = pcall(require, "scripts.core.direct_acquisition_executor_0513")
  if okD and Direct and type(Direct.service_pair)=="function" then pcall(Direct.service_pair, pair, "bootstrap-resource-governor-0637") end
  return true, "assigned"
end

function M.service_pair(pair, reason)
  local root=M.root(); if root.enabled==false then return false,"disabled" end
  if not valid_pair(pair) then return false,"invalid" end
  clear_stale_critical(pair)
  if not emergencyish(pair) then return false,"not-emergencyish" end
  local spec, have, deficit = missing_reserve(pair)
  if not spec then
    pair.bootstrap_mode_0637 = { tick=now(), state="reserve-satisfied", floor=M.reserve_floor }
    stat("bootstrap-reserve-satisfied-0637")
    return false,"reserve-satisfied"
  end
  local task, cur = current_direct_task(pair)
  if task and cur and not (task.bootstrap_resource_0637 or cur.bootstrap_resource_0637) then
    stat("bootstrap-yielded-active-direct-0637")
    return false,"active-direct-present"
  end
  return assign_direct(pair, spec, have, deficit)
end

function M.service_all(reason)
  local root=M.root(); if root.enabled==false then return 0 end
  local n=0
  for _, pair in pairs(pair_map()) do
    if n >= M.max_pairs then break end
    if valid_pair(pair) then pcall(M.service_pair, pair, reason or "pulse"); n=n+1 end
  end
  return n
end

local function selected_pair(player)
  local selected = player and player.selected
  if selected and selected.valid and _G.find_pair_for_entity then local ok,pair=pcall(_G.find_pair_for_entity,selected); if ok and pair then return pair end end
  for _, pair in pairs(pair_map()) do if valid_pair(pair) and (pair.station==selected or pair.priest==selected) then return pair end end
  return nil
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-bootstrap-0637") end end)
  commands.add_command("tp-bootstrap-0637", "Tech Priests 0.1.637: bootstrap reserve governor. Params: status/all/on/off/kick", function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil
    local p=lower(event and event.parameter or "status")
    local r=M.root()
    if p=="on" then r.enabled=true elseif p=="off" then r.enabled=false elseif p=="all" then M.service_all("command-all") elseif p=="kick" then local pair=selected_pair(player); if pair then M.service_pair(pair,"command-kick") end end
    local msg="[tp-bootstrap-0637] enabled="..safe(r.enabled).." assigned="..safe(r.stats["bootstrap-assigned-direct-0637"] or 0).." cleared="..safe(r.stats["bootstrap-cleared-stale-critical-0637"] or 0).." yielded="..safe(r.stats["bootstrap-yielded-active-direct-0637"] or 0).." satisfied="..safe(r.stats["bootstrap-reserve-satisfied-0637"] or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  install_command()
  _G.TechPriestsBootstrapResourceGovernor0637 = M
  local R=rawget(_G,"TechPriestsRuntimeEventRegistry")
  if R and type(R.on_nth_tick)=="function" then R.on_nth_tick(M.service_interval,function() M.service_all("nth-tick") end,{owner="bootstrap_resource_governor_0637",category="emergency",priority="early"})
  elseif script and script.on_nth_tick then script.on_nth_tick(M.service_interval,function() M.service_all("nth-tick") end) end
  if log then log("[Tech-Priests 0.1.637] bootstrap resource governor installed; emergency survival blockers build raw reserve before higher-level loops") end
  return true
end

return M