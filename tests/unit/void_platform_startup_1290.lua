package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local file="tech-priests_src/prototypes/compatibility/platform-void-startup_1290.lua"
local pack={weight=1000000,initial_items={{name="space-platform-foundation",amount=10}},
 trigger={{type="direct",action_delivery={type="instant",source_effects={{type="create-entity",entity_name="space-platform-hub"}}}}},tiles={}}
for x=-5,4 do for y=-5,4 do pack.tiles[#pack.tiles+1]={tile="space-platform-foundation",position={x,y}}end end
data={raw={["space-platform-starter-pack"]={["space-platform-starter-pack"]=pack},container={["void-cogitator-station"]={}}}}
dofile(file);dofile(file)
assert(#pack.trigger==2 and #pack.tiles==104 and pack.weight==1000000 and pack.initial_items[1].amount==10)
local effect=pack.trigger[2].action_delivery.source_effects[1]
assert(effect.entity_name=="void-cogitator-station"and effect.trigger_created_entity and effect.offsets[1][1]==6)
local seen={};for _,t in ipairs(pack.tiles)do
 local p=t.position;local key=(p.x or p[1])..":"..(p.y or p[2]);assert(not seen[key]);seen[key]=true
 assert(t.tile=="space-platform-foundation")
end
assert(seen["5:-1"]and seen["6:0"],"startup station lacks attached native foundation")
game={tick=1000};storage={tech_priests={pairs_by_station={},orbital_campaign_1287={by_force={}}}}
local force={index=1};local surface={index=2};local platform={valid=true,index=3,force=force,surface=surface};surface.platform=platform
local station={valid=true,name="void-cogitator-station",unit_number=4,force=force,surface=surface}
local made,enabled=0,0
on_built=function(event)
 assert(event.entity==station)
 if storage.tech_priests.pairs_by_station[4]then return end
 made=made+1;storage.tech_priests.pairs_by_station[4]={station=station,
  priest={valid=true,name="void-tech-priest",unit_number=5,force=force,surface=surface}}
end
tech_priests_set_emergency_operation_0184=function(p,on)
 assert(p.station==station and on==true);enabled=enabled+1;p.independent_emergency_operation_0184={enabled=true}
end
local parent={independent_emergency_operation_0184={enabled=true}}
storage.tech_priests.pairs_by_station[1]=parent
storage.tech_priests.orbital_campaign_1287.by_force[1]={platform=platform,station_unit=1}
local M=require("scripts.core.void_platform_startup_1290")
assert(not M.on_created{entity={valid=true,name="solar-panel"}}and made==0)
surface.platform=nil;assert(not M.on_created{entity=station}and made==0)
surface.platform=platform;assert(M.on_created{entity=station}and made==1 and enabled==1)
assert(M.on_created{entity=station}and made==1 and enabled==1,"duplicate native trigger reset or duplicated the priest")
local p=storage.tech_priests.pairs_by_station[4]
assert(p.platform_startup_1290.platform_index==3 and p.emergency_operation_auto_allowed_0190)
platform.force={index=2};assert(not M.on_created{entity=station}and made==1)
local manual_force={index=2};local manual_surface={index=9}
manual_surface.platform={valid=true,index=10,force=manual_force}
local manual={valid=true,name="void-cogitator-station",unit_number=11,force=manual_force,surface=manual_surface}
on_built=function(e)assert(e.entity==manual);storage.tech_priests.pairs_by_station[11]={station=manual,
 priest={valid=true,force=manual_force,surface=manual_surface}}end
assert(M.on_created{entity=manual})
assert(not storage.tech_priests.pairs_by_station[11].independent_emergency_operation_0184 and enabled==1,
 "ordinary player ship inherited an unrelated expedition's independent mode")
script={active_mods={}};assert(M.install(),"base-only profile attempted to register a Space Age event")
print("PASS native starter Void berth, one canonical local priest, mode inheritance and duplicate/context guards")
