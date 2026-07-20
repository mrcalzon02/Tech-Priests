-- scripts/core/action_state_arbiter_0488.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- Pure action classifier and read-only presentation gate. It never creates work,
-- fails orders, clears executor state, requests movement, or owns a timer.

local M = { version = "0.1.674-dev", storage_key = "action_state_arbiter_0488", close_distance_sq = 4 }
local previous_scan_line, previous_fire_laser
local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v) if v == nil then return "nil" end local ok,s=pcall(tostring,v);return ok and s or "?" end
local function dist_sq(a,b) if not(a and b) then return nil end local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
local function root()
  storage.tech_priests=storage.tech_priests or{}
  local r=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,stats={},snapshots={}}
  storage.tech_priests[M.storage_key]=r;r.version=M.version
  if r.enabled==nil then r.enabled=true end;r.stats=r.stats or{};r.snapshots=r.snapshots or{};return r
end
local function enabled() return root().enabled~=false end
local function stat(k,n)local r=root();r.stats[k]=(r.stats[k]or 0)+(tonumber(n)or 1)end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function pair_key(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number)or(valid(p.priest)and p.priest.unit_number))or nil end
local function current_order(p)local q=p and p.order_queue_0469;return p and((q and q.current)or p.active_order_0469)or nil end
local function item_from(v)if type(v)=="string"then return v end;if type(v)~="table"then return nil end;return v.item or v.item_name or v.output_item or v.wanted_item or v.requested_item or v.resource end

local function normalize_kind(v)
  local k=lower(v);if k==""then return"idle"end
  local aliases={
    {"roboport%-repair%-pack%-logistics","roboport-repair-pack-logistics"},{"roboport_repair_pack_logistics","roboport-repair-pack-logistics"},
    {"artillery%-logistics","artillery-logistics"},{"artillery_logistics","artillery-logistics"},
    {"rocket%-silo%-logistics","rocket-silo-logistics"},{"rocket_silo_logistics","rocket-silo-logistics"},
    {"energy%-family%-logistics","energy-family-logistics"},{"energy_family_logistics","energy-family-logistics"},
    {"item%-family%-logistics","item-family-logistics"},{"item_family_logistics","item-family-logistics"},
    {"machine%-logistics","machine-logistics"},{"machine_logistics","machine-logistics"},
  }
  for _,a in ipairs(aliases)do if k:find(a[1])then return a[2]end end
  if k:find("combat%-repair")then return"combat-repair"end
  if k:find("combat",1,true)or k:find("defend",1,true)then return"combat"end
  if k:find("repair",1,true)then return"repair"end
  if k:find("consecr",1,true)or k:find("sanct",1,true)then return"consecration"end
  if k:find("construct",1,true)or k:find("build",1,true)then return"construction"end
  if k:find("craft",1,true)or k:find("fabric",1,true)then return"crafting"end
  if k:find("machine",1,true)or k:find("logistic",1,true)or k:find("supply",1,true)or k:find("scav",1,true)or k:find("mine",1,true)or k:find("acqui",1,true)or k:find("gather",1,true)or k:find("resource",1,true)or k:find("emergency",1,true)then return"acquisition"end
  if k:find("return",1,true)or k:find("travell",1,true)or k:find("moving",1,true)then return"movement"end
  return k
end
local function entity_or_position(v,seen)
  if valid(v)then return v,v.position end;if type(v)~="table"then return nil,nil end
  seen=seen or{};if seen[v]then return nil,nil end;seen[v]=true
  if v.x and v.y then return nil,v end;if type(v.position)=="table"and v.position.x and v.position.y then return nil,v.position end
  for _,k in ipairs{"target","source","entity","resource_entity","mining_target","candidate","current","selected","node","destination","task"}do local e,p=entity_or_position(v[k],seen);if e or p then return e,p end end
  return nil,nil
end
local function current_target(p,o)
  local values={o and o.target,o and o.task,p and p.direct_acquisition_custody_0513,p and p.direct_acquisition_task_0336,p and p.emergency_craft,p and p.consecration_0515,p and p.repair_0516,p and p.combat_repair_0517,
    p and p.construction_task_0338,p and p.construction_custody_0338,p and p.construction_candidate_0338,
    p and p.machine_logistics_0528,p and p.item_family_logistics_0702,p and p.item_family_custody_0702,p and p.item_family_candidate_0702,
    p and p.energy_family_logistics_0707,p and p.energy_family_custody_0707,p and p.energy_family_candidate_0707,
    p and p.rocket_silo_logistics_0710,p and p.rocket_silo_custody_0710,p and p.rocket_silo_candidate_0710,
    p and p.artillery_logistics_0713,p and p.artillery_custody_0713,p and p.artillery_candidate_0713,
    p and p.roboport_repair_logistics_0715,p and p.roboport_repair_custody_0715,p and p.roboport_repair_candidate_0715,p and p.active_task,p and p.active_task_0285,p and p.target}
  for _,v in ipairs(values)do local e,pos=entity_or_position(v);if e or pos then return e,pos end end;return nil,nil
end
local function actual_crafting(p,o)
  if normalize_kind(o and o.kind)=="crafting"then return true end
  local t=p and(p.emergency_craft or p.station_crafting_task_0337 or p.station_craft_0337 or p.active_craft_0479);if not t then return false end
  local current=type(t)=="table"and(t.current or t.entity or t.target);if valid(current)or type(current)=="table"then return false end
  local due=tonumber(t.craft_due_tick or t.build_due_tick or t.station_craft_due_tick_0337 or t.due_tick);return due~=nil or t.station_craft_pending_0337==true
end
local function hostile(priest,target)
  if not(valid(priest)and valid(target)and priest.force and target.force)or priest.force==target.force then return false end
  local ok,v=pcall(function()return priest.force.is_enemy and priest.force.is_enemy(target.force)end);return ok and v==true
end
local function recommendation(global_name,module_name,pair,kind)
  local mod=rawget(_G,global_name)or package.loaded[module_name];if not(mod and type(mod.recommend_action)=="function")then return nil end
  local ok,a=pcall(mod.recommend_action,pair);return ok and type(a)=="table"and a.kind==kind and a or nil
end
local function combat_repair_recommendation(p,order_kind,mode_kind)
  if order_kind~="idle"or not(mode_kind=="combat"or valid(p.combat_target))then return nil end
  return recommendation("TechPriestsCombatRepairDoctrine0517","scripts.core.combat_repair_doctrine_0517",p,"combat-repair")
end
local function construction_recommendation(p,order_kind,mode_kind)
  if order_kind~="idle"and order_kind~="construction"then return nil end;if mode_kind=="combat"or valid(p.combat_target)then return nil end
  return recommendation("TechPriestsConstructionPlanner0338","scripts.core.construction_planner",p,"construction")
end
local function machine_logistics_recommendation(p,order_kind,mode_kind)
  if order_kind~="idle"or mode_kind=="combat"or valid(p.combat_target)then return nil end
  return recommendation("TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528","scripts.core.logistics_machine_fulfillment_0528",p,"machine-logistics")
end
local function item_family_recommendation(p,k)if k~="idle"and k~="item-family-logistics"then return nil end;return recommendation("TechPriestsItemFamilyLogistics0702","scripts.core.item_family_logistics_0702",p,"item-family-logistics")end
local function energy_family_recommendation(p,k)if k~="idle"and k~="energy-family-logistics"then return nil end;return recommendation("TechPriestsEnergyFamilyLogistics0707","scripts.core.energy_family_logistics_0707",p,"energy-family-logistics")end
local function rocket_silo_recommendation(p,k)if k~="idle"and k~="rocket-silo-logistics"then return nil end;return recommendation("TechPriestsRocketSiloLogistics0710","scripts.core.rocket_silo_logistics_0710",p,"rocket-silo-logistics")end
local function artillery_recommendation(p,k)if k~="idle"and k~="artillery-logistics"then return nil end;return recommendation("TechPriestsArtilleryLogistics0713","scripts.core.artillery_logistics_0713",p,"artillery-logistics")end
local function roboport_recommendation(p,k)if k~="idle"and k~="roboport-repair-pack-logistics"then return nil end;return recommendation("TechPriestsRoboportRepairPackLogistics0715","scripts.core.roboport_repair_pack_logistics_0715",p,"roboport-repair-pack-logistics")end

function M.action(p)
  if not valid_pair(p)then return{kind="invalid",family="invalid"}end
  local o=current_order(p);local target,position=current_target(p,o);local order_kind=normalize_kind(o and(o.kind or o.type or o.source));local mode_kind=normalize_kind(p.mode)
  local combat_rec=combat_repair_recommendation(p,order_kind,mode_kind);local construction_rec=construction_recommendation(p,order_kind,mode_kind);local machine_rec=machine_logistics_recommendation(p,order_kind,mode_kind)
  local item_rec=item_family_recommendation(p,order_kind);local energy_rec=energy_family_recommendation(p,order_kind);local silo_rec=rocket_silo_recommendation(p,order_kind);local artillery_rec=artillery_recommendation(p,order_kind);local roboport_rec=roboport_recommendation(p,order_kind)
  local active_construction=construction_rec and construction_rec.active==true and construction_rec or nil
  local active_item=item_rec and item_rec.active==true and item_rec or nil;local active_energy=energy_rec and energy_rec.active==true and energy_rec or nil;local active_silo=silo_rec and silo_rec.active==true and silo_rec or nil;local active_artillery=artillery_rec and artillery_rec.active==true and artillery_rec or nil;local active_roboport=roboport_rec and roboport_rec.active==true and roboport_rec or nil
  local selected=combat_rec or active_construction or active_item or active_energy or active_silo or active_artillery or active_roboport or construction_rec or machine_rec or item_rec or energy_rec or silo_rec or artillery_rec or roboport_rec
  local kind,reason
  if p.idle_player_conversation_0181 or p.idle_conversation then kind,reason="conversation","conversation-surface"
  elseif actual_crafting(p,o)then kind,reason="crafting","crafting-surface"
  elseif order_kind=="combat-repair"then kind,reason="combat-repair","order"
  elseif combat_rec then kind,reason="combat-repair","tactical-recommendation";target=combat_rec.target;position=valid(target)and target.position or combat_rec.position
  elseif active_construction then kind,reason="construction","active-construction-custody";target=active_construction.target;position=valid(target)and target.position or active_construction.position
  elseif active_item then kind,reason="item-family-logistics","active-item-family-custody";target=active_item.target;position=valid(target)and target.position or active_item.position
  elseif active_energy then kind,reason="energy-family-logistics","active-energy-family-custody";target=active_energy.target;position=valid(target)and target.position or active_energy.position
  elseif active_silo then kind,reason="rocket-silo-logistics","active-rocket-silo-custody";target=active_silo.target;position=valid(target)and target.position or active_silo.position
  elseif active_artillery then kind,reason="artillery-logistics","active-artillery-custody";target=active_artillery.target;position=valid(target)and target.position or active_artillery.position
  elseif active_roboport then kind,reason="roboport-repair-pack-logistics","active-roboport-custody";target=active_roboport.target;position=valid(target)and target.position or active_roboport.position
  elseif order_kind=="combat"or(hostile(p.priest,target)and mode_kind=="combat")then kind,reason="combat","order-or-hostile-target"
  elseif order_kind=="repair"then kind,reason="repair","order" elseif order_kind=="consecration"then kind,reason="consecration","order" elseif order_kind=="construction"then kind,reason="construction","order"
  elseif order_kind=="machine-logistics"or order_kind=="item-family-logistics"or order_kind=="energy-family-logistics"or order_kind=="rocket-silo-logistics"or order_kind=="artillery-logistics"or order_kind=="roboport-repair-pack-logistics"then kind,reason=order_kind,"order"
  elseif order_kind=="acquisition"then kind,reason="acquisition","order" elseif order_kind=="movement"then kind,reason="movement","order"
  elseif construction_rec then kind,reason="construction","construction-recommendation";target=construction_rec.target;position=valid(target)and target.position or construction_rec.position
  elseif machine_rec then kind,reason="machine-logistics","machine-recommendation";target=machine_rec.target;position=valid(target)and target.position or machine_rec.position
  elseif item_rec then kind,reason="item-family-logistics","item-family-recommendation";target=item_rec.target;position=valid(target)and target.position or item_rec.position
  elseif energy_rec then kind,reason="energy-family-logistics","energy-family-recommendation";target=energy_rec.target;position=valid(target)and target.position or energy_rec.position
  elseif silo_rec then kind,reason="rocket-silo-logistics","rocket-silo-recommendation";target=silo_rec.target;position=valid(target)and target.position or silo_rec.position
  elseif artillery_rec then kind,reason="artillery-logistics","artillery-recommendation";target=artillery_rec.target;position=valid(target)and target.position or artillery_rec.position
  elseif roboport_rec then kind,reason="roboport-repair-pack-logistics","roboport-recommendation";target=roboport_rec.target;position=valid(target)and target.position or roboport_rec.position
  elseif mode_kind~="idle"then kind,reason=mode_kind,"compatibility-mode"else kind,reason="idle","no-current-order"end
  return{kind=kind,family=kind,target=target,position=position,item=selected and selected.item or o and(o.item or item_from(o.task))or item_from(p.active_supply_request)or item_from(p.logistic_requested_item)or item_from(p.emergency_craft)or item_from(p.direct_acquisition_task_0336),order_key=o and o.key,order_status=o and o.status,source=selected and selected.source or reason,reason=selected and selected.reason or reason,phase=selected and selected.phase}
end
M.classify=M.action
local function destroy_visual(o)if o then pcall(function()if o.valid==nil or o.valid then o.destroy()end end)end end
function M.clear_beams(p)if not p then return end;destroy_visual(p.scan_line_render);p.scan_line_render=nil;destroy_visual(p.mining_beam_render);p.mining_beam_render=nil;local key=pair_key(p);local work=storage and storage.tech_priests and storage.tech_priests.tech_priests_work_visuals_0323;if work and work.scan_lines and key then destroy_visual(work.scan_lines[key]);work.scan_lines[key]=nil end end
function M.allow_scan(p,target)if not enabled()then return true end;if not valid_pair(p)then return false end;local a=M.action(p);if a.kind~="acquisition"then M.clear_beams(p);stat("scan_suppressed");return false end;if valid(target)and valid(a.target)and target~=a.target then stat("scan_target_mismatch");return false end;if valid(target)and(dist_sq(p.priest.position,target.position)or 0)>M.close_distance_sq then stat("remote_scan_suppressed");return false end;return true end
function M.allow_laser(priest,target)if not enabled()then return true end;if not valid(priest)then return false end;local p=storage and storage.tech_priests and(storage.tech_priests.pairs_by_priest or{})[priest.unit_number];if not valid_pair(p)then return true end;local a=M.action(p);if hostile(priest,target)then local ok=a.kind=="combat";if not ok then stat("combat_laser_suppressed")end;return ok end;if a.kind~="acquisition"then M.clear_beams(p);stat("laser_suppressed_wrong_action");return false end;if valid(target)and valid(a.target)and target~=a.target then stat("laser_target_mismatch");return false end;if valid(target)and(dist_sq(priest.position,target.position)or 0)>M.close_distance_sq then stat("remote_laser_suppressed");return false end;return true end
local STATUS={conversation="Conversing",combat="Battle rite engaged",["combat-repair"]="Combat repair litany",repair="Repair litany in progress",consecration="Consecration rite in progress",construction="Construction rite in progress",["machine-logistics"]="Machine logistics",["item-family-logistics"]="Item logistics",["energy-family-logistics"]="Energy logistics",["rocket-silo-logistics"]="Rocket silo logistics",["artillery-logistics"]="Artillery logistics",["roboport-repair-pack-logistics"]="Roboport repair logistics",acquisition="Acquiring field materials",crafting="Crafting"}
function M.status(p)if not valid_pair(p)then return nil,nil end;local a=M.action(p);local text=STATUS[a.kind];if not text then return nil,nil end;if a.item and a.kind:find("logistics",1,true)then text=text..": "..tostring(a.item):gsub("-"," ")end;return text,{r=.85,g=.85,b=.35,a=.95}end
function M.status_for_pair(p)return M.status(p)end
function M.service_pair(p)if not(enabled()and valid_pair(p))then return nil end;return M.action(p)end
function M.tick_all() return 0 end
local function wrap_visuals()
  if type(_G.draw_emergency_craft_scan_line)=="function"and not previous_scan_line then previous_scan_line=_G.draw_emergency_craft_scan_line;_G.draw_emergency_craft_scan_line=function(p,t)if M.allow_scan(p,t)then return previous_scan_line(p,t)end;return false end end
  if type(_G.tech_priests_0312_fire_laser)=="function"and not previous_fire_laser then previous_fire_laser=_G.tech_priests_0312_fire_laser;_G.tech_priests_0312_fire_laser=function(priest,target,damage,reason,color)if M.allow_laser(priest,target)then return previous_fire_laser(priest,target,damage,reason,color)end;return false end end
  local ok,work=pcall(require,"scripts.core.work_visuals");if ok and type(work)=="table"then work.status_for_pair=function(p)local a=M.action(p);local text,color=M.status(p);return text,a.kind=="acquisition"and a.target or nil,color end;local previous=work.draw_scan_line;if type(previous)=="function"and not work.action_arbiter_0488_wrapped then work.action_arbiter_0488_wrapped=true;work.draw_scan_line=function(p,t)if M.allow_scan(p,t)then return previous(p,t)end end end end
