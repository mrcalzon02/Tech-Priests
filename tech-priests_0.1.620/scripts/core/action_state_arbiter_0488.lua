-- scripts/core/action_state_arbiter_0488.lua
-- Tech Priests 0.1.488
--
-- Late-loaded single-action arbiter. A priest may have old bookkeeping tables
-- for craft, acquisition, combat, scan, and return at the same time, but only
-- one of those surfaces may own visible beams and overhead state on a given
-- tick. This module is intentionally conservative: it suppresses the wrong
-- visuals/actions rather than deleting the queued writ.

local M = {}
M.version = "0.1.488"
M.storage_key = "action_state_arbiter_0488"
M.tick_interval = 11
M.close_distance_sq = 4.0

local previous_scan_line, previous_fire_laser, previous_spawn_smoke

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function dist_sq(a,b) if not (a and b) then return nil end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, stats={} }
  local r=storage.tech_priests[M.storage_key]; r.version=M.version; if r.enabled==nil then r.enabled=true end; r.stats=r.stats or {}; return r
end
local function enabled() return root().enabled ~= false end
local function stat(k,n) local r=root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function pairs_by_station() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(p) return type(p)=="table" and valid(p.station) and valid(p.priest) end
local function pair_key(p) return p and (p.station_unit or (valid(p.station) and p.station.unit_number) or (valid(p.priest) and p.priest.unit_number)) or nil end

local function current_order(pair)
  local q=pair and pair.order_queue_0469
  return pair and ((q and q.current) or pair.active_order_0469) or nil
end
local function item_from(v)
  if type(v)=="string" then return v end
  if type(v)~="table" then return nil end
  return v.item or v.item_name or v.output_item or v.wanted_item or v.requested_item or v.resource or v.name
end
local function order_item(o) return o and (o.item or o.wanted_item or o.requested_item or item_from(o.task)) or nil end
local function normalize_kind(k)
  k=lower(k)
  if k=="" then return "idle" end
  if k:find("combat",1,true) or k:find("defend",1,true) or k:find("weapon",1,true) or k:find("point",1,true) then return "combat" end
  if k:find("repair",1,true) then return "repair" end
  if k:find("consecr",1,true) or k:find("sanct",1,true) then return "consecration" end
  if k:find("craft",1,true) or k:find("fabric",1,true) then return "crafting" end
  if k:find("assign",1,true) then return "acquisition" end
  if k:find("logistic",1,true) or k:find("supply",1,true) then return "acquisition" end
  if k:find("scav",1,true) or k:find("mine",1,true) or k:find("acqui",1,true) or k:find("gather",1,true) or k:find("resource",1,true) or k:find("emergency",1,true) then return "acquisition" end
  return k
end
local function is_hostile(priest,target)
  if not (valid(priest) and valid(target) and priest.force and target.force) then return false end
  if priest.force == target.force then return false end
  local ok,enemy=pcall(function() return priest.force.is_enemy and priest.force.is_enemy(target.force) end)
  return ok and enemy == true
end
local function entity_or_pos(v, seen)
  if valid(v) then return v, v.position end
  if type(v)~="table" then return nil,nil end
  seen=seen or {}; if seen[v] then return nil,nil end; seen[v]=true
  if v.x and v.y then return nil,v end
  if v.position and v.position.x and v.position.y then return nil,v.position end
  for _,key in ipairs({"target","source","entity","resource_entity","mining_target","candidate","current","selected","node","resource","destination"}) do
    local e,p=entity_or_pos(v[key], seen); if e or p then return e,p end
  end
  return nil,nil
end
local function current_target(pair)
  local o=current_order(pair)
  for _,v in ipairs({o and o.target, o and o.task, pair and pair.direct_acquisition_task_0336, pair and pair.emergency_craft, pair and pair.scavenge, pair and pair.active_task, pair and pair.active_task_0285, pair and pair.inventory_scan, pair and pair.target, pair and pair.mining_target}) do
    local e,p=entity_or_pos(v); if e or p then return e,p end
  end
  return nil,nil
end
local function name_item_from_entity(e)
  if not valid(e) then return nil end
  if e.type == "resource" then return e.name end
  local n=tostring(e.name or "")
  if n:find("coal",1,true) then return "coal" end
  if n:find("iron",1,true) then return "iron-ore" end
  if n:find("copper",1,true) then return "copper-ore" end
  if n:find("rock",1,true) or n:find("stone",1,true) then return "stone" end
  if n:find("tree",1,true) then return "wood" end
  return n ~= "" and n or nil
