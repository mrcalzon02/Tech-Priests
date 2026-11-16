-- 1252: physical electric-demand recognition and staged real steam assets.
-- Every request is only an order for existing 0338; no stock is spent here.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=12000}
defines={direction={north=0,east=4,south=8,west=12},build_check_type={manual=1}}
local force={index=1,name="player"}
local foreign={index=2,name="enemy"}
local surface={valid=true,index=1}
local station={valid=true,unit_number=21,name="planetary-magos-cogitator-station",
 position={x=0,y=0},surface=surface,force=force}
local priest={valid=true,unit_number=22,position={x=0,y=1},surface=surface,force=force}
local pair={station=station,priest=priest,radius=38,mode="idle"}
local lab={valid=true,name="lab",type="lab",unit_number=30,
 position={x=8,y=0},energy=0,force=force,surface=surface}
local made={lab}
local stock={["offshore-pump"]=2,boiler=2,["steam-engine"]=2,
 ["small-electric-pole"]=3}
local water={ {position={x=-15,y=-9}}, {position={x=-16,y=-9}}}
local placeable=true
surface.find_entities_filtered=function(spec)
 local accepted={}
 local types={}
 for _,name in ipairs(type(spec.type)=="table"and spec.type or{spec.type})do
  types[name]=true
 end
 for _,e in ipairs(made)do if types[e.type]then accepted[#accepted+1]=e end end
 return accepted
end
surface.find_tiles_filtered=function()return water end
surface.can_place_entity=function(spec)
 assert(spec.force==force and spec.position)
 assert(spec.build_check_type==defines.build_check_type.manual,
  "power machinery used ghost-revival placement rules")
 if type(placeable)=="function"then return placeable(spec)end
 return placeable
end
storage={tech_priests={pairs_by_station={[21]=pair}}}
_G.TechPriestsStorageRoleAuthority0686={
 generic_item_count=function(p,item)
  assert(p==pair)
  return stock[item]or 0
 end,
}
prototypes={item={},entity={}}
for _,item in ipairs({"offshore-pump","boiler","steam-engine","small-electric-pole"})do
 prototypes.item[item]={place_result={name=item}}
 prototypes.entity[item]={}
 if item=="small-electric-pole"then
  prototypes.entity[item].supply_area_distance=2.5
 end
end
prototypes.entity["offshore-pump"].tile_width=1;prototypes.entity["offshore-pump"].tile_height=1
prototypes.entity["offshore-pump"].fluidbox_prototypes={
 {production_type="output",pipe_connections={{direction=8,
 positions={{x=0,y=0},{x=0,y=0},{x=0,y=0},{x=0,y=0}}}}}}
prototypes.entity.boiler.tile_width=3;prototypes.entity.boiler.tile_height=2
prototypes.entity.boiler.fluidbox_prototypes={
 {production_type="input",pipe_connections={
  {direction=12,positions={{x=-1,y=.5},{x=-.5,y=-1},{x=1,y=-.5},{x=.5,y=1}}},
  {direction=4,positions={{x=1,y=.5},{x=-.5,y=1},{x=-1,y=-.5},{x=.5,y=-1}}}}},
 {production_type="output",pipe_connections={
  {direction=0,positions={{x=0,y=-.5},{x=.5,y=0},{x=0,y=.5},{x=-.5,y=0}}}}}}
prototypes.entity["steam-engine"].tile_width=3;prototypes.entity["steam-engine"].tile_height=5
prototypes.entity["steam-engine"].fluidbox_prototypes={
 {production_type="input",pipe_connections={
  {direction=0,positions={{x=0,y=-2},{x=2,y=0},{x=0,y=2},{x=-2,y=0}}},
  {direction=8,positions={{x=0,y=2},{x=-2,y=0},{x=0,y=-2},{x=2,y=0}}}}}}
local Planner=require("scripts.core.power_setup_1252")
local function check(value,msg)assert(value,"power-setup-1252 "..msg)end
local ghost={item="tech-priests-emergency-miner",status="ghosted"}
pair.construction_bootstrap_ghost_0645=ghost
local audit,audit_reason=Planner.service_pair(pair,{audit_only=true})
check(not audit and audit_reason=="power-setup-audit-only"
 and pair.structure_construction_requested_item==nil,
 "audit-only governor created a power construction request")
local stages={
 {"water-intake","offshore-pump","offshore-pump"},
 {"heat-water","boiler","boiler"},
 {"generate-electricity","steam-engine","generator"},
 {"generation-output-pole","small-electric-pole","electric-pole"},
}
for i,stage in ipairs(stages)do
 local ok,why=Planner.service_pair(pair)
 local request=pair.structure_construction_requested_item
 check(ok and why=="physical-power-build-requested:"..stage[1]..":"..stage[2]
  and request and request.owner=="power-setup-1252"
  and request.item_name==stage[2]
  and request.entity_name==stage[2]
  and request.site_reason=="physical-steam-power-1252:"..stage[1]
  and request.power_setup_load_unit_1252==30
  and pair.construction_task_0338==nil
  and pair.construction_custody_0338==nil
  and pair.construction_bootstrap_ghost_0645==ghost,
  "failed staged physical request "..stage[1])
 local original=request
 local again,again_why=Planner.service_pair(pair)
 check(again and again_why=="power-build-awaiting-original-0338:"..stage[2]
  and pair.structure_construction_requested_item==original
  and stock[stage[2]]==2 or
   (i==4 and again and pair.structure_construction_requested_item==original),
  "double-issued a power request before original physical build")
 -- Emulate the 0338 builder completing the exact native item transaction;
 -- this planner does NOT decrement the material or create the entity itself.
 pair.structure_construction_requested_item=nil
 local built={valid=true,unit_number=40+i,name=stage[2],
  type=stage[3],position={x=request.position.x,y=request.position.y},
  direction=request.direction,force=force,surface=surface}
 if i==4 then built.prototype={supply_area_distance=2.5}end
 if i==1 or i==2 then
  built.fluidbox={valid=true,true,get_pipe_connections=function()
   return{{target_position={x=built.position.x+1,y=built.position.y},target={owner={valid=true}}}}end}
  if i==2 then built.fluidbox[2]=true end
 end
 made[#made+1]=built
 game.tick=game.tick+100
end
local continued,reason=Planner.service_pair(pair)
check(continued
 and reason=="physical-power-build-requested:consumer-electric-pole:small-electric-pole"
 and pair.structure_construction_requested_item.owner=="power-setup-1252"
 and pair.structure_construction_requested_item.power_setup_load_unit_1252==lab.unit_number
 and pair.construction_bootstrap_ghost_0645==ghost
 and stock["boiler"]==2 and lab.energy==0,
 "unpowered installed laboratory was stranded outside the physical power owner")
pair.structure_construction_requested_item=nil
-- 1256: Factorio can build a generator between crowded machines. Its
-- original eight cardinal candidates are obstructed; the legitimate
-- diagonal site inside the actual 2.5-tile supply radius must be found.
local old_pole=table.remove(made)
local generator=made[#made]
check(old_pole and generator.name=="steam-engine",
 "crowded site test lost the real installed generator")
placeable=function(spec)
 if spec.name~="small-electric-pole"then return true end
 return spec.position.x==generator.position.x+1
    and spec.position.y==generator.position.y+1
end
local dense_ok,dense_reason=Planner.service_pair(pair)
local dense_request=pair.structure_construction_requested_item
check(dense_ok and dense_reason==
 "physical-power-build-requested:generation-output-pole:small-electric-pole"
 and dense_request and dense_request.owner=="power-setup-1252"
 and dense_request.position.x==generator.position.x+1
 and dense_request.position.y==generator.position.y+1,
 "blocked cardinal offsets hid an engine-approved diagonal power pole")
pair.structure_construction_requested_item=nil
placeable=function()return false end
local blocked_pole,blocked_pole_reason=Planner.service_pair(pair)
check(not blocked_pole and blocked_pole_reason==
 "site-not-verified:small-electric-pole"
 and not pair.structure_construction_requested_item,
 "completely obstructed native supply square created a fictional pole")
placeable=true
prototypes.entity["small-electric-pole"].supply_area_distance=nil
local unknown_radius,unknown_radius_reason=Planner.service_pair(pair)
check(not unknown_radius and unknown_radius_reason==
 "site-not-verified:small-electric-pole"
 and not pair.structure_construction_requested_item,
 "unknown native pole supply radius authorized a power connection")
prototypes.entity["small-electric-pole"].supply_area_distance=2.5
-- Existing physical custody wins; nothing is retasked or touched.
made={lab}
pair.structure_construction_requested_item=nil
pair.construction_task_0338={phase="move-source",item_name="steel-chest"}
local busy,blocked=Planner.service_pair(pair)
check(not busy and blocked=="physical-owner-busy"
 and pair.construction_task_0338.item_name=="steel-chest",
 "ignored existing physical 0338 ownership")
pair.construction_task_0338=nil
-- No actual water/safe shore => no imaginary pump.
water={}
local no_water,no_water_reason=Planner.service_pair(pair)
check(not no_water and no_water_reason=="site-not-verified:offshore-pump"
 and not pair.structure_construction_requested_item,
 "no water became a fabricated offshore-pump site")
water={{position={x=-15,y=-9}}}
stock["offshore-pump"]=0
local no_stock,stock_reason=Planner.service_pair(pair)
check(not no_stock and stock_reason=="equipment-shortage:offshore-pump"
 and not pair.structure_construction_requested_item,
 "empty physical inventory became an imaginary pump")
stock["offshore-pump"]=2
placeable=false
local blocked_site,site_reason=Planner.service_pair(pair)
check(not blocked_site and site_reason=="site-not-verified:offshore-pump"
 and not pair.structure_construction_requested_item,
 "unplaceable shoreline created a construction request")
placeable=true
lab.energy=5
local powered,powered_reason=Planner.service_pair(pair)
check(not powered and powered_reason=="no-unpowered-native-load"
 and not pair.structure_construction_requested_item,
 "powered lab created redundant steam generation")
lab.energy=0
lab.force=foreign
local foreign_load,foreign_reason=Planner.service_pair(pair)
check(not foreign_load and foreign_reason=="no-unpowered-native-load",
 "foreign laboratory demanded our steam setup")
print("[power-setup-generation-1252] PASS real stored staged pump/boiler/engine/pole plans; owner, site, stock, energy, foreign-force and ghost retention")

lab.force=force;lab.position={x=24,y=-34};lab.energy=0
station.position={x=32,y=-32};pair.radius=40
local pump={valid=true,name="offshore-pump",type="offshore-pump",unit_number=90,
 position={x=18.5,y=-67.5},force=force,surface=surface,
 fluidbox={valid=true,true,get_pipe_connections=function()
  return{{target_position={x=17.5,y=-67.5}}}end}}
made={lab,pump};pair.structure_construction_requested_item=nil
placeable=function(spec)
 if spec.name=="boiler"then
  return spec.position.x>=18 and spec.position.x<=18.5
   and spec.position.y>=-61.5 and spec.position.y<=-61
 end
 if spec.name=="pipe"then return spec.position.x<19.5 end
 return false
end
local placed=Planner.service_pair(pair)
local oriented=pair.structure_construction_requested_item
check(placed and oriented and oriented.item_name=="boiler"
 and oriented.direction==defines.direction.west,
 "shoreline boiler failed to align water toward pump and steam toward buildable land")
check(stock.boiler==2 and not pair.construction_task_0338,
 "fluid-aware planning consumed a boiler or bypassed its original constructor")
pair.structure_construction_requested_item=nil
local boiler_ports_1295=prototypes.entity.boiler.fluidbox_prototypes
prototypes.entity.boiler.fluidbox_prototypes=nil
local unreadable,unreadable_reason=Planner.service_pair(pair)
check(not unreadable and unreadable_reason=="site-not-verified:boiler",
 "unknown native fluid ports authorized an invented steam-plant layout")
print("PASS native prototype ports select a land-facing steam outlet and pump-facing water inlet without spending stock")
pair.structure_construction_requested_item=nil;made={lab}
water={{position={x=18,y=-67}}}
placeable=function(spec)
 if spec.name=="offshore-pump"then return true end
 if spec.name=="pipe"then return false end
 return true
end
local trapped,trapped_reason=Planner.service_pair(pair)
check(not trapped and trapped_reason=="site-not-verified:offshore-pump"
 and not pair.structure_construction_requested_item,
 "engine-placeable pump with an obstructed real pipe outlet was admitted")
placeable=function(spec)
 if spec.name=="pipe"then return spec.position.x>19 end
 return true
end
local usable=Planner.service_pair(pair)
check(usable and pair.structure_construction_requested_item.item_name=="offshore-pump",
 "clear native pump outlet was rejected alongside blocked shoreline directions")
print("PASS shoreline placement requires a real buildable pump outlet and onward pipe contact")
pair.structure_construction_requested_item=nil
made={lab,pump}
placeable=function(spec)
 if spec.name=="pipe"and spec.position.x==17.5 and spec.position.y==-67.5 then return false end
 return true
end
local replacement=Planner.service_pair(pair)
check(replacement and pair.structure_construction_requested_item.item_name=="offshore-pump"
 and pump.valid and stock["offshore-pump"]==2,
 "blocked installed intake could not request a separately paid usable pump")
print("PASS only engine-observed blocked pump outlets permit a new funded native intake")
pair.structure_construction_requested_item=nil;pair.power_engine_site_probe_1282=nil
station.position={x=0,y=0};lab.position={x=8,y=0}
pump.position={x=-5,y=-5}
local boiler={valid=true,name="boiler",type="boiler",unit_number=91,
 position={x=0,y=0},force=force,surface=surface,
 fluidbox={valid=true,true,true,get_pipe_connections=function(index)
  assert(index==2);return{{target_position={x=0,y=1}}}end}}
pump.fluidbox={valid=true,true,get_pipe_connections=function()return{{target=boiler}}end}
made={lab,pump,boiler}
placeable=function(spec)
 if spec.name=="steam-engine"then return spec.position.x==2.5 and spec.position.y==-13.5 end
 return true
end
local recovered=Planner.service_pair(pair)
local engine=pair.structure_construction_requested_item
check(recovered and engine and engine.item_name=="steam-engine"
 and engine.position.x==2.5 and engine.position.y==-13.5 and stock["steam-engine"]==2,
 "sparse steam-engine axes concealed a real funded native grid site")
pair.structure_construction_requested_item=nil;pair.power_engine_site_probe_1282=nil
local checks=0
placeable=function(spec)
 if spec.name=="steam-engine"then checks=checks+1;return false end
 return true
end
Planner.service_pair(pair);local first_checks=checks
Planner.service_pair(pair)
check(first_checks>64 and checks-first_checks<=64,
 "failed local engine grid was repeated every power-planning pulse")
print("PASS engine-verified generator grid fallback and bounded failed-site retry without spending kits")

-- 1295: the native contact-arena pump has usable boiler sites outside all
-- sixteen sparse offsets. Apply the same bounded fallback to the boiler.
prototypes.entity.boiler.fluidbox_prototypes=boiler_ports_1295
pair.structure_construction_requested_item=nil;pair.power_boiler_site_probe_1295=nil
pump.fluidbox={valid=true,true,get_pipe_connections=function()return{{target_position={x=-5,y=-4}}}end}
made={lab,pump}
placeable=function(spec)
 if spec.name=="boiler"then return spec.position.x==2.5 and spec.position.y==-13 end
 return true
end
local recovered_boiler=Planner.service_pair(pair)
local heat=pair.structure_construction_requested_item
check(recovered_boiler and heat and heat.item_name=="boiler"
 and heat.position.x==2.5 and heat.position.y==-13 and stock.boiler==2
 and not pair.construction_task_0338 and not pair.construction_custody_0338,
 "sparse boiler axes concealed a real funded native grid site")
pair.structure_construction_requested_item=nil;pair.power_boiler_site_probe_1295=nil
checks=0
placeable=function(spec)
 if spec.name=="boiler"then checks=checks+1;return false end
 return true
end
Planner.service_pair(pair);local first_boiler_checks=checks
Planner.service_pair(pair)
check(first_boiler_checks>64 and checks-first_boiler_checks<=64,
 "failed local boiler grid was repeated every power-planning pulse")
game.tick=game.tick+601
placeable=function(spec)
 if spec.name=="boiler"then return spec.position.x==2.5 and spec.position.y==-13 end
 return true
end
check(Planner.service_pair(pair)and pair.structure_construction_requested_item.item_name=="boiler",
 "expired boiler refusal prevented discovery of a newly clear native site")
print("PASS native boiler grid fallback, refusal backoff and later retry without spending kits")
