-- A request adapter serviced by 0510. No independent scheduler or tactical AI.
-- Physical construction belongs to 0338, physical supply to 0702, combat to AAI.
local C=require("shared.combat_roster_catalog")
local Bridge=require("scripts.core.combat_roster_bridge")
local Logistics=require("scripts.core.item_family_logistics_0702")
local Planner=require("scripts.core.construction_planner")
local M={}
local function valid(e) return e and e.valid end
local function root()
 storage.tech_priests=storage.tech_priests or {}
 local tp=storage.tech_priests
 tp.combat_roster_orders=tp.combat_roster_orders or {next_id=1,actors={}}
 return tp.combat_roster_orders
end
local function valid_pair(pair)
 return pair and valid(pair.station) and valid(pair.priest) and pair.station.force==pair.priest.force
  and pair.station.surface==pair.priest.surface
end
local function position(p)
 return type(p)=="table" and type(p.x)=="number" and type(p.y)=="number"
  and p.x==p.x and p.y==p.y and math.abs(p.x)<1000000 and math.abs(p.y)<1000000
end
function M.request(pair,id,deploy,rally,quality)
 local u=C.by_id[id]
 if not(valid_pair(pair) and u and position(deploy) and position(rally or deploy)) then return false,"invalid-order" end
 if pair.combat_muster_order then return false,"muster-already-pending" end
 if pair.combat_construction_request then return false,"construction-request-already-pending" end
 local allowed=settings.startup["tech-priests-combat-allow-"..u.faction]
 if allowed and not allowed.value then return false,"faction-disabled" end
 if not(pair.station.force.recipes[u.name] and pair.station.force.recipes[u.name].enabled) then return false,"unit-not-researched" end
 quality=quality or "normal"
 if not prototypes.quality[quality] then return false,"unknown-quality" end
 if quality~="normal" then
  local upgrade=pair.station.force.technologies[u.name.."-reinforcement"]
  if not(upgrade and upgrade.researched) then return false,"reinforcement-not-researched" end
 end
 local s=root();local token=s.next_id;s.next_id=token+1
 local request={item_name=u.name,entity_name=u.name,position={x=deploy.x,y=deploy.y},quality=quality,combat_muster_token=token,source="combat-muster"}
 pair.combat_muster_order={id=token,unit_id=id,quality=quality,phase="construction",issued_tick=game.tick,request=request,
  deploy={x=deploy.x,y=deploy.y},rally={x=(rally or deploy).x,y=(rally or deploy).y}}
 pair.combat_construction_request=request
 if not(pair.construction_task_0338 or pair.construction_custody_0338) then
  Planner.discover_pair(pair,true)
 end
 return true,token
end
function M.on_built(pair,task,built)
 if not(valid_pair(pair) and valid(built) and built.type=="car" and built.force==pair.station.force) then return false end
 local unit=C.for_entity_name(built.name)
 if not(unit and C.by_name[task.item_name] and C.by_name[task.item_name].id==unit.id) then return false end
 local order=pair.combat_muster_order
 if not order then
  -- Ordinary 0338 construction/ghost completion also belongs to its actual
  -- builder. Arm and supply that real unit, then hold the construction site;
  -- subsequent commander orders still go through native AAI.
  local state=root();local id=state.next_id;state.next_id=id+1
  local p=built.position
  order={id=id,unit_id=unit.id,quality=built.quality.name,phase="supply",issued_tick=game.tick,
   deploy={x=p.x,y=p.y},rally={x=p.x,y=p.y},source="ordinary-priest-construction"}
  pair.combat_muster_order=order
 elseif not(type(task.request_value)=="table" and task.request_value.combat_muster_token==order.id) then
  -- Keep the existing pending command intact; still record the actual builder.
  root().actors[built.unit_number]=pair.station.unit_number
  return true
 end
 -- Called by 0338 only AFTER its actual item has been spent. This receipt
 -- does not create a vehicle, item, ammunition, energy or damage.
 order.actor=built;order.phase="supply";order.built_tick=game.tick
 root().actors[built.unit_number]=pair.station.unit_number
 return true
end
function M.replaced(data)
 local state=storage.tech_priests and storage.tech_priests.combat_roster_orders
 if not state then return end
 local owner=state.actors[data.old_entity_unit_number]
 if not owner then return end
 local pairs=storage.tech_priests.pairs_by_station or {}
 local pair=pairs[owner]
 if pair then Logistics.on_combat_replaced(pair,data.old_entity,data.new_entity) end
 -- A priest can own older units while constructing/supplying another. Only
 -- the order that actually held this body may follow its AAI replacement.
 if pair and pair.combat_muster_order and pair.combat_muster_order.actor==data.old_entity
  and valid(data.new_entity) then
  pair.combat_muster_order.actor=data.new_entity
 end
 if pair and pair.combat_muster_last and valid(data.new_entity)
  and pair.combat_muster_last.actor==data.old_entity then pair.combat_muster_last.actor=data.new_entity end
 state.actors[data.old_entity_unit_number]=nil
 if valid(data.new_entity) then state.actors[data.new_entity.unit_number]=owner end