end
local function wrap_overhead()local g=rawget(_G,"TECH_PRIESTS_OVERHEAD_STATUS_GOVERNOR_0471");if g and type(g)=="table"and not g.canonical_status_0488_previous then g.canonical_status_0488_previous=g.canonical_status;g.canonical_status=function(p,incoming)local text,color=M.status(p);if text then return text,color end;return g.canonical_status_0488_previous(p,incoming)end end end
local function wrap_diagnostics()local d=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468");if not(d and type(d.pair_dump_lines)=="function")or d.action_state_wrapped_0488 then return false end;d.action_state_wrapped_0488=true;local previous=d.pair_dump_lines;d.pair_dump_lines=function(...)local lines=previous(...);lines=type(lines)=="table"and lines or{};local r=root();lines[#lines+1]="ACTION-CLASSIFIER-0488 BEGIN pure=true scan_suppressed="..safe(r.stats.scan_suppressed or 0);for key,p in pairs(pair_map())do if valid_pair(p)then local a=M.action(p);lines[#lines+1]="classifier["..safe(key).."] kind="..safe(a.kind).." item="..safe(a.item).." source="..safe(a.source)end end;lines[#lines+1]="ACTION-CLASSIFIER-0488 END";return lines end;return true end
function M.install()root();_G.TECH_PRIESTS_ACTION_STATE_ARBITER_0488=M;wrap_visuals();wrap_overhead();wrap_diagnostics();if commands and commands.remove_command then pcall(commands.remove_command,"tp-action-state-0488")end;if log then log("[Tech-Priests recovery] pure action classifier installed; construction aware; no scheduler or movement ownership")end;return true end
return M
