-- 1093: test the real 0259 executor (no synthetic defense executor).
-- Item custody and physical placement are source-level mocks; Factorio
-- engine movement, real biter combat and fluid delivery remain native gates.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local stock={
 ["gun-turret"]=3,["firearm-magazine"]=120,["laser-turret"]=2,
 ["flamethrower-turret"]=2,["medium-electric-pole"]=0,
 pipe=0,["stone-wall"]=0}
local inv={valid=true}
function inv.get_item_count(name) return stock[name]or 0 end
function inv.get_contents()
 local out={}
 for name,count in pairs(stock)do
  if count>0 then out[#out+1]={name=name,count=count,quality="normal"}end
 end
 return out
end
function inv.remove(args)
 local taken=math.min(stock[args.name]or 0,args.count)
 stock[args.name]=(stock[args.name]or 0)-taken
 return taken
end
function inv.insert(args)
 stock[args.name]=(stock[args.name]or 0)+args.count
 return args.count
end
game={tick=100}
defines={inventory={chest=1,turret_ammo=2},direction={north=0,east=2},
 command={go_to_location=1},distraction={by_enemy=1}}
local force={name="player",index=1}
local surface={}
local made={}
local proto_types={
 ["gun-turret"]="ammo-turret",["laser-turret"]="electric-turret",
 ["flamethrower-turret"]="fluid-turret",
 ["medium-electric-pole"]="electric-pole",pipe="pipe",
 ["stone-wall"]="wall"}
local function proto(name)
 return {type=proto_types[name],
   attack_parameters={range=18},
   get_supply_area_distance=function()return 6 end,
   get_max_wire_distance=function()return 9 end}
end
local entity_proto={}
for name in pairs(proto_types)do entity_proto[name]=proto(name)end
tech_priests_get_entity_prototype_name_from_item_0184=function(name)
 return entity_proto[name]and name or nil
end
tech_priests_get_entity_prototype_0440=function(name)
 return entity_proto[name]
end
tech_priests_get_item_prototype_0440=function(name)
 if name=="firearm-magazine"then return {type="ammo"} end
 return entity_proto[name]and {place_result={name=name}} or nil
end
tech_priests_prototype_table_0440=function(kind)
 if kind~="item"then return {} end
 local out={}
 for name in pairs(entity_proto)do
   out[name]={place_result={name=name}} end
 out["firearm-magazine"]={type="ammo"}
 return out
end
TechPriestsPlanningConstraints0646={
 entity_unlocked=function()return true end,
 item_for_entity=function(name)return entity_proto[name]and name or nil end,
 defense_position_allowed=function()return true end}
local next_unit=100
local function entity(name,pos,extra)
 extra=extra or {}
 next_unit=next_unit+1
 local ammo={valid=true,quantity=0}
 function ammo.get_item_count(item)
  return item=="firearm-magazine"and ammo.quantity or 0 end
 function ammo.insert(st)ammo.quantity=ammo.quantity+st.count;return st.count end
 local e={valid=true,name=name,type=proto_types[name],
   position={x=pos.x,y=pos.y},unit_number=next_unit,
   surface=surface,force=force,prototype=entity_proto[name],
   electric_network_id=extra.electric_network_id,
   energy=extra.energy,fluidbox=extra.fluidbox or {},
   get_inventory=function(id)
     if id==defines.inventory.turret_ammo then return ammo end
   end,
   is_connected_to_electric_network=function()
     return extra.electric_network_id~=nil end}
 made[#made+1]=e
 return e
end
function surface.can_place_entity()return true end
function surface.create_entity(spec)
  -- Only the production 0259 build calls this native placement mock.
  -- Fixtures' preexisting power pole and pipe are not counted as builds.
  return entity(spec.name,spec.position)
end
function surface.find_entities_filtered(spec)
 local out={}
 for _,e in ipairs(made)do
  local ok=e.valid and(not spec.name or spec.name==e.name)
    and(not spec.force or spec.force==e.force)
  if type(spec.type)=="string"then ok=ok and e.type==spec.type
  elseif type(spec.type)=="table"then
    local match=false
    for _,t in ipairs(spec.type)do if t==e.type then match=true end end
    ok=ok and match
  end
  if spec.position and spec.radius then
    local dx=e.position.x-spec.position.x
    local dy=e.position.y-spec.position.y
    ok=ok and dx*dx+dy*dy<=spec.radius*spec.radius
  end
  if spec.area then
    local a,b=spec.area[1],spec.area[2]
    local x0,y0=a.x or a[1],a.y or a[2]
    local x1,y1=b.x or b[1],b.y or b[2]
    ok=ok and e.position.x>=x0 and e.position.x<=x1
      and e.position.y>=y0 and e.position.y<=y1
  end
  if ok then out[#out+1]=e end
 end
 return out
end
local pole=entity("medium-electric-pole",{x=-18,y=0},
 {electric_network_id=7})
local pipe=entity("pipe",{x=0,y=17})
local pipe2=entity("pipe",{x=6,y=17})
local station={valid=true,name="planetary-magos-cogitator-station",
 unit_number=5,position={x=0,y=0},surface=surface,force=force,
 get_inventory=function(id)if id==defines.inventory.chest then return inv end end}
local priest={valid=true,name="tech-priest",unit_number=6,
 position={x=0,y=0},surface=surface,force=force}
local state={threats={},next_scan_tick=0}
local pair={station=station,priest=priest,radius=20,
 defense_perimeter_0259=state}
storage={tech_priests={pairs_by_station={[station.unit_number]=pair}}}
tick_pair=function()return false end
dofile("tech-priests_src/scripts/defense_perimeter.lua")
local bridge=assert(_G.TechPriestsDefensePerimeter0259)
local function attack_at(x,y,wanted)
 state.threats={{position={x=x,y=y},tick=game.tick,
   reason="engine-hostile-damage"}}
 state.next_scan_tick=0
 local before=stock[wanted]
 local started=bridge.service_pair(pair)
 assert(started.acted==1 and pair.defense_task_0259
   and pair.defense_task_0259.type=="build-turret"
   and pair.defense_task_0259.item==wanted,
   "existing 0259 did not select stocked "..wanted)
 -- Source-level movement mock only; not a native engine movement proof.
 local pos=pair.defense_task_0259.position
 priest.position={x=pos.x,y=pos.y}
 game.tick=game.tick+1
 assert(bridge.service_pair(pair).acted==1,
   "0259 did not reach the timed physical build")
 game.tick=game.tick+90
 assert(bridge.service_pair(pair).acted==1
   and stock[wanted]==before-1,
   "0259 did not debit exactly one physically held "..wanted)
 local built=made[#made]
 assert(built and built.name==wanted and built.valid,
   "0259 did not create the correct physically debited entity")
 return built
end
local gun=attack_at(17,0,"gun-turret")
assert(pair.defense_task_0259
 and pair.defense_task_0259.type=="ammo-turret",
 "gun was built without scheduling real ammo supply")
game.tick=game.tick+1
assert(bridge.service_pair(pair).acted==1
 and inv.get_item_count("firearm-magazine")==100
 and gun.get_inventory(defines.inventory.turret_ammo)
  .get_item_count("firearm-magazine")==20,
 "gun refill did not debit the station and load the real turret inventory")
local gun2=attack_at(17,6,"gun-turret")
game.tick=game.tick+1
assert(bridge.service_pair(pair).acted==1,
  "second purchased gun did not receive real source ammunition")
local gun3=attack_at(17,-6,"gun-turret")
game.tick=game.tick+1
assert(bridge.service_pair(pair).acted==1
  and inv.get_item_count("firearm-magazine")==60
  and stock["gun-turret"]==0,
  "three gun line failed physical item/ammunition accounting")
local laser=attack_at(-17,0,"laser-turret")
local laser2=attack_at(-17,6,"laser-turret")
assert(laser and laser2 and stock["laser-turret"]==0,
 "two connected laser installations did not consume both owned items")
local flame=attack_at(0,17,"flamethrower-turret")
local flame2=attack_at(6,17,"flamethrower-turret")
assert(flame and flame2 and stock["flamethrower-turret"]==0,
 "two pipe-supported flamethrowers did not consume both owned items")
local audit=require("scripts.core.defense_layer_audit_1091")
local summary=assert(audit.inspect(surface,force,{x=0,y=0},50))
assert(summary.guns==3 and summary.loaded_guns==3
 and summary.lasers==2 and summary.energized_lasers==0
 and summary.flames==2 and summary.fueled_flames==0,
 "installed laser/flame incorrectly credited as powered or fueled")
-- A nearby pipe is ONLY layout support, never proof of sustained oil supply.
flame.fluidbox[1]={name="light-oil",amount=20}
laser.energy=100
laser.electric_network_id=7
laser.is_connected_to_electric_network=function()return true end
local actually_supplied=assert(audit.inspect(surface,force,{x=0,y=0},50))
assert(actually_supplied.energized_lasers==1
 and actually_supplied.fueled_flames==1
 and pair.defense_perimeter_0259.turrets_built==7,
 "real live energy and oil were ignored by mixed readiness observer")
print("[defense-mixed-turret-1093] PASS 0259 three guns, two lasers, two flames, exact ammunition/item custody and honest unpowered/unfueled status")
