-- Read-only planning/admission for an independent, cold native boiler whose
-- current steam outlet has no legal route. Original 0338 alone rotates it.
local Power=require("scripts.core.power_setup_1252")
local ProductionOrder=require("scripts.core.production_order_ownership_0514")
local M={}
local function valid(e)return e and e.valid end
local function d2(a,b)return(a.x-b.x)^2+(a.y-b.y)^2 end
function M.idle_owner(p,child)
 local op=p and p.independent_emergency_operation_0184
 if not(op and op.enabled==true and valid(p.station)and valid(p.priest)
   and p.priest.force==p.station.force and p.priest.surface==p.station.surface)then return false end
 if valid(p.combat_target)then return false end
 for _,field in ipairs{"construction_task_0338","construction_custody_0338","direct_acquisition_task_0336",
  "direct_acquisition_custody_0513","machine_logistics_custody_0528","item_family_custody_0702",
  "energy_family_custody_0707","inventory_transfer_custody_0687","emergency_production_custody_0514",
  "emergency_facility_feed_custody_0357","station_cargo_custody_0824","repair_pack_custody_0516",
  "consecration_refund_custody_0515","rocket_silo_custody_0710","artillery_custody_0713",
  "roboport_repair_custody_0715","defense_task_0259"}do
   if p[field]and not(field=="direct_acquisition_task_0336"and p[field]==child)then return false end
  end
 if p.emergency_craft and not(p.emergency_craft.strict_recipe_0647 or p.emergency_craft.facility_only_0647)then return false end
 if p.machine_logistics_0528 and p.machine_logistics_0528.custody then return false end
 local order=p.order_queue_0469 and p.order_queue_0469.current or p.active_order_0469
 return not order or order.status~="active"or ProductionOrder.matches(p,order,p.emergency_craft)
  or(child and order.task==child and order.source=="construction-source-clearance-0338")
end
local function cold_boiler(p,e)
 if not(valid(e)and e.name=="boiler"and e.type=="boiler"and e.force==p.station.force
   and e.surface==p.station.surface and e.rotatable~=false)then return false end
 local ok,yes=pcall(function()
  local links=p.station.surface.find_entities_filtered{position=e.position,radius=4,
   force=p.station.force,type={"inserter","loader","loader-1x1"},limit=32}
  for _,link in pairs(links)do
   if link.type=="inserter"and(link.pickup_target==e or link.drop_target==e)
     or(link.type~="inserter"and link.loader_container==e)then return false end
  end
  local inv=e.get_fuel_inventory();if not(inv and inv.valid and inv.is_empty())then return false end
  local burner=e.burner
  if burner and burner.remaining_burning_fuel>0 then return false end
  local fluids=e.get_fluid_contents()
  for name,amount in pairs(fluids)do if name~="water"and amount>0 then return false end end
  return true
 end)
 return ok and yes==true
end
local function scoped(p,e)return valid(e)and e.force==p.station.force and e.surface==p.station.surface end
function M.valid_request(p,r,child)
 if not(M.idle_owner(p,child)and type(r)=="table"and r==p.steam_outlet_reorientation_1288
   and r.expires_tick>=game.tick and cold_boiler(p,r.boiler)and scoped(p,r.engine)
   and r.engine.type=="generator"and r.boiler.direction==r.from_direction
   and d2(r.position,r.boiler.position)<.01 and r.proposal and r.proposal.source
   and r.proposal.source.entity==r.boiler and r.proposal.machine==r.engine
   and r.proposal.fluid=="steam"and r.proposal.direction=="input")then return false end
 local radius=tonumber(p.radius)or 28
 return d2(p.station.position,r.boiler.position)<=(radius-2.5)^2
