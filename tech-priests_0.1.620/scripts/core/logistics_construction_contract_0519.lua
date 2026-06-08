-- scripts/core/logistics_construction_contract_0519.lua
-- Tech Priests 0.1.519
--
-- Logistics / construction authority contract.
--
-- This pass fixes two related legacy behaviours without deleting the old helper
-- modules yet:
--   * supplies from ground stacks or remote inventories must be physically
--     fetched by a Tech-Priest before they are deposited into the Cogitator
--     Station work inventory;
--   * construction/expansion planning may not project unreachable fantasy work.
--     A build can be placed from available station-known inventory, or deferred
--     until the required item is actually unlocked/producible/available.

local M = {}
M.version = "0.1.519"
M.storage_key = "logistics_construction_contract_0519"
M.pickup_radius_sq = 2.25
M.inventory_radius_sq = 4.0
M.construction_ghost_ttl = 60 * 15
M.station_expansion_retry_ticks = 60 * 20

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function dist_sq(a,b) if not (a and b) then return 999999999 end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    physical_pickup_required = true,
    dispatcher_owns_construction = true,
    defer_unproducible_expansion = true,
    suppress_independent_construction_pulse = true,
    stats = {},
    recent = {},
    deferred_expansion = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.physical_pickup_required == nil then r.physical_pickup_required = true end
  if r.dispatcher_owns_construction == nil then r.dispatcher_owns_construction = true end
  if r.defer_unproducible_expansion == nil then r.defer_unproducible_expansion = true end
  if r.suppress_independent_construction_pulse == nil then r.suppress_independent_construction_pulse = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.deferred_expansion = r.deferred_expansion or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(pair, event, detail)
  local r=M.root(); stat(event)
  local rec={ tick=now(), event=tostring(event or "event"), detail=tostring(detail or ""), station=safe(station_unit(pair)), priest=safe(valid(pair and pair.priest) and pair.priest.unit_number or "nil") }
  r.recent[#r.recent+1]=rec
  while #r.recent > 120 do table.remove(r.recent,1) end
  if pair then pair.logistics_construction_0519 = rec end
  return rec
end

local function item_proto(name)
  if not (name and prototypes and prototypes.item) then return nil end
  local ok,p=pcall(function() return prototypes.item[name] end)
  return ok and p or nil
end
local function recipe_proto(name)
  if not (name and prototypes and prototypes.recipe) then return nil end
  local ok,p=pcall(function() return prototypes.recipe[name] end)
  return ok and p or nil
end
local function place_result_name(item_name)
  local p=item_proto(item_name); if not p then return nil end
  local ok,r=pcall(function() return p.place_result end)
  if not ok or not r then return nil end
  if type(r)=="string" then return r end
  if type(r)=="table" then return r.name or r[1] end
  return nil
end

local function station_item_count(pair, item)
  if not (valid_pair(pair) and item) then return 0 end
  if _G.tech_priests_0358_station_item_count then
    local ok,n=pcall(_G.tech_priests_0358_station_item_count, pair, item)
    if ok and tonumber(n) then return tonumber(n) end
  end
  local inv = (get_station_inventory and get_station_inventory(pair.station)) or (pair.station.get_inventory and pair.station.get_inventory(defines.inventory.chest))
  if inv and inv.valid then local ok,n=pcall(function() return inv.get_item_count(item) end); if ok then return tonumber(n) or 0 end end
  return 0
end

local function recipe_outputs_item(proto, item)
  if not (proto and item) then return false end
  local ok, products = pcall(function() return proto.products end)
  if not ok or not products then return false end
  for _,p in pairs(products) do
    local n = p.name or p[1]
    if n == item then return true end
  end
  return false
end

local function recipe_enabled_for_force(force, recipe_name)
  if not (force and recipe_name) then return false end
  local ok, rec = pcall(function() return force.recipes and force.recipes[recipe_name] end)
  if ok and rec then
    local ok2, enabled = pcall(function() return rec.enabled end)
    if ok2 then return enabled == true end
  end
  local p = recipe_proto(recipe_name)
  if p then
    local ok3, enabled = pcall(function() return p.enabled end)
    if ok3 and enabled == true then return true end
  end
  return false
end

function M.item_available_or_producible(pair, item)
  if not (valid_pair(pair) and item) then return false, "invalid" end
  if station_item_count(pair, item) > 0 then return true, "available-in-station-work-inventory" end
  if recipe_enabled_for_force(pair.station.force, item) then return true, "recipe-name-enabled" end
  if prototypes and prototypes.recipe then
    for name, proto in pairs(prototypes.recipe) do
      if recipe_outputs_item(proto, item) and recipe_enabled_for_force(pair.station.force, name) then
        return true, "enabled-product-recipe:" .. tostring(name)
      end
    end
  end
  return false, "not-available-or-unlocked"
end

function M.has_constructible_pair(pair)
  if not valid_pair(pair) then return false end
  if pair.construction_task_0338 or pair.construction_task_0340 or pair.construction_task_0342 or pair.construction_task_0357 then return true end
  if not _G.tech_priests_0358_station_sources_for_pair then return false end
  local ok,sources=pcall(_G.tech_priests_0358_station_sources_for_pair,pair)
  if not (ok and type(sources)=="table") then return false end
  for _,slot in ipairs(sources) do
    local inv=slot and slot.inv
    if inv and inv.valid then
      local okc, contents=pcall(function() return inv.get_contents() end)
      if okc and contents then
        for k,v in pairs(contents) do
          local name, count
          if type(v)=="table" then name=v.name or v[1] or (type(k)=="string" and k or nil); count=tonumber(v.count or v[2] or 1) or 1
          elseif type(k)=="string" then name=k; count=tonumber(v) or 0 end
          if name and count > 0 and place_result_name(name) then return true end
        end
      end
    end
  end
  return false
end

local function source_entity_for_scavenge(scav)
  if not scav then return nil end
  for _,k in ipairs({"source","entity","target","container","machine"}) do if valid(scav[k]) then return scav[k] end end
  return nil
end

local function is_ground_item(e)
  if not valid(e) then return false end
  local ok,t=pcall(function() return e.type end)
  return ok and (t=="item-entity" or t=="item-on-ground")
end

local function pickup_radius_sq_for(e)
  if is_ground_item(e) then return M.pickup_radius_sq end
  return M.inventory_radius_sq
end

local function request_move_to_source(pair, source, reason)
  if not (valid_pair(pair) and valid(source)) then return false end
  local pos=source.position
  if _G.tech_priests_request_movement_0418 then
    local ok,res=pcall(_G.tech_priests_request_movement_0418,pair,pos,reason or "logistics-pickup-0519",{ radius= is_ground_item(source) and 0.75 or 1.15, owner="logistics-pickup-0519", priority=760, ttl=60*8, distraction=defines and defines.distraction and defines.distraction.none or nil })
    if ok and res ~= false then
      pair.mode="moving-to-logistics-source"
      pair.logistics_pickup_0519={tick=now(), source=source.unit_number, name=source.name, x=pos.x, y=pos.y, reason=tostring(reason or "logistics-pickup")}
      record(pair,"move-to-source",source.name .. "#" .. tostring(source.unit_number or "?") )
      return true
    end
  end
  return false
end

function M.require_physical_source_access(pair, source, reason)
  local r=M.root(); if r.enabled == false or r.physical_pickup_required == false then return false end
  if not (valid_pair(pair) and valid(source)) then return false end
  local d2=dist_sq(pair.priest.position, source.position)
  if d2 <= pickup_radius_sq_for(source) then return false end
  request_move_to_source(pair, source, reason or "physical-source-access-0519")
  return true
end

local function wrap_scavenge_withdraw()
  if type(_G.try_withdraw_scavenge_item)=="function" and not rawget(_G,"TECH_PRIESTS_0519_PRE_TRY_WITHDRAW_SCAVENGE_ITEM") then
    _G.TECH_PRIESTS_0519_PRE_TRY_WITHDRAW_SCAVENGE_ITEM=_G.try_withdraw_scavenge_item
    _G.try_withdraw_scavenge_item=function(pair,...)
      local source=source_entity_for_scavenge(pair and pair.scavenge)
      if M.require_physical_source_access(pair, source, "scavenge-source-before-withdraw-0519") then
        stat("withdraw-held-for-movement")
        return true
      end
      return _G.TECH_PRIESTS_0519_PRE_TRY_WITHDRAW_SCAVENGE_ITEM(pair,...)
    end
  end
  if type(_G.tech_priests_0291_take_ground_stockpile)=="function" and not rawget(_G,"TECH_PRIESTS_0519_PRE_TAKE_GROUND_STOCKPILE") then
    _G.TECH_PRIESTS_0519_PRE_TAKE_GROUND_STOCKPILE=_G.tech_priests_0291_take_ground_stockpile
    _G.tech_priests_0291_take_ground_stockpile=function(pair,...)
      local source=source_entity_for_scavenge(pair and pair.scavenge)
      if M.require_physical_source_access(pair, source, "ground-stockpile-before-pickup-0519") then
        stat("ground-pickup-held-for-movement")
        return true
      end
      return _G.TECH_PRIESTS_0519_PRE_TAKE_GROUND_STOCKPILE(pair,...)
    end
  end
end

local function find_construction_source_entity(task, pair)
  if task and task.source_entity and valid(task.source_entity) then return task.source_entity end
  if not (task and task.item_name and _G.tech_priests_0358_station_sources_for_pair and valid_pair(pair)) then return pair and pair.station or nil end
  local ok,sources=pcall(_G.tech_priests_0358_station_sources_for_pair,pair)
  if not (ok and type(sources)=="table") then return pair.station end
  for _,slot in ipairs(sources) do
    local inv=slot and slot.inv
    if inv and inv.valid then
      local okc,n=pcall(function() return inv.get_item_count(task.item_name) end)
      if okc and (tonumber(n) or 0)>0 then return slot.entity or slot.owner or pair.station end
    end
  end
  return pair.station
end

local function ensure_construction_ghost(pair, task)
  if not (valid_pair(pair) and task and task.entity_name and task.target_position) then return false end
  local surface=pair.station.surface
  local force=pair.station.force
  local ghosts={}
  pcall(function()
    ghosts=surface.find_entities_filtered({name="entity-ghost", ghost_name=task.entity_name, force=force, area={{task.target_position.x-0.6,task.target_position.y-0.6},{task.target_position.x+0.6,task.target_position.y+0.6}}, limit=1}) or {}
  end)
  if ghosts and ghosts[1] and ghosts[1].valid then task.ghost_unit_0519=ghosts[1].unit_number; return true end
  local ok,ghost=pcall(function()
    return surface.create_entity({name="entity-ghost", inner_name=task.entity_name, position=task.target_position, force=force, raise_built=false, create_build_effect_smoke=false})
  end)
  if ok and ghost and ghost.valid then
    task.ghost_unit_0519=ghost.unit_number
    task.ghost_created_tick_0519=now()
    record(pair,"construction-ghost",task.entity_name .. "@" .. string.format("%.1f,%.1f",task.target_position.x,task.target_position.y))
    return true
  end
  return false
end

local function wrap_construction_planner()
  local Build = rawget(_G,"TECH_PRIESTS_CONSTRUCTION_PLANNER_0359")
  if type(Build)~="table" then return false end
  if type(Build.service_pair)=="function" and not Build.TECH_PRIESTS_0519_PRE_SERVICE_PAIR then
    Build.TECH_PRIESTS_0519_PRE_SERVICE_PAIR=Build.service_pair
    Build.service_pair=function(pair, reason, ...)
      local task=pair and pair.construction_task_0338
      if task and valid_pair(pair) then
        local source=find_construction_source_entity(task,pair)
        if source and source ~= pair.station and M.require_physical_source_access(pair, source, "construction-source-before-build-0519") then
          task.phase="moving-to-construction-source"
          stat("construction-source-move")
          return true,"moving-to-source"
        end
        ensure_construction_ghost(pair, task)
      end
      local ok,why=Build.TECH_PRIESTS_0519_PRE_SERVICE_PAIR(pair, reason, ...)
      local task2=pair and pair.construction_task_0338
      if task2 then ensure_construction_ghost(pair, task2) end
      return ok,why
    end
  end
  if type(Build.service_all)=="function" and not Build.TECH_PRIESTS_0519_PRE_SERVICE_ALL then
    Build.TECH_PRIESTS_0519_PRE_SERVICE_ALL=Build.service_all
    Build.service_all=function(reason,...)
      local r=M.root(); local rs=tostring(reason or "")
      if r.enabled ~= false and r.suppress_independent_construction_pulse ~= false and not r.dispatcher_construction_call and not rs:find("manual",1,true) and not rs:find("command",1,true) and not rs:find("dispatcher",1,true) then
        stat("independent-construction-pulse-suppressed")
        return 0
      end
      return Build.TECH_PRIESTS_0519_PRE_SERVICE_ALL(reason,...)
    end
  end
  return true
end

function M.service_construction(pair, reason)
  local r=M.root(); if r.enabled == false then return false,"disabled" end
  if not valid_pair(pair) then return false,"invalid" end
  local Build = rawget(_G,"TECH_PRIESTS_CONSTRUCTION_PLANNER_0359")
  if not (type(Build)=="table" and type(Build.service_pair)=="function") then return false,"no-build-planner" end
  r.dispatcher_construction_call=true
  local ok, acted, why = pcall(Build.service_pair, pair, reason or "dispatcher-0519")
  r.dispatcher_construction_call=false
  if not ok then record(pair,"construction-error",acted); return false,"construction-error:"..safe(acted) end
  if acted then record(pair,"construction-service",why or "acted") end
  return acted, why or "construction-0519"
end

local function wrap_station_expansion()
  local okM, Exp = pcall(require,"scripts.magos_station_expansion")
  if not (okM and type(Exp)=="table") then return false end
  if type(Exp.request_station_expansion)=="function" and not Exp.TECH_PRIESTS_0519_PRE_REQUEST_EXPANSION then
    Exp.TECH_PRIESTS_0519_PRE_REQUEST_EXPANSION=Exp.request_station_expansion
    Exp.request_station_expansion=function(requester_pair, blocked_item, op, note, preferred_angle)
      local r=M.root()
      if r.enabled ~= false and r.defer_unproducible_expansion ~= false and valid_pair(requester_pair) then
        local station_item = type(Exp.allowed_station_item_for_pair)=="function" and Exp.allowed_station_item_for_pair(requester_pair) or nil
        if station_item then
          local can,why=M.item_available_or_producible(requester_pair, station_item)
          if not can then
            local key=tostring(station_unit(requester_pair) or "?")..":"..tostring(station_item)..":"..tostring(blocked_item or "?")
            r.deferred_expansion[key]={tick=now(), station=station_unit(requester_pair), item=station_item, blocked=blocked_item, reason=why, retry_tick=now()+M.station_expansion_retry_ticks}
            if op then op.magos_planner_phase_0255="range-expansion-deferred"; op.magos_planner_item_0255=station_item; op.next_tick=now()+M.station_expansion_retry_ticks end
            record(requester_pair,"expansion-deferred",station_item..":"..tostring(why))
            return false
          end
        end
      end
      return Exp.TECH_PRIESTS_0519_PRE_REQUEST_EXPANSION(requester_pair, blocked_item, op, note, preferred_angle)
    end
  end
  if type(Exp.service_station_expansion_assignment)=="function" and not Exp.TECH_PRIESTS_0519_PRE_SERVICE_ASSIGNMENT then
    Exp.TECH_PRIESTS_0519_PRE_SERVICE_ASSIGNMENT=Exp.service_station_expansion_assignment
    Exp.service_station_expansion_assignment=function(worker_pair,...)
      if valid_pair(worker_pair) and worker_pair.station_expansion_0256 then
        local rec=worker_pair.station_expansion_0256
        if rec and rec.station_item and station_item_count(worker_pair, rec.station_item) <= 0 then
          local can,why=M.item_available_or_producible(worker_pair, rec.station_item)
          if not can then
            rec.phase="deferred-missing-station-item"
            rec.next_retry_tick=now()+M.station_expansion_retry_ticks
            record(worker_pair,"assignment-deferred",rec.station_item..":"..tostring(why))
            return false
          end
        end
      end
      return Exp.TECH_PRIESTS_0519_PRE_SERVICE_ASSIGNMENT(worker_pair,...)
    end
  end
  return true
end

local function patch_dispatcher()
  local okD, D = pcall(require,"scripts.core.single_dispatcher_0510")
  if not (okD and type(D)=="table" and type(D.service_pair)=="function") or D.TECH_PRIESTS_0519_WRAPPED then return false end
  D.TECH_PRIESTS_0519_WRAPPED=true
  D.TECH_PRIESTS_0519_PRE_SERVICE_PAIR=D.service_pair
  D.service_pair=function(pair, reason, ...)
    if M.root().enabled ~= false and M.root().dispatcher_owns_construction ~= false and valid_pair(pair) and M.has_constructible_pair(pair) then
      pair.dispatcher_0510 = pair.dispatcher_0510 or {}
      pair.dispatcher_0510.tick=now(); pair.dispatcher_0510.action="construction"; pair.dispatcher_0510.family="construction"; pair.dispatcher_0510.reason=tostring(reason or "construction-priority-0519")
      if type(_G.tech_priests_0507_action_claim)=="function" then pcall(_G.tech_priests_0507_action_claim,pair,"construction","logistics_construction_contract_0519",pair.dispatcher_0510.reason) end
      local acted,why=M.service_construction(pair,"dispatcher-0519")
      pair.dispatcher_0510.acted=acted and true or false; pair.dispatcher_0510.result=safe(why)
      if acted then return acted, why end
      -- If construction could not act, fall through to the normal dispatcher so
      -- combat/recovery/etc. can still proceed.
    end
    return D.TECH_PRIESTS_0519_PRE_SERVICE_PAIR(pair, reason, ...)
  end
  return true
end

function M.describe_pair(pair)
  if not valid_pair(pair) then return "invalid pair" end
  local task=pair.construction_task_0338
  local parts={
    "enabled="..tostring(M.root().enabled),
    "has_constructible="..tostring(M.has_constructible_pair(pair)),
    "construction="..(task and (tostring(task.phase)..":"..tostring(task.item_name).."->"..tostring(task.entity_name)) or "none"),
    "scavenge="..(pair.scavenge and (tostring(pair.scavenge.item_name).." source="..safe(source_entity_for_scavenge(pair.scavenge) and source_entity_for_scavenge(pair.scavenge).name or "nil")) or "none"),
    "movement="..safe(pair.movement_controller_reason_0418 or (pair.movement_request_0418 and pair.movement_request_0418.reason) or "none"),
  }
  return table.concat(parts," | ")
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  if _G.selected_pair_for_player then local ok,p=pcall(_G.selected_pair_for_player,player); if ok and p then return p end end
  local sel=player.selected
  if sel and sel.valid then
    for _,pair in pairs(pair_map()) do if valid_pair(pair) and (pair.station==sel or pair.priest==sel) then return pair end end
  end
  return nil
end

local function install_commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-logistics-construction-0519") end)
  commands.add_command("tp-logistics-construction-0519","Tech Priests 0.1.519 logistics/construction physical-access contract diagnostics.",function(event)
    local player=game.get_player(event.player_index); if not player then return end
    local arg=tostring(event.parameter or "status")
    local r=M.root()
    if arg=="enable" then r.enabled=true; player.print("[tp-logistics-construction-0519] enabled"); return end
    if arg=="disable" then r.enabled=false; player.print("[tp-logistics-construction-0519] disabled"); return end
    if arg=="pulses-on" then r.suppress_independent_construction_pulse=false; player.print("[tp-logistics-construction-0519] construction pulses allowed"); return end
    if arg=="pulses-off" then r.suppress_independent_construction_pulse=true; player.print("[tp-logistics-construction-0519] construction pulses suppressed unless dispatcher/manual"); return end
    if arg=="all" then for _,p in pairs(pair_map()) do if valid_pair(p) then pcall(M.service_construction,p,"manual-all") end end; player.print("[tp-logistics-construction-0519] serviced construction for all valid pairs"); return end
    local pair=selected_pair(player)
    player.print("[tp-logistics-construction-0519] version="..M.version.." enabled="..tostring(r.enabled).." physical_pickup="..tostring(r.physical_pickup_required).." construction_dispatcher="..tostring(r.dispatcher_owns_construction).." deferred_expansions="..tostring((function() local n=0 for _ in pairs(r.deferred_expansion or {}) do n=n+1 end return n end)()))
    if pair then player.print("[tp-logistics-construction-0519] "..M.describe_pair(pair)) else player.print("[tp-logistics-construction-0519] select a station or priest for pair diagnostics") end
  end)
end

local function wrap_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.logistics_construction_0519_wrapped then return false end
  local prev=diag.pair_dump_lines; diag.logistics_construction_0519_wrapped=true
  diag.pair_dump_lines=function()
    local lines=prev()
    local r=M.root()
    lines[#lines+1]="PAIR-DUMP-0468 LOGISTICS-CONSTRUCTION-0519 BEGIN enabled="..tostring(r.enabled).." physical_pickup="..tostring(r.physical_pickup_required).." dispatcher_construction="..tostring(r.dispatcher_owns_construction)
    for _,pair in pairs(pair_map()) do if valid_pair(pair) then lines[#lines+1]="PAIR-DUMP-0468 logistics-construction["..tostring(station_unit(pair)).."] "..M.describe_pair(pair) end end
    lines[#lines+1]="PAIR-DUMP-0468 LOGISTICS-CONSTRUCTION-0519 END"
    return lines
  end
  return true
end

function M.install()
  M.root()
  wrap_scavenge_withdraw()
  wrap_construction_planner()
  wrap_station_expansion()
  patch_dispatcher()
  wrap_diagnostics()
  install_commands()
  _G.TECH_PRIESTS_LOGISTICS_CONSTRUCTION_CONTRACT_0519=M
  if log then log("[Tech-Priests 0.1.519] logistics/construction physical-access contract loaded") end
end

return M
