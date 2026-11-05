-- 1251: ordinary stocked pole -> exact 0338 build request beside a
-- physically installed unpowered lab. Never synthesize generator output.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=3000}
defines={inventory={chest=1}}
local force={index=1,name="player",recipes={},technologies={}}
local enemy={index=2,name="enemy"}
local surface={index=1,name="nauvis"}
local station={valid=true,name="planetary-magos-cogitator-station",
 unit_number=10,position={x=0,y=0},surface=surface,force=force}
local priest={valid=true,unit_number=11,position={x=0,y=0},
 force=force,surface=surface}
local lab={valid=true,name="lab",type="lab",unit_number=32,
 position={x=10,y=0},energy=0,surface=surface,force=force}
local built_poles={}
local placeable=true
surface.can_place_entity=function(req)
 assert(req.name=="small-electric-pole" and req.force==force)
 return placeable and req.position.x==13 and req.position.y==0
end
surface.find_entities_filtered=function(req)
 if req.type=="lab" then return {lab} end
 if req.type=="electric-pole" then return built_poles end
 return {}
end
local pair={station=station,priest=priest,radius=30,mode="idle"}
storage={tech_priests={pairs_by_station={[10]=pair}}}
local stock=4
_G.TechPriestsStorageRoleAuthority0686={
 generic_item_count=function(p,item)
  assert(p==pair and item=="small-electric-pole")
  return stock
 end,
}
prototypes={
 item={["small-electric-pole"]={place_result={name="small-electric-pole"}}},
 entity={["small-electric-pole"]={supply_area_distance=2.5}},
}
local Governor=require("scripts.core.infrastructure_first_governor_0640")
local function check(v,why)
 assert(v,"lab-pole-1251 "..why)
end
local acted,reason=Governor.service_pair(pair,"native-lab-electric-access")
local request=pair.structure_construction_requested_item
check(not acted and reason=="lab-power-physical-pole-requested"
 and type(request)=="table"
 and request.item_name=="small-electric-pole"
 and request.entity_name=="small-electric-pole"
 and request.site_reason=="installed-lab-power-supply-1251"
 and request.position.x==13 and request.position.y==0
 and request.lab_unit_1251==32 and stock==4
 and pair.construction_task_0338==nil
 and pair.construction_custody_0338==nil,
 "stored pole was not queued for exact physical 0338 construction")
local acted2,reason2=Governor.request_installed_lab_power_pole_1251(pair)
check(acted2 and reason2=="lab-power-physical-pole-already-requested"
 and pair.structure_construction_requested_item==request and stock==4,
 "repeat plan fabricated stock or replaced original physical request")
-- An already-started *other* 0338 physical transaction must never be
-- preempted even though the lab still needs electric distribution.
pair.structure_construction_requested_item=nil
pair.construction_task_0338={phase="move-source",item_name="boiler"}
local busy,busy_why=Governor.request_installed_lab_power_pole_1251(pair)
check(not busy and busy_why=="lab-power-existing-physical-construction-owner"
 and pair.construction_task_0338.item_name=="boiler" and stock==4,
 "power request stole a real boiler build")
pair.construction_task_0338=nil
-- A foreign or different-surface pole does NOT cover our physical lab.
built_poles={{valid=true,type="electric-pole",force=enemy,surface=surface,
 position={x=13,y=0},prototype={supply_area_distance=2.5}}}
local foreign,foreign_why=Governor.request_installed_lab_power_pole_1251(pair)
check(foreign and foreign_why=="lab-power-physical-pole-requested",
 "foreign pole was mistaken for native power distribution")
pair.structure_construction_requested_item=nil
-- After actual native construction, this is only a distribution proof:
-- no electricity is credited, and generator-readiness stays separate.
built_poles={{valid=true,type="electric-pole",force=force,surface=surface,
 position={x=13,y=0},prototype={supply_area_distance=2.5}}}
local complete,complete_why=Governor.request_installed_lab_power_pole_1251(pair)
check(not complete and complete_why=="lab-power-pole-installed-generator-needed"
 and stock==4 and lab.energy==0
 and pair.structure_construction_requested_item==nil,
 "existing unpowered distribution pole was duplicated or called generated energy")
-- Native 1263: a LAB on another electric network must not accept a pole
-- merely because its physical footprint is nearby. Nor may a genuine
-- network connection be dismissed because the boiler is not yet fueled.
lab.is_connected_to_electric_network=function()return false end
lab.electric_network_id=201
built_poles[1].electric_network_id=200
local different,different_why=Governor.request_installed_lab_power_pole_1251(pair)
check(different and different_why=="lab-power-physical-pole-requested"
 and pair.structure_construction_requested_item
 and stock==4 and lab.energy==0,
 "unconnected native lab was mistaken for covered distribution")
pair.structure_construction_requested_item=nil
lab.electric_network_id=200
local native,native_why=Governor.request_installed_lab_power_pole_1251(pair)
check(not native and native_why=="lab-power-pole-installed-generator-needed"
 and pair.structure_construction_requested_item==nil,
 "same genuine native electric network caused duplicate lab pole build")
lab.electric_network_id=nil
local absent,absent_why=Governor.request_installed_lab_power_pole_1251(pair)
check(absent and absent_why=="lab-power-physical-pole-requested"
 and pair.structure_construction_requested_item,
 "native lab with no network was falsely connected by proximity")
pair.structure_construction_requested_item=nil
lab.is_connected_to_electric_network=nil
built_poles={}
lab.energy=10
local powered=Governor.request_installed_lab_power_pole_1251(pair)
check(not powered and pair.structure_construction_requested_item==nil,
 "actual lab energy still triggered needless pole construction")
lab.energy=0
stock=0
local none,none_why=Governor.request_installed_lab_power_pole_1251(pair)
check(not none and none_why=="lab-power-no-real-stored-pole",
 "no stock was manufactured into a proposed pole")
stock=4
placeable=false
local blocked,blocked_why=Governor.request_installed_lab_power_pole_1251(pair)
check(not blocked and blocked_why=="lab-power-no-legal-pole-site",
 "illegal Factorio placement created a construction request")
placeable=true
-- 1264: in a real crowded factory none of the eight handpicked legacy
-- offsets may be engine-placeable. A native half-tile legal site overlapping
-- the laboratory's actual bounding box must still be discovered.
local original_can_place=surface.can_place_entity
lab.bounding_box={left_top={x=8.8,y=-1.3},
 right_bottom={x=11.2,y=1.3}}
surface.can_place_entity=function(req)
 assert(req.name=="small-electric-pole"and req.force==force)
 return req.position.x==12.5 and req.position.y==2.5
end
local native_site,native_site_why=Governor.request_installed_lab_power_pole_1251(pair)
check(native_site and native_site_why=="lab-power-physical-pole-requested"
 and pair.structure_construction_requested_item
 and pair.structure_construction_requested_item.position.x==12.5
 and pair.structure_construction_requested_item.position.y==2.5
 and stock==4 and lab.energy==0,
 "native bounding-box service area ignored a legal off-axis pole site")
pair.structure_construction_requested_item=nil
surface.can_place_entity=original_can_place
lab.bounding_box=nil
storage.tech_priests.infrastructure_first_governor_0640.audit_only=true
local audit,audit_why=Governor.request_installed_lab_power_pole_1251(pair)
check(not audit and audit_why=="lab-power-audit-only"
 and pair.structure_construction_requested_item==nil,
 "audit-only inspection scheduled physical work")
print("[lab-power-pole-build-request-1251] PASS stocked exact pole request, native site, no item credit, incumbent custody, foreign pole, real distribution, generator not spoofed")