end
function M.ignorable_tree_tile(p,point,tree)
 if not(valid(tree)and tree.type=="tree"and tree.force.name=="neutral"and tree.surface==p.station.surface)then return false end
 local ok,clear=pcall(function()
  local tile=p.station.surface.get_tile(point)
  local mask=prototypes.entity.pipe.collision_mask.layers
  for layer in pairs(tile.prototype.collision_mask.layers)do if mask[layer]then return false end end
  local found=false
  for _,e in pairs(p.station.surface.find_entities_filtered{area={{point.x-.3,point.y-.3},{point.x+.3,point.y+.3}}})do
   if e==tree then found=true elseif e.type~="resource"then return false end
  end
  return found
 end)
 return ok and clear==true
end
function M.propose(p,proposal,preview)
 if not(type(proposal)=="table"and proposal.direction=="input"
   and proposal.fluid=="steam"and proposal.source and proposal.source.fluidbox_index==2
   and scoped(p,proposal.source.entity)and proposal.source.entity.name=="boiler"and scoped(p,proposal.machine)
   and proposal.machine.type=="generator")then return nil end
 local boiler=proposal.source.entity
 local function refused(why)
  p.steam_outlet_reorientation_probe_1288={tick=game.tick,boiler=boiler.unit_number,reason=why}
  return nil
 end
 if not M.idle_owner(p)then return refused("incumbent-owner")end
 if not cold_boiler(p,boiler)then return refused("not-unautomated-cold-boiler")end
 local previous=p.steam_outlet_reorientation_last_1288
 if previous and previous.boiler==boiler and(previous.retry_tick or 0)>game.tick then return nil end
 local old=p.steam_outlet_reorientation_1288
 if old and M.valid_request(p,old)then return old end
 local direction=(boiler.direction+8)%16
 local center,inputs,outputs=Power.native_port_geometry_1288("boiler",boiler.position,direction)
 if not(center and d2(center,boiler.position)<.01 and #outputs==1)then return refused("native-half-turn-geometry-unavailable")end
 local geometry={boiler=boiler,direction=direction,inputs=inputs,outputs=outputs}
 local route=preview(proposal,geometry)
 local clear_tree
 if not route then
  local output=outputs[1];local next_tile={x=output.x+output.dx,y=output.y+output.dy}
  local ok,trees=pcall(function()return p.station.surface.find_entities_filtered{
   area={{next_tile.x-.7,next_tile.y-.7},{next_tile.x+.7,next_tile.y+.7}},type="tree",force="neutral",limit=8}end)
  if ok then for _,tree in pairs(trees)do
   local safe,wood=pcall(function()
    if tree.minable==false then return false end
    for _,product in pairs(tree.prototype.mineable_properties.products)do if product.name=="wood"then return true end end
    return false
   end)
   if safe and wood and M.ignorable_tree_tile(p,next_tile,tree)then
    geometry.ignore_tree_1288=tree;route=preview(proposal,geometry)
    if route then clear_tree=tree;break end
   end
  end end
 end
 if not route then return refused("alternate-steam-route-unavailable")end
 -- The rotated water inlet must still be physically reconnectable. A full
 -- native water route will be planned normally after rotation; no fluid credit.
 local clear=false
 for _,port in ipairs(inputs)do
  local ok,yes=pcall(function()return p.station.surface.can_place_entity{
   name="pipe",position=port,force=p.station.force}end)
  if ok and yes==true then clear=true;break end
 end
 if not clear then return refused("alternate-water-inlet-unavailable")end
 local r={boiler=boiler,engine=proposal.machine,proposal=proposal,from_direction=boiler.direction,
  direction=direction,position={x=boiler.position.x,y=boiler.position.y},geometry=geometry,
  route=route,clear_tree=clear_tree,created_tick=game.tick,expires_tick=game.tick+1800}
 p.steam_outlet_reorientation_1288=r
 p.steam_outlet_reorientation_probe_1288={tick=game.tick,boiler=boiler.unit_number,reason="native-half-turn-route-proven",tiles=#route}
 return r
end
return M