end
function M.service_pair(pair)
 -- This adapter is called by a pcall-isolated dispatcher. Preserve the usual
 -- dispatcher receipt on every entry, including offers blocked by other work.
 local order=pair.combat_muster_order
 if not(order and valid_pair(pair)) then return false end
 order.last_service_tick=game.tick
 local u=C.by_id[order.unit_id]
 if order.phase=="failed" then
  if not pair.item_family_logistics_0702 and not pair.item_family_custody_0702 then
   pair.combat_muster_last=order;pair.combat_muster_order=nil
  end
  return false
 end
 if order.phase=="construction" then
  if not order.request and not(pair.combat_construction_request or pair.construction_task_0338 or pair.construction_custody_0338) then
   local request={item_name=u.name,entity_name=u.name,position=order.deploy,combat_muster_token=order.id,source="combat-muster"}
   order.request=request;pair.combat_construction_request=request
   Planner.discover_pair(pair,true)
  end
  return false
 end
 local actor=order.actor
 if not valid(actor) then order.phase="failed";order.reason="deployed-actor-lost";return false end
 if actor.force~=pair.station.force or actor.surface~=pair.station.surface then
  order.phase="failed";order.reason="deployed-actor-force-or-surface-changed";return false
 end
 if order.phase=="supply" then
  local ammo=C.ammo[u.ammo_family].name
  if Logistics.combat_supply_count(actor.get_inventory(defines.inventory.car_ammo),ammo)<1 then
   Logistics.offer_combat_supply(pair,actor,ammo,"ammo",2);return false
  end
  local fuel=actor.get_fuel_inventory()
  if Logistics.combat_supply_count(fuel,"tech-priests-field-supply-pack")<1 and actor.burner.remaining_burning_fuel<=0 then
   Logistics.offer_combat_supply(pair,actor,"tech-priests-field-supply-pack","supply",2);return false
  end
  if pair.item_family_logistics_0702 or pair.item_family_custody_0702 then return false end
  local ok,why=Bridge.command(actor,pair.station.force,{position=order.rally})
  if not ok then order.reason=why;return false end
  order.phase="commanded";order.command_tick=game.tick
  pair.combat_muster_last=order;pair.combat_muster_order=nil
  return true
 end
 return false
end
function M.command_owned(pair,actor,order)
 if not(valid_pair(pair) and valid(actor) and root().actors[actor.unit_number]==pair.station.unit_number) then
  return false,"not-this-priests-unit"
 end
 return Bridge.command(actor,pair.station.force,order)
end
function M.recommend_action(pair)
 local order=pair and pair.combat_muster_order
 local build=pair and (pair.construction_task_0338 or pair.construction_candidate_0338)
 local ordinary=not order and build and C.by_name[build.item_name]
  and build.request_field and pair[build.request_field]==build.request_value
  and build.site_reason=="funded-combat-construction"
 if not((order or ordinary) and valid_pair(pair)) or valid(pair.combat_target) or pair.defense_task_0259 then return nil end
 -- Read-only admission into the existing classifier; existing real custody
 -- and explicit unrelated player work retain their normal owners.
 for _,field in ipairs({"direct_acquisition_custody_0513","emergency_production_custody_0514",
  "consecration_refund_custody_0515","repair_pack_custody_0516","energy_family_custody_0707",
  "rocket_silo_custody_0710","artillery_custody_0713","roboport_repair_custody_0715",
  "inventory_transfer_custody_0687","station_cargo_custody_0824","emergency_facility_feed_custody_0357",
  "machine_logistics_custody_0528"}) do if pair[field] then return nil end end
 if pair.machine_logistics_0528 and pair.machine_logistics_0528.custody then return nil end
 local current=pair.order_queue_0469 and pair.order_queue_0469.current or pair.active_order_0469
 if current and current.kind~="logistics" and current.source~="assign_task" and current.source~="adopt-active" then return nil end
 if ordinary then
  if pair.item_family_custody_0702 then return nil end
  return Planner.recommend_action(pair)
 end
 if order.phase=="construction" then
  if pair.item_family_custody_0702 then return nil end
  local task=pair.construction_task_0338 or pair.construction_candidate_0338
  if task and task.request_field=="combat_construction_request" and task.request_value==order.request then
   return Planner.recommend_action(pair)
  end
 elseif order.phase=="supply" or order.phase=="failed" then
  if pair.construction_custody_0338 then return nil end
  local task=pair.item_family_logistics_0702 or pair.item_family_candidate_0702
  if task and task.target==order.actor and (task.family=="combat-ammo" or task.family=="combat-supply") then
   return Logistics.recommend_action(pair)
  end
 end
 return nil
end
function M.install()
 _G.TechPriestsCombatRosterOrders=M
 Bridge.set_replacement_handler(M.replaced)
 local function authorized(data)
  local pair=storage.tech_priests and storage.tech_priests.pairs_by_station
   and storage.tech_priests.pairs_by_station[data.station_unit]
  return valid_pair(pair) and pair.station.force.index==data.force_index and pair or nil
 end
 Bridge.handlers.request_muster=function(data)
  local pair=authorized(data);if not pair then return false,"foreign-station" end
  return M.request(pair,data.unit_id,data.position,data.rally,data.quality)
 end
 Bridge.handlers.command_from_priest=function(data)
  local pair=authorized(data);if not pair then return false,"foreign-station" end
  return M.command_owned(pair,data.entity,data.order)
 end
 local registry=require("scripts.core.runtime_event_registry")
 registry.on_event({defines.events.on_entity_died,defines.events.on_player_mined_entity,defines.events.on_robot_mined_entity},function(e)
  local state=storage.tech_priests and storage.tech_priests.combat_roster_orders
  if state and valid(e.entity) then state.actors[e.entity.unit_number]=nil end
 end,nil,{owner="combat_roster_orders",route="retire-owner-receipt"})
 return true
end
return M
