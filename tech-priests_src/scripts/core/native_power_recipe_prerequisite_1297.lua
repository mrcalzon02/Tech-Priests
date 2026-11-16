-- A missing terrestrial power kit is a real dependency of an engine-only
-- science/lab recipe. Retain the exact parent and let 0647/0514/0338 alone
-- manufacture, carry and build paid items; never alter machine buffers.
local M={}
local kits={["offshore-pump"]=true,boiler=true,["steam-engine"]=true,["small-electric-pole"]=true}
local fields={"active_task","active_task_0285","current_task","active_acquisition_0333",
 "active_supply_request","supply_request","robot_network_request_0338",
 "construction_request","pending_construction","build_request","direct_acquisition_task_0336","direct_acquisition_custody_0513",
 "machine_logistics_custody_0528","emergency_production_custody_0514",
 "emergency_facility_feed_custody_0357","construction_task_0338","construction_custody_0338",
 "inventory_transfer_custody_0687","item_family_custody_0702","energy_family_custody_0707",
 "station_cargo_custody_0824","rocket_silo_custody_0710","repair_pack_custody_0516",
 "station_crafting_task_0337","active_craft_0479","combat_target","robot_network_task_0338"}
local function valid(e)return e and e.valid end
local function safe_context(p,r)
 return p and valid(p.station)and valid(p.priest)and p.priest.surface==p.station.surface
  and p.priest.force==p.station.force and not p.station.surface.platform
  and(not r or(r.station==p.station and r.surface==p.station.surface and r.force==p.station.force))
end
local function unladen(p)
 for _,f in ipairs(fields)do if p[f]~=nil and p[f]~=false then return false end end
 if p.machine_logistics_0528 and p.machine_logistics_0528.custody then return false end
 if p.movement_request_0418 then return false end
 local o=p.order_queue_0469 and p.order_queue_0469.current or p.active_order_0469
 return not(o and o.status=="active")
end
function M.request_owned(p)
 local r=p and p.native_power_recipe_prerequisite_1297
 if not r then return false end
 local q=p.infrastructure_recipe_request_0647
 for _=1,8 do
  if q==r.request then return true end
  if type(q)~="table"then break end
  q=q.parent_request_0647
 end
 return false
end
function M.begin(p,reason)
 local item=type(reason)=="string"and reason:match("^equipment%-shortage:(.+)$")
 local t=p and p.emergency_craft;local n=t and(t.output_item or t.item_name)
 if not(kits[item]and safe_context(p)and unladen(p)
  and p.independent_emergency_operation_0184 and p.independent_emergency_operation_0184.enabled==true
  and not p.native_power_recipe_prerequisite_1297 and not p.infrastructure_recipe_request_0647
  and type(t)=="table"and t.infrastructure_first_0640==true and t.strict_recipe_0647==true
  and t.facility_only_0647==true and type(n)=="string"and(n=="lab"or n:match("science%-pack$")))then return false end
 local recipe=p.station.force.recipes and p.station.force.recipes[item]
 if not(recipe and recipe.enabled==true)then return false end
 local observed=p.power_setup_observation_1252
 if not(observed and observed.tick==game.tick and observed.reason==reason and observed.load_unit)then return false end
 local request={tick=game.tick,item=item,reason="native-power-kit-prerequisite-1297",target_stock_0647=1}
 p.native_power_recipe_prerequisite_1297={item=item,parent_task=t,parent_gate=p.local_infrastructure_gate_0640,
  request=request,station=p.station,surface=p.station.surface,force=p.station.force,
  load_unit=observed.load_unit,started_tick=game.tick}
 p.emergency_craft=nil;p.infrastructure_recipe_request_0647=request
 p.local_infrastructure_gate_0640=nil;p.mode="infrastructure-material-acquisition-0647"
 return true
end
function M.restore(p)
 local r=p and p.native_power_recipe_prerequisite_1297
 if not(r and safe_context(p,r)and unladen(p)and not p.emergency_craft and M.request_owned(p))then return false end
 local observed=p.power_setup_observation_1252
 if not(observed and observed.tick==game.tick and observed.reason~="equipment-shortage:"..r.item)then return false end
 local radius=tonumber(p.radius)or 36
 local get_radius=rawget(_G,"get_station_operating_radius")
 if type(get_radius)=="function"then
  local ok,n=pcall(get_radius,p.station)
  if ok and tonumber(n)then radius=tonumber(n)end
 end
 radius=math.max(12,math.min(72,radius))
 local ok,entities=pcall(function()return p.station.surface.find_entities_filtered{
  name=r.item,force=r.force,position=p.station.position,radius=radius}end)
 local installed=false
 for _,e in pairs(ok and entities or{})do
  if valid(e)and e.force==r.force and e.surface==r.surface then installed=true;break end
 end
 if not installed then return false end
 p.emergency_craft=r.parent_task;p.infrastructure_recipe_request_0647=nil
 p.local_infrastructure_gate_0640=r.parent_gate;p.native_power_recipe_prerequisite_1297=nil
 p.native_power_recipe_last_1297={item=r.item,started_tick=r.started_tick,resumed_tick=game.tick,
  parent_item=r.parent_task.output_item or r.parent_task.item_name}
 p.mode="infrastructure-first-0643"
 return true
end
return M
