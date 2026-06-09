-- scripts/core/combat_repair_doctrine_0517.lua
-- Tech Priests 0.1.517
--
-- Dispatcher-owned combat repair doctrine.  This is not ordinary repair.  It
-- asks whether a damaged wall/gate segment is part of a currently defended
-- line.  If loaded/active turrets or other Tech-Priests are covering the line,
-- a priest may temporarily repair the wall under fire.  If the priest is alone
-- and uncovered, combat remains the correct answer.

local M = {}
M.version = "0.1.517"
M.storage_key = "combat_repair_doctrine_0517"
M.search_radius = 26
M.wall_enemy_radius = 9
M.wall_turret_radius = 8
M.priest_cover_radius = 12
M.personal_danger_radius_sq = 16
M.repair_range_sq = 16
M.cluster_size = 3
M.cluster_reservation_ttl = 150
M.target_cooldown_ticks = 90
M.min_wall_missing_ratio = 0.04
M.critical_wall_missing_ratio = 0.35
M.max_candidates = 120

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number) or "nil") or "nil" end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number) or "nil") or "nil" end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) if not (a and b) then return 999999999 end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function distance(a,b) return math.sqrt(dist_sq(a,b)) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    dispatcher_owned = true,
    require_cover = true,
    reserve_clusters = true,
    stats = {},
    recent = {},
    cluster_reservations = {},
    target_cooldowns = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.dispatcher_owned == nil then r.dispatcher_owned = true end
  if r.require_cover == nil then r.require_cover = true end
  if r.reserve_clusters == nil then r.reserve_clusters = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.cluster_reservations = r.cluster_reservations or {}
  r.target_cooldowns = r.target_cooldowns or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(pair, action, detail)
  local r=M.root(); stat(action)
  local ev={ tick=now(), action=tostring(action or "event"), station=station_unit(pair), priest=priest_unit(pair), detail=tostring(detail or "") }
  r.recent[#r.recent+1]=ev
  while #r.recent>180 do table.remove(r.recent,1) end
  return ev
end

local function is_wallish(e)
  if not valid(e) then return false end
  local t=lower(e.type); local n=lower(e.name)
  return t=="wall" or t=="gate" or n:find("wall",1,true) ~= nil or n:find("gate",1,true) ~= nil
end

local function missing_health(e)
  if not (valid(e) and e.health and e.max_health) then return 0 end
  return math.max(0, (tonumber(e.max_health) or 0) - (tonumber(e.health) or 0))
end

local function missing_ratio(e)
  local maxh=valid(e) and tonumber(e.max_health) or 0
  if not maxh or maxh <= 0 then return 0 end
  return missing_health(e)/maxh
end

local function damaged(e)
  return valid(e) and e.health and e.max_health and missing_health(e) > 0.01
end

local function same_force(pair, e)
  return valid_pair(pair) and valid(e) and e.force and pair.station.force and e.force.name == pair.station.force.name
end

local function enemyish(pair, e)
  if not (valid_pair(pair) and valid(e) and e.force and pair.station.force) then return false end
  if e.force.name == pair.station.force.name or e.force.name == "neutral" then return false end
  local t=lower(e.type)
  if t == "unit" or t == "unit-spawner" or t == "turret" or t == "spider-unit" then return true end
  if e.health and e.max_health and (t:find("unit",1,true) or t:find("biter",1,true) or t:find("spitter",1,true)) then return true end
  return false
end

local function surface_entities(surface, area, filter)
  local ok, ents = pcall(function()
    local spec = { area = area }
    if filter and filter.force then spec.force = filter.force end
    return surface.find_entities_filtered(spec)
  end)
  if ok and ents then return ents end
  return {}
end

local function box(pos, radius)
  return {{(pos.x or 0)-radius, (pos.y or 0)-radius}, {(pos.x or 0)+radius, (pos.y or 0)+radius}}
end

local function ammo_inventory_loaded(turret)
  if not valid(turret) then return false end
  local inv_id = defines and defines.inventory and defines.inventory.turret_ammo
  if not inv_id then return false end
  local ok, inv = pcall(function() return turret.get_inventory(inv_id) end)
  if not (ok and inv and inv.valid) then return false end
  local ok_empty, empty = pcall(function() return inv.is_empty() end)
  if ok_empty then return not empty end
  local ok_count, contents = pcall(function() return inv.get_contents() end)
  if ok_count and contents then
    for _, count in pairs(contents) do if tonumber(count) and tonumber(count) > 0 then return true end end
  end
  return false
end

local function has_energy(turret)
  if not valid(turret) then return false end
  local ok, e = pcall(function() return turret.energy end)
  return ok and tonumber(e or 0) and tonumber(e or 0) > 1000
end

local function has_fluid(turret)
  if not valid(turret) then return false end
  local ok, fb = pcall(function() return turret.fluidbox end)
  if not (ok and fb) then return false end
  local ok_len, len = pcall(function() return #fb end)
  if not ok_len then return false end
  for i=1,len do
    local okf, f = pcall(function() return fb[i] end)
    if okf and f and tonumber(f.amount or 0) and tonumber(f.amount or 0) > 0 then return true end
  end
  return false
end

local function turret_active_or_loaded(pair, turret)
  if not (valid_pair(pair) and valid(turret) and same_force(pair, turret)) then return false, "not-allied" end
  local t=lower(turret.type)
  if not t:find("turret",1,true) then return false, "not-turret" end
  local ok_target, st = pcall(function() return turret.shooting_target end)
  if ok_target and valid(st) then return true, "shooting" end
  if ammo_inventory_loaded(turret) then return true, "ammo-loaded" end
  if has_energy(turret) then return true, "energized" end
  if has_fluid(turret) then return true, "fluid-ready" end
  return false, "unloaded"
end

local function count_enemies_near(pair, pos, radius)
  local n=0; local nearest=999999
  for _, e in ipairs(surface_entities(pair.station.surface, box(pos, radius), nil)) do
    if enemyish(pair, e) then
      n=n+1
      nearest=math.min(nearest, distance(pos, e.position))
    end
  end
  if nearest == 999999 then nearest = nil end
  return n, nearest
end

local function turret_cover(pair, wall)
  local count=0; local active=0; local labels={}
  for _, e in ipairs(surface_entities(wall.surface, box(wall.position, M.wall_turret_radius), { force = pair.station.force })) do
    if valid(e) and lower(e.type):find("turret",1,true) then
      count=count+1
      local ok, why = turret_active_or_loaded(pair,e)
      if ok then
        active=active+1
        labels[#labels+1]=safe(e.name)..":"..safe(why)
      end
    end
  end
  return active > 0, active, count, table.concat(labels, ",")
end

local function other_priest_cover(pair, wall)
  local active=0
  for _, other in pairs(pair_map()) do
    if other ~= pair and valid_pair(other) and same_force(pair, other.priest) then
      local ds=dist_sq(other.priest.position, wall.position)
      if ds <= M.priest_cover_radius*M.priest_cover_radius then
        local mode=lower(other.mode)
        local tgt=(valid(other.combat_target) and other.combat_target) or (valid(other.target) and other.target) or nil
        if mode:find("combat",1,true) or mode:find("defend",1,true) or enemyish(pair,tgt) then
          active=active+1
        end
      end
    end
  end
  return active > 0, active
end

local function cluster_key(entity)
  if not valid(entity) then return nil end
  local p=entity.position or {x=0,y=0}
  local s=M.cluster_size
  local cx=math.floor(((p.x or 0)/s)+0.5)*s
  local cy=math.floor(((p.y or 0)/s)+0.5)*s
  return tostring(entity.surface.index)..":"..tostring(entity.force and entity.force.name or "?")..":"..cx..":"..cy
end

local function target_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return tostring(entity.unit_number) end
  local p=entity.position or {x=0,y=0}
  return entity.name.."@"..string.format("%.1f,%.1f", p.x or 0, p.y or 0)
end

local function cleanup_reservations(r)
  local t=now()
  for k,res in pairs(r.cluster_reservations or {}) do
    if not res or (tonumber(res.until_tick) or 0) < t then r.cluster_reservations[k]=nil end
  end
  for k,tick in pairs(r.target_cooldowns or {}) do
    if (tonumber(tick) or 0) < t then r.target_cooldowns[k]=nil end
  end
end

local function cluster_reserved_by_other(r, pair, wall)
  if not r.reserve_clusters then return false end
  cleanup_reservations(r)
  local key=cluster_key(wall); if not key then return false end
  local res=r.cluster_reservations[key]
  return res and tostring(res.station or "") ~= tostring(station_unit(pair))
end

local function reserve_cluster(r, pair, wall)
  local key=cluster_key(wall); if not key then return false end
  r.cluster_reservations[key]={ station=station_unit(pair), priest=priest_unit(pair), wall=target_key(wall), until_tick=now()+M.cluster_reservation_ttl }
  return true
end

local function release_cluster(r, wall)
  local key=cluster_key(wall); if key then r.cluster_reservations[key]=nil end
end

local function release_cluster_key(r, key)
  if key then r.cluster_reservations[key]=nil; return true end
  return false
end

local function station_has_repair_pack(pair)
  if _G.station_has_repair_pack then local ok,res=pcall(_G.station_has_repair_pack, pair.station); if ok then return res == true end end
  local inv = pair and valid(pair.station) and _G.get_station_inventory and _G.get_station_inventory(pair.station) or nil
  return inv and inv.get_item_count("repair-pack") > 0
end

local function eligible_wall(pair, wall)
  if not valid_pair(pair) then return false, "invalid-pair" end
  if not (valid(wall) and same_force(pair, wall) and is_wallish(wall) and damaged(wall)) then return false, "not-damaged-wall" end
  if missing_ratio(wall) < M.min_wall_missing_ratio then return false, "minor-damage" end
  if not station_has_repair_pack(pair) then return false, "no-repair-pack" end
  local radius=tonumber(pair.radius) or 32
  if dist_sq(pair.station.position, wall.position) > radius*radius then return false, "outside-station-radius" end
  local r=M.root()
  local k=target_key(wall)
  if k and r.target_cooldowns[k] and tonumber(r.target_cooldowns[k]) > now() then return false, "target-cooldown" end
  if cluster_reserved_by_other(r, pair, wall) then return false, "cluster-reserved" end
  local enemies, nearest=count_enemies_near(pair, wall.position, M.wall_enemy_radius)
  if enemies <= 0 then return false, "no-enemy-pressure" end
  local turret_ok, active_turrets, turret_count, turret_labels=turret_cover(pair, wall)
  local priest_ok, active_priests=other_priest_cover(pair, wall)
  local covered = turret_ok or priest_ok
  local personal_enemies=count_enemies_near(pair, pair.priest.position, math.sqrt(M.personal_danger_radius_sq))
  if r.require_cover and not covered then return false, "uncovered-under-fire" end
  if personal_enemies and personal_enemies > 0 and not turret_ok and not priest_ok and missing_ratio(wall) < M.critical_wall_missing_ratio then return false, "priest-personal-danger" end
  return true, {
    enemies=enemies,
    nearest_enemy=nearest,
    active_turrets=active_turrets,
    turret_count=turret_count,
    turret_labels=turret_labels,
    active_priests=active_priests,
    covered=covered,
    personal_enemies=personal_enemies,
  }
end

local function score_wall(pair, wall, context)
  local ratio=missing_ratio(wall)
  local missing=missing_health(wall)
  local pds=dist_sq(pair.priest.position, wall.position)
  local sds=dist_sq(pair.station.position, wall.position)
  local enemies=(context and context.enemies) or 0
  local active_turrets=(context and context.active_turrets) or 0
  local active_priests=(context and context.active_priests) or 0
  local nearest=(context and context.nearest_enemy) or M.wall_enemy_radius
  return ratio*15000 + missing*3 + enemies*450 + active_turrets*900 + active_priests*650 - nearest*40 - math.sqrt(pds)*35 - math.sqrt(sds)*4
end

function M.find_combat_repair_target(pair)
  local r=M.root()
  if r.enabled == false then return nil, "disabled" end
  if not valid_pair(pair) then return nil, "invalid-pair" end
  cleanup_reservations(r)
  local radius=math.min(tonumber(pair.radius) or 32, M.search_radius)
  local best, best_score, best_context=nil, -999999999, nil
  local checked=0
  for _, e in ipairs(surface_entities(pair.station.surface, box(pair.priest.position, radius), { force = pair.station.force })) do
    if is_wallish(e) then
      checked=checked+1
      if checked > M.max_candidates then break end
      local ok, ctx = eligible_wall(pair, e)
      if ok then
        local score=score_wall(pair,e,ctx)
        if score > best_score then best=e; best_score=score; best_context=ctx end
      end
    end
  end
  if not best then
    record(pair,"no-combat-repair-target","checked="..safe(checked))
    return nil, "no-defended-damaged-wall"
  end
  return best, best_context, best_score
end


function M.abort_pair(pair, reason)
  if not pair then return false end
  local state=pair.combat_repair_0517
  local target=state and state.target or pair.combat_repair_target_0517
  local r=M.root()
  if state and state.cluster_key then release_cluster_key(r, state.cluster_key) end
  if valid(target) then release_cluster(r,target) end
  pair.combat_repair_0517={ phase="failed", failed_tick=now(), last_blocker=tostring(reason or "combat-repair-aborted") }
  if pair.repair_0516 and pair.repair_0516.target == target then
    pair.repair_0516.phase="none"
    pair.repair_0516.target=nil
    pair.repair_0516.target_name=nil
    pair.repair_0516.target_unit=nil
  end
  if pair.target == target then pair.target=nil end
  pair.combat_repair_target_0517=nil
  if lower(pair.mode):find("repair",1,true) then pair.mode="combat-repair-aborted" end
  record(pair,"aborted",reason or "combat-repair-aborted")
  return true
end

function M.recommend_action(pair)
  local r=M.root()
  if r.enabled == false or not valid_pair(pair) then return nil end
  -- If we were in a combat-repair leaf but cover vanished, abort the repair
  -- state so ordinary repair cannot continue kneeling in front of the swarm.
  if M.active(pair) then
    local active_target = pair.combat_repair_0517 and pair.combat_repair_0517.target
    if valid(active_target) then
      local ok, why = eligible_wall(pair, active_target)
      if not ok then M.abort_pair(pair, "cover-lost:"..safe(why)); return nil end
    end
  end
  local target, ctx, score = M.find_combat_repair_target(pair)
  if not valid(target) then return nil end
  return {
    kind="combat-repair",
    target=target,
    item="repair-pack",
    reason="defended-wall-under-attack-0517",
    priority=920,
    score=score,
    context=ctx,
  }
end

function M.active(pair)
  if not pair then return false end
  local s=pair.combat_repair_0517
  return s and s.phase and s.phase ~= "none" and s.phase ~= "complete" and s.phase ~= "failed"
end

local function clear_if_complete(pair, target)
  local s=pair and pair.combat_repair_0517 or nil
  if not s then return end
  if not valid(target) or missing_health(target) <= 0.01 then
    local r=M.root()
    local k=target_key(target)
    if k then r.target_cooldowns[k]=now()+M.target_cooldown_ticks end
    if s.cluster_key then release_cluster_key(r, s.cluster_key) end
    if valid(target) then release_cluster(r,target) end
    s.phase="complete"
    s.completed_tick=now()
    record(pair,"complete",valid(target) and target.name or "invalid-target")
  end
end

function M.service_pair(pair, reason, forced_target)
  local r=M.root()
  if r.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  cleanup_reservations(r)
  local target=forced_target
  local ctx=nil
  if valid(target) then
    local ok, c = eligible_wall(pair,target)
    if ok then ctx=c else target=nil end
  end
  if not valid(target) then
    target, ctx = M.find_combat_repair_target(pair)
  end
  local state=pair.combat_repair_0517 or { phase="none" }
  pair.combat_repair_0517=state
  state.version=M.version
  state.last_service_tick=now()
  state.last_reason=tostring(reason or "service")
  if not valid(target) then
    state.phase="no-target"
    state.last_blocker=tostring(ctx or "no-target")
    return false, state.last_blocker
  end
  reserve_cluster(r,pair,target)
  state.phase="repair-via-0516"
  state.target=target
  state.target_name=target.name
  state.target_unit=target.unit_number
  state.cluster_key=cluster_key(target)
  state.missing=missing_health(target)
  state.ratio=missing_ratio(target)
  state.enemies=ctx and ctx.enemies or nil
  state.active_turrets=ctx and ctx.active_turrets or nil
  state.active_priests=ctx and ctx.active_priests or nil
  state.cover=tostring((ctx and ctx.covered) or false)
  state.turret_labels=ctx and ctx.turret_labels or ""
  pair.combat_repair_target_0517=target
  pair.mode="combat-repair"

  local okR, Repair = pcall(require, "scripts.core.repair_executor_0516")
  if not (okR and Repair and type(Repair.service_pair)=="function") then
    release_cluster_key(r,state.cluster_key)
    if valid(target) then release_cluster(r,target) end
    state.phase="failed"
    state.last_blocker="repair-executor-missing"
    pair.combat_repair_target_0517=nil
    record(pair,"failed","repair-executor-missing")
    return false, "repair-executor-missing"
  end
  if type(Repair.submit_or_assign_repair_task)=="function" then
    pcall(Repair.submit_or_assign_repair_task, pair, target, "combat-repair-0517")
  end
  local ok, acted, why = pcall(Repair.service_pair, pair, "combat-repair-0517", target)
  if not ok then
    release_cluster_key(r,state.cluster_key)
    if valid(target) then release_cluster(r,target) end
    state.phase="failed"
    state.last_blocker=tostring(acted)
    pair.combat_repair_target_0517=nil
    record(pair,"repair-error",state.last_blocker)
    return false, "repair-error"
  end
  clear_if_complete(pair,target)
  record(pair,"service","target="..safe(target.name).."#"..safe(target.unit_number or "?").." acted="..safe(acted).." why="..safe(why).." enemies="..safe(state.enemies).." turrets="..safe(state.active_turrets).." priests="..safe(state.active_priests))
  return acted, why or "combat-repair-0517"
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok,p=pcall(_G.selected_pair_for_player, player); if ok and p then return p end end
  local selected=player and player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local tp=storage.tech_priests
    return (tp.pairs_by_station and tp.pairs_by_station[selected.unit_number]) or (tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number])
  end
  return nil
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-combat-repair-0517") end end)
  commands.add_command("tp-combat-repair-0517", "Tech Priests 0.1.517: combat repair doctrine. Params: on/off/all/cover-on/cover-off/reserve-on/reserve-off", function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil
    local param=lower(event and event.parameter or "status")
    local r=M.root()
    if param=="on" then r.enabled=true end
    if param=="off" then r.enabled=false end
    if param=="cover-on" then r.require_cover=true end
    if param=="cover-off" then r.require_cover=false end
    if param=="reserve-on" then r.reserve_clusters=true end
    if param=="reserve-off" then r.reserve_clusters=false end
    if param=="all" then for _,pair in pairs(pair_map()) do if valid_pair(pair) then pcall(M.service_pair,pair,"manual-all") end end end
    local pair=selected_pair(player)
    local lines={}
    lines[#lines+1]="[tp-combat-repair-0517] enabled="..safe(r.enabled).." require_cover="..safe(r.require_cover).." reserve_clusters="..safe(r.reserve_clusters).." service="..safe(r.stats.service or 0).." complete="..safe(r.stats.complete or 0).." no_target="..safe(r.stats["no-combat-repair-target"] or 0)
    if pair then
      local s=pair.combat_repair_0517 or {}
      local target, ctx, score = M.find_combat_repair_target(pair)
      lines[#lines+1]="selected station="..safe(station_unit(pair)).." priest="..safe(priest_unit(pair)).." mode="..safe(pair.mode).." phase="..safe(s.phase).." active_target="..safe(s.target_name).."#"..safe(s.target_unit).." missing="..safe(s.missing).." enemies="..safe(s.enemies).." turrets="..safe(s.active_turrets).." priests="..safe(s.active_priests).." cover="..safe(s.cover)
      lines[#lines+1]="candidate="..safe(target and target.name or "nil").."#"..safe(target and (target.unit_number or "?") or "nil").." score="..safe(score and string.format("%.1f",score) or "nil").." ctx_enemies="..safe(ctx and ctx.enemies or "nil").." ctx_turrets="..safe(ctx and ctx.active_turrets or "nil").." ctx_priests="..safe(ctx and ctx.active_priests or "nil").." labels="..safe(ctx and ctx.turret_labels or "")
    end
    local msg=table.concat(lines,"\n")
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_pair_dump()
  local diag=rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.combat_repair_0517_wrapped then return false end
  local prev=diag.pair_dump_lines
  diag.combat_repair_0517_wrapped=true
  diag.pair_dump_lines=function()
    local lines=prev()
    local r=M.root()
    lines[#lines+1]="PAIR-DUMP-0468 COMBAT-REPAIR-0517 BEGIN enabled="..safe(r.enabled).." require_cover="..safe(r.require_cover).." reserve_clusters="..safe(r.reserve_clusters).." service="..safe(r.stats.service or 0).." complete="..safe(r.stats.complete or 0).." no_target="..safe(r.stats["no-combat-repair-target"] or 0)
    for _,pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local s=pair.combat_repair_0517 or {}
        lines[#lines+1]="PAIR-DUMP-0468 combatRepair0517["..safe(station_unit(pair)).."] priest="..safe(priest_unit(pair)).." mode="..safe(pair.mode).." phase="..safe(s.phase).." target="..safe(s.target_name).."#"..safe(s.target_unit).." missing="..safe(s.missing).." ratio="..safe(s.ratio).." enemies="..safe(s.enemies).." turrets="..safe(s.active_turrets).." priests="..safe(s.active_priests).." cover="..safe(s.cover).." labels="..safe(s.turret_labels)
      end
    end
    for i=math.max(1,#r.recent-10),#r.recent do
      local ev=r.recent[i]
      if ev then lines[#lines+1]="PAIR-DUMP-0468 combatRepair0517.recent["..safe(i).."] tick="..safe(ev.tick).." action="..safe(ev.action).." station="..safe(ev.station).." priest="..safe(ev.priest).." "..safe(ev.detail) end
    end
    lines[#lines+1]="PAIR-DUMP-0468 COMBAT-REPAIR-0517 END"
    return lines
  end
  return true
end

function M.install()
  M.root()
  install_command()
  wrap_pair_dump()
  _G.TechPriestsCombatRepairDoctrine0517=M
  if log then log("[Tech-Priests 0.1.517] combat repair doctrine installed; defended damaged wall clusters can route through dispatcher and repair_executor_0516") end
  return true
end

return M