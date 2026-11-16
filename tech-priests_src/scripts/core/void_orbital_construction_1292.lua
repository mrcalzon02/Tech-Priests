-- Local Void construction, executed ONLY by original 0338. No broker/tick,
-- remote ghosts, free tiles or scripted material production.
local ProductionOrder=require("scripts.core.production_order_ownership_0514")
local M={}
local function valid(e)return e and e.valid end
local function count(inv,item)return inv and inv.valid and inv.get_item_count(item)or 0 end
local function dist(a,b)return(a.x-b.x)^2+(a.y-b.y)^2 end
function M.context(p)
 if not(p and valid(p.station)and valid(p.priest)and p.station.name=="void-cogitator-station"
  and(p.priest.name=="void-tech-priest"or p.priest.name=="void-tech-priest-belt-immune")
  and p.priest.force==p.station.force and p.priest.surface==p.station.surface)then return nil end
 local platform=p.station.surface.platform
 if not(valid(platform)and platform.force==p.station.force and valid(platform.hub)
   and platform.hub.force==p.station.force and platform.hub.surface==p.station.surface)then return nil end
 return platform
end
function M.owns(p)
 local t=p and p.construction_task_0338;local c=p and p.construction_custody_0338
 return t and t.void_orbital_1292==true or c and c.void_orbital_1292==true or false
end
local function order_allows(p)
 local o=p.order_queue_0469 and p.order_queue_0469.current or p.active_order_0469
 return not o or o.status~="active"or ProductionOrder.matches(p,o,p.emergency_craft)
end
local function admitted(p)
 if not(M.context(p)and p.independent_emergency_operation_0184 and p.independent_emergency_operation_0184.enabled==true
   and order_allows(p)and not valid(p.combat_target))then return false end
 if p.emergency_craft and not(p.emergency_craft.strict_recipe_0647 and p.emergency_craft.facility_only_0647)then return false end
 for _,f in ipairs{"direct_acquisition_task_0336","direct_acquisition_custody_0513","machine_logistics_custody_0528",
  "item_family_custody_0702","energy_family_custody_0707","inventory_transfer_custody_0687",
  "emergency_facility_feed_custody_0357","emergency_production_custody_0514","station_cargo_custody_0824",
  "repair_pack_custody_0516","rocket_silo_custody_0710","defense_task_0259"}do if p[f]then return false end end
 return not(p.machine_logistics_0528 and p.machine_logistics_0528.custody)
end
local function hub_inventory(platform)return platform.hub.get_inventory(defines.inventory.hub_main)end
function M.layout(platform)
 local hub=platform.hub;local x=math.floor(hub.position.x)-1
 local y=math.floor(hub.bounding_box.left_top.y)-2
 local tiles={};for row=0,2 do for dx=0,2 do tiles[#tiles+1]={x=x+dx,y=y-row}end end
 return tiles,{x=x+1.5,y=y-.5}
end
local function solar_at(platform,pos)
 local found=platform.surface.find_entities_filtered{name="solar-panel",position=pos,radius=.1,force=platform.force,limit=1}
 return found[1]and valid(found[1])and found[1]or nil
end
function M.next_need(p)
 local platform=M.context(p);if not platform then return nil end
 local tiles,solar=M.layout(platform)
 for _,pos in ipairs(tiles)do if platform.surface.get_tile(pos).name~="space-platform-foundation"then
  return{item_name="space-platform-foundation",kind="tile",position=pos,platform=platform}
 end end
 if not solar_at(platform,solar)then return{item_name="solar-panel",kind="entity",position=solar,platform=platform}end
end
function M.offer(p)
 if not admitted(p)then return nil end
 if(p.void_orbital_retry_1292 or 0)>game.tick then return nil end
 if p.construction_task_0338 or p.construction_custody_0338 then return nil end
 local need=M.next_need(p);if not need then return nil end
 local inv=hub_inventory(need.platform)
 if count(inv,need.item_name)<1 then return nil end
 need.source_entity=need.platform.hub;need.source_inv=inv
 return need
end
function M.material_request(platform)
 if not(valid(platform)and valid(platform.hub))then return nil end
 local map=storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}
 local ok,stations=pcall(function()return platform.surface.find_entities_filtered{name="void-cogitator-station",force=platform.force,limit=8}end)
 if not(ok and type(stations)=="table")then return nil end
 for _,station in pairs(stations)do
  local p=map[station.unit_number];local plan=p and p.void_orbital_plan_1292
  if p and plan and plan.hub_unit==platform.hub.unit_number and plan.force_index==platform.force.index
    and M.context(p)==platform and p.independent_emergency_operation_0184
    and p.independent_emergency_operation_0184.enabled==true and order_allows(p)then
   local need=M.next_need(p)
   if need then
    local required=1
    if need.kind=="tile"then required=0;local tiles=M.layout(platform)
     for _,pos in ipairs(tiles)do if platform.surface.get_tile(pos).name~="space-platform-foundation"then required=required+1 end end
    end
    local t=p.construction_task_0338
    local held=t and t.void_orbital_1292 and count(t.inventory,need.item_name)or 0
    local missing=required-count(hub_inventory(platform),need.item_name)-held
    if missing>0 then return{item=need.item_name,count=missing,manager_station=station.unit_number}end
   end
  end
 end
end
function M.recommend(p)
 local task=p and p.construction_task_0338
 local c=p and p.construction_custody_0338
 if M.owns(p)then task=task or c.orbital_task_1292
 else task=M.offer(p)end
 if not task then return nil end
 return{kind="construction",family="construction",active=M.owns(p),void_orbital_1292=true,
  target=task.source_entity,position=task.position,item=task.item_name,source="construction-planner-0338",
  reason="local-void-paid-orbital-construction"}
end
local function reach(pos,box)
 local a,b=box.left_top,box.right_bottom
 return math.max(a.x-pos.x,0,pos.x-b.x)^2+math.max(a.y-pos.y,0,pos.y-b.y)^2
end
local function target_box(t)
 local p=t.position
 if t.kind=="tile"then return{left_top={x=p.x,y=p.y},right_bottom={x=p.x+1,y=p.y+1}}end
 local size=1.5
 return{left_top={x=p.x-size,y=p.y-size},right_bottom={x=p.x+size,y=p.y+size}}
end
local function move_to_box(p,box,move,why)
 local b=box.right_bottom;local a=box.left_top
 return move(p,{x=b.x+.8,y=math.max(a.y,math.min(b.y,p.priest.position.y))},why,.15)
end
local function sync(p,t)
 local n=count(t.inventory,t.item_name)
 if n>0 then p.construction_custody_0338={void_orbital_1292=true,orbital_task_1292=t,
  item_name=t.item_name,count=n,native_inventory=t.inventory,position=t.position,source_entity=t.source_entity}
 elseif p.construction_custody_0338 and p.construction_custody_0338.void_orbital_1292 then p.construction_custody_0338=nil end
end
local function finish(p,t,why,release)
 if t.inventory and t.inventory.valid then assert(t.inventory.is_empty());t.inventory.destroy()end
 if p.construction_task_0338==t then p.construction_task_0338=nil end
 sync(p,t);p.void_orbital_construction_last_1292={tick=game.tick,item_name=t.item_name,
  kind=t.kind,position=t.position,result=why,source_unit=t.source_unit}
 if why~="void-paid-foundation-built"and why~="void-paid-solar-built"then p.void_orbital_retry_1292=game.tick+300 end
 release(p)
 return{processed=1,acted=1,detail=why}
end
local function return_item(p,t,move,release)
 local n=count(t.inventory,t.item_name)
 if n==0 then return finish(p,t,"void-build-empty-custody-retired",release)end
 local source=t.source_entity
 if not(valid(source)and source.force==t.source_force and source.surface==t.source_surface and t.source_inv.valid)then
  return{processed=1,blocked=1,detail="void-custody-source-unavailable"}
 end
 if p.priest.surface~=source.surface then return{processed=1,blocked=1,detail="void-custody-surface-changed"}end
 if reach(p.priest.position,source.bounding_box)>2.56 then
  if not move_to_box(p,source.bounding_box,move,"void-build-actual-custody-return-1292")then
   return{processed=1,blocked=1,detail="void-custody-return-movement-denied"}
  end
  return{processed=1,waiting=1,detail="void-build-returning-actual-custody"}
 end
 local removed=t.inventory.remove{name=t.item_name,count=n}
 local inserted=t.source_inv.insert{name=t.item_name,count=removed}
 if inserted<removed then t.inventory.insert{name=t.item_name,count=removed-inserted}end
 sync(p,t)
 if count(t.inventory,t.item_name)==0 then return finish(p,t,"void-build-actual-item-returned",release)end
 return{processed=1,blocked=1,detail="void-custody-source-full"}
