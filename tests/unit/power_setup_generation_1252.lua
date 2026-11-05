-- 1252: physical electric-demand recognition and staged real steam assets.
-- Every request is only an order for existing 0338; no stock is spent here.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=12000}
defines={direction={north=0,east=4,south=8,west=12}}
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
end
local Planner=require("scripts.core.power_setup_1252")
local function check(value,msg)assert(value,"power-setup-1252 "..msg)end
local ghost={item="tech-priests-emergency-miner",status="ghosted"}
pair.construction_bootstrap_ghost_0645=ghost
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
 made[#made+1]=built
 game.tick=game.tick+100
end
local continued,reason=Planner.service_pair(pair)
check(not continued
 and reason=="steam-machinery-present-await-fluid-fuel-or-grid"
 and pair.structure_construction_requested_item==nil
 and pair.construction_bootstrap_ghost_0645==ghost
 and stock["boiler"]==2 and lab.energy==0,
 "mistook bare generated-fluid equipment for real delivered electricity")
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