end
local function actual_crafting(pair)
  local task = pair and (pair.emergency_craft or pair.station_craft_0337 or pair.active_craft_0479)
  local mode = lower(pair and pair.mode)
  if not task then return false end
  local cur = type(task)=="table" and (task.current or task.entity or task.target) or nil
  if valid(cur) or (type(cur)=="table" and (cur.entity or cur.target or cur.source)) then return false end
  local due = tonumber(task.craft_due_tick or task.build_due_tick or task.station_craft_due_tick_0337 or task.due_tick)
  if due and due >= now() then return true end
  if mode:find("craft",1,true) and (pair.station_craft_lock_0337 or pair.crafting_lock_0418 or task.station_craft_pending_0337) then return true end
  return false
end
function M.action(pair)
  if not valid_pair(pair) then return { kind="invalid" } end
  if pair.idle_player_conversation_0181 or pair.idle_conversation then return { kind="conversation" } end
  local target,pos = current_target(pair)
  local order = current_order(pair)
  local okind = normalize_kind(order and (order.kind or order.type or order.source) or "")
  local modekind = normalize_kind(pair.mode)
  if (is_hostile(pair.priest, target) or modekind == "combat") and valid(target) then return { kind="combat", target=target, item="combat" } end
  if okind == "combat" and not valid(target) and (modekind == "idle" or modekind == "combat") then return { kind="idle", stale_combat=true } end
  if actual_crafting(pair) then return { kind="crafting", item=item_from(pair.emergency_craft or {}) or order_item(order) } end
  if okind == "repair" or modekind == "repair" then return { kind="repair", target=target, item="repair-pack" } end
  if okind == "consecration" or modekind == "consecration" then return { kind="consecration", target=target, item="sacred-machine-oil" } end
  if okind == "acquisition" or modekind == "acquisition" or pair.emergency_craft or pair.direct_acquisition_task_0336 or pair.scavenge or pair.inventory_scan then
    return { kind="acquisition", target=target, pos=pos, item=(target and name_item_from_entity(target)) or order_item(order) or item_from(pair.emergency_craft or {}) or item_from(pair.direct_acquisition_task_0336 or {}) }
  end
  return { kind="idle", item=order_item(order), target=target, pos=pos }
end
local function destroy(obj) if obj then pcall(function() if obj.valid == nil or obj.valid then obj.destroy() end end) end end
function M.clear_beams(pair)
  if not pair then return end
  destroy(pair.scan_line_render); pair.scan_line_render=nil
  destroy(pair.mining_beam_render); pair.mining_beam_render=nil
  local key=pair_key(pair)
  if storage and storage.tech_priests and key then
    local w=storage.tech_priests.tech_priests_work_visuals_0323
    if w and w.scan_lines then destroy(w.scan_lines[key]); w.scan_lines[key]=nil end
  end
end
local function request_move(pair,pos,reason)
  if not (valid_pair(pair) and pos) then return false end
  if _G.tech_priests_request_movement_0418 then
    local ok,res=pcall(_G.tech_priests_request_movement_0418,pair,pos,reason or "action-arbiter-0488",{radius=0.75,owner="action-arbiter-0488",priority=720,ttl=600,distraction=defines and defines.distraction and defines.distraction.by_enemy})
    if ok and res ~= false then stat("move_requests"); return true end
  elseif pair.priest.set_command and defines and defines.command then
    local ok=pcall(function() pair.priest.set_command{type=defines.command.go_to_location,destination=pos,radius=0.75,distraction=defines.distraction.by_enemy} end)
    if ok then stat("move_requests"); return true end
  end
  return false
end
function M.allow_scan(pair,target)
  if not enabled() then return true end
  if not valid_pair(pair) then return false end
  local a=M.action(pair)
  if a.kind ~= "acquisition" then M.clear_beams(pair); stat("scan_suppressed"); return false end
  if valid(target) and a.target and valid(a.target) and target ~= a.target then stat("scan_target_mismatch"); return false end
  if valid(target) and dist_sq(pair.priest.position,target.position) and dist_sq(pair.priest.position,target.position) > M.close_distance_sq then request_move(pair,target.position,"action-arbiter-0488-before-scan") end
  return true