end
local function site_clear(p,t)
 local s=t.platform.surface
 if t.kind=="entity"then return s.can_place_entity{name=t.item_name,position=t.position,force=t.source_force}end
 if s.get_tile(t.position).name~="empty-space"then return false end
 local connected=false
 for _,d in ipairs{{1,0},{-1,0},{0,1},{0,-1}}do
  if s.get_tile{x=t.position.x+d[1],y=t.position.y+d[2]}.name=="space-platform-foundation"then connected=true end
 end
 if not connected then return false end
 for _,e in pairs(s.find_entities_filtered{area={{t.position.x,t.position.y},{t.position.x+1,t.position.y+1}}})do
  if valid(e)and e~=p.priest then return false end
 end
 return true
end
function M.service(p,move,release,abort_reason)
 local t=p.construction_task_0338
 if not t and p.construction_custody_0338 and p.construction_custody_0338.void_orbital_1292 then
  t=p.construction_custody_0338.orbital_task_1292
  if not t then return{processed=1,blocked=1,detail="void-custody-context-missing"}end
  p.construction_task_0338=t;t.phase="return-custody"
 end
 if not t then
  t=M.offer(p);if not t then return nil end
  t.void_orbital_1292=true;t.phase="move-source";t.started_tick=game.tick
  t.source_force=p.station.force;t.source_surface=p.station.surface
  t.source_unit=t.source_entity.unit_number
  p.void_orbital_plan_1292={hub_unit=t.source_unit,platform_index=t.platform.index,
   force_index=p.station.force.index,manager_station=p.station.unit_number,started_tick=game.tick}
  p.construction_task_0338=t
 end
 if not t.void_orbital_1292 then return nil end
 if p.construction_custody_0338 and not p.construction_custody_0338.void_orbital_1292 then
  return{processed=1,blocked=1,detail="foreign-construction-custody"}
 end
 if abort_reason or not admitted(p)or M.context(p)~=t.platform or game.tick-t.started_tick>7200 then t.phase="return-custody"end
 if t.phase=="return-custody"then return return_item(p,t,move,release)end
 if t.phase=="move-source"then
  if not(valid(t.source_entity)and t.source_inv.valid)then return finish(p,t,"void-source-lost-before-pickup",release)end
  if reach(p.priest.position,t.source_entity.bounding_box)>2.56 then
   if not move_to_box(p,t.source_entity.bounding_box,move,"void-build-hub-pickup-1292")then
    return{processed=1,blocked=1,detail="void-hub-approach-denied"}
   end
   return{processed=1,waiting=1,detail="void-moving-to-real-hub-stock"}
  end
  t.inventory=game.create_inventory(1)
  local removed=t.source_inv.remove{name=t.item_name,count=1}
  if removed~=1 then return finish(p,t,"void-source-empty",release)end
  local inserted=t.inventory.insert{name=t.item_name,count=removed}
  if inserted~=1 then t.source_inv.insert{name=t.item_name,count=removed-inserted};return finish(p,t,"void-cargo-refused",release)end
  t.phase="move-site";sync(p,t)
  return{processed=1,waiting=1,detail="void-real-build-item-picked-up"}
 end
 local box=target_box(t)
 if reach(p.priest.position,box)>2.56 then
  if not move_to_box(p,box,move,"void-build-local-placement-1292")then
   return{processed=1,blocked=1,detail="void-site-approach-denied"}
  end
  return{processed=1,waiting=1,detail="void-moving-paid-kit-to-site"}
 end
 if not site_clear(p,t)then t.phase="return-custody";return return_item(p,t,move,release)end
 if count(t.inventory,t.item_name)~=1 then t.phase="return-custody";return return_item(p,t,move,release)end
 assert(t.inventory.remove{name=t.item_name,count=1}==1)
 local surface=t.platform.surface
 local ok,built=pcall(function()
  if t.kind=="tile"then
   surface.set_tiles({{name="space-platform-foundation",position=t.position}},false,false,false,false)
   return surface.get_tile(t.position).name=="space-platform-foundation"
  end
  return surface.create_entity{name=t.item_name,position=t.position,force=t.source_force,raise_built=true}
 end)
 local actual=t.kind=="tile"and surface.get_tile(t.position).name=="space-platform-foundation"
  or t.kind=="entity"and solar_at(t.platform,t.position)
 if not actual then t.inventory.insert{name=t.item_name,count=1};sync(p,t);t.phase="return-custody";return return_item(p,t,move,release)end
 sync(p,t)
 return finish(p,t,t.kind=="tile"and"void-paid-foundation-built"or"void-paid-solar-built",release)
end
return M