end
function M.allow_laser(priest,target,reason)
  if not enabled() then return true end
  if not valid(priest) then return false end
  local pair = storage and storage.tech_priests and (storage.tech_priests.pairs_by_priest or {})[priest.unit_number]
  if not valid_pair(pair) then return true end
  local hostile = is_hostile(priest,target)
  local a=M.action(pair)
  if hostile then
    if a.kind == "combat" then return true end
    stat("combat_laser_suppressed"); return false
  end
  if a.kind ~= "acquisition" then M.clear_beams(pair); stat("laser_suppressed_wrong_action"); return false end
  if valid(target) and a.target and valid(a.target) and target ~= a.target then stat("laser_target_mismatch"); return false end
  if valid(target) then
    local d2=dist_sq(priest.position,target.position) or 0
    if d2 > M.close_distance_sq then request_move(pair,target.position,"action-arbiter-0488-before-laser"); stat("remote_laser_suppressed"); return false end
  end
  return true
end
local function progress_bar(p,w) w=w or 10; p=math.max(0,math.min(1,tonumber(p) or 0)); local f=math.floor(p*w+0.5); local s=""; for i=1,w do s=s..(i<=f and "█" or "░") end; return s end
function M.status(pair)
  if not valid_pair(pair) then return nil,nil end
  local a=M.action(pair)
  if a.kind=="conversation" then return "Conversing", {r=1,g=0.86,b=0.28,a=0.95} end
  if a.kind=="combat" then return "Battle rite engaged", {r=1,g=0.25,b=0.15,a=0.95} end
  if a.kind=="repair" then return "Repair litany in progress", {r=0.55,g=0.95,b=0.55,a=0.95} end
  if a.kind=="consecration" then return "Consecration rite in progress", {r=0.6,g=1,b=0.95,a=0.95} end
  if a.kind=="crafting" then
    local task=pair.emergency_craft or pair.station_craft_0337 or pair.active_craft_0479 or {}
    local due=tonumber(task.craft_due_tick or task.build_due_tick or task.station_craft_due_tick_0337 or task.due_tick)
    local started=tonumber(task.craft_started_tick_0337 or task.station_craft_started_tick_0337 or task.started_tick or (due and due-180) or now())
    local rem=due and math.max(0,due-now()) or nil; local total=due and math.max(1,due-started) or 180
    local label="Crafting" .. (a.item and (" "..tostring(a.item):gsub("-"," ")) or "")
    if rem then label=label.." "..tostring(math.ceil(rem/60)).."s "..progress_bar(1-math.min(1,rem/total),10) end
    return label,{r=1,g=0.74,b=0.24,a=0.95}
  end
  if a.kind=="acquisition" then return "Acquiring " .. tostring((a.item or "field materials")):gsub("-"," "), {r=0.98,g=0.72,b=0.22,a=0.95} end
  return nil,nil
end
function M.service_pair(pair)
  if not (enabled() and valid_pair(pair)) then return end
  local a=M.action(pair)
  if _G.tech_priests_0507_action_claim then pcall(_G.tech_priests_0507_action_claim, pair, a.kind or "idle", "action_state_arbiter_0488", a.reason or a.item or "service_pair") end
  pair.action_state_0488={kind=a.kind,item=a.item,target=(valid(a.target) and (a.target.name.."#"..tostring(a.target.unit_number or "?")) or nil),tick=now()}
  if a.stale_combat then
    local oq=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
    if oq and type(oq.fail_current)=="function" then pcall(oq.fail_current,pair,"action-arbiter-0488-stale-combat-without-target") end
    stat("stale_combat_failed")
  end
  if a.kind ~= "acquisition" then M.clear_beams(pair) end
  if a.kind=="crafting" then pair.direct_acquisition_task_0336=nil; pair.scavenge=nil; pair.inventory_scan=nil end
end
function M.tick_all() if not enabled() then return end; for _,p in pairs(pairs_by_station()) do pcall(M.service_pair,p) end end
function M.wrap_visuals()
  if type(_G.draw_emergency_craft_scan_line)=="function" and not previous_scan_line then
    previous_scan_line=_G.draw_emergency_craft_scan_line
    _G.draw_emergency_craft_scan_line=function(pair,target) if M.allow_scan(pair,target) then return previous_scan_line(pair,target) end return false end
  end
  if type(_G.tech_priests_0312_fire_laser)=="function" and not previous_fire_laser then
    previous_fire_laser=_G.tech_priests_0312_fire_laser
    _G.tech_priests_0312_fire_laser=function(priest,target,damage,reason,color) if M.allow_laser(priest,target,reason) then return previous_fire_laser(priest,target,damage,reason,color) end return false end
  end
  local ok,W=pcall(require,"scripts.core.work_visuals")
  if ok and type(W)=="table" then
    W.status_for_pair=function(pair)
      local a=M.action(pair)
      local text=M.status(pair)
      if a.kind=="acquisition" then return text, a.target end
      return text, nil
    end
    local prev_draw_scan=W.draw_scan_line
    W.draw_scan_line=function(pair,target) if M.allow_scan(pair,target) and prev_draw_scan then return prev_draw_scan(pair,target) end return nil end
  end
end
function M.wrap_overhead()
  local gov=rawget(_G,"TECH_PRIESTS_OVERHEAD_STATUS_GOVERNOR_0471")
  if gov and type(gov)=="table" and not gov.canonical_status_0488_previous then
    gov.canonical_status_0488_previous=gov.canonical_status
    gov.canonical_status=function(pair,incoming)
      local text,color=M.status(pair)
      if text then return text,color end
      return gov.canonical_status_0488_previous(pair,incoming)
    end
  end
end
function M.wrap_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.action_state_wrapped_0488 then return false end
  local prev=diag.pair_dump_lines; diag.action_state_wrapped_0488=true
  diag.pair_dump_lines=function()
    local lines=prev(); local r=root()
    lines[#lines+1]="ACTION-STATE-0488 BEGIN enabled="..safe(r.enabled).." suppressed_scan="..safe(r.stats.scan_suppressed or 0).." suppressed_laser="..safe(r.stats.laser_suppressed_wrong_action or 0).." remote_laser="..safe(r.stats.remote_laser_suppressed or 0).." stale_combat="..safe(r.stats.stale_combat_failed or 0)
    for k,p in pairs(pairs_by_station()) do if valid_pair(p) then local a=M.action(p); lines[#lines+1]="action["..safe(k).."] kind="..safe(a.kind).." item="..safe(a.item).." mode="..safe(p.mode).." target="..safe(valid(a.target) and (a.target.name.."#"..tostring(a.target.unit_number or "?")) or "none") end end
    lines[#lines+1]="ACTION-STATE-0488 END"; return lines
  end
  return true
end
function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-action-state-0488") end end)
  commands.add_command("tp-action-state-0488","Tech Priests 0.1.488: inspect single-action authority. Usage: status|all|on|off",function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil; local param=lower(event and event.parameter or "status"); local r=root(); if param=="off" then r.enabled=false elseif param=="on" then r.enabled=true end
    if not (player and player.valid) then return end
    local function print_pair(p) local a=M.action(p); player.print("[tp-action-state-0488] station="..safe(pair_key(p)).." action="..safe(a.kind).." item="..safe(a.item).." mode="..safe(p and p.mode).." target="..safe(valid(a.target) and a.target.name or "none")) end
    if param=="all" then for _,p in pairs(pairs_by_station()) do print_pair(p) end else local e=player.selected; local p=e and e.valid and storage and storage.tech_priests and ((storage.tech_priests.pairs_by_station or {})[e.unit_number] or (storage.tech_priests.pairs_by_priest or {})[e.unit_number]); if p then print_pair(p) else player.print("[tp-action-state-0488] select a Cogitator Station or Tech-Priest, or use /tp-action-state-0488 all") end end
  end)
end
function M.install()
  root(); _G.TECH_PRIESTS_ACTION_STATE_ARBITER_0488=M
  M.wrap_visuals(); M.wrap_overhead(); M.wrap_diagnostics(); M.register_commands()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry"); if not registry then pcall(function() registry=require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then registry.on_nth_tick(M.tick_interval,function() M.tick_all(); M.wrap_overhead() end,{owner="action_state_arbiter_0488",category="scheduler",priority="last"}) elseif script and script.on_nth_tick then pcall(function() script.on_nth_tick(M.tick_interval,function() M.tick_all(); M.wrap_overhead() end) end) end
  if log then log("[Tech-Priests 0.1.488] single-action arbiter installed; priest beams and overhead now follow one active action") end
  return true
end
return M
