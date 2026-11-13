-- 1410: live priest doctrine affects only ONE immediate factory object.
-- Read-only factory previews must never invent ghosts or steal 0510/0338.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Doctor=require("scripts.core.priest_factory_doctrine_1410")
local Arterial=require("scripts.core.arterial_planner")
local Map=require("scripts.core.doctrine_map")
game={tick=100}
local force={index=3}
local surface={valid=true,index=7}
local station={valid=true,unit_number=77,name="senior-cogitator-station",
 position={x=0,y=0},surface=surface,force=force}
local priest={valid=true,unit_number=79,position={x=0,y=1},
 surface=surface,force=force}
local pair={station=station,priest=priest}
storage={tech_priests={
 pairs_by_station={[77]=pair},
 station_work_state_memory_0366={by_station={
  ["77"]={priest_profile_0367={
    doctrine="Binharic Main-Bus Orthodoxy",doctrine_camp="main_bus"}}}},
}}
local function check(ok,why)
 assert(ok,"[priest-factory-doctrine-1410] "..why)
end
local profile,reason=Doctor.active_policy(pair)
check(profile and profile.key=="main_bus"
 and profile.source=="existing-priest-dossier-0367"
 and profile.planning_priest_unit==79
 and not profile.construction_authorized,
 "existing priest profile was not mapped into advisory factory policy")
local stage={key="ore-belts",name="transport-belt"}
local aligned={role="ore-belts",entity_name="transport-belt",
 position={x=10,y=0},direction=4,
 native_site_verified=true,real_item_available=true}
local short={role="ore-belts",entity_name="transport-belt",
 position={x=3,y=3},direction=4,
 native_site_verified=true,real_item_available=true}
local options={anchor={x=0,y=0},preferred_axis="horizontal"}
local choice,why=Doctor.select_immediate_site(pair,stage,
 {short,aligned},options)
check(choice and choice.position.x==10 and choice.position.y==0
 and choice.doctrine_key=="main_bus"
 and choice.candidate_count_examined==2
 and not choice.construction_authorized
 and choice.physically_built==false,
 "Main Bus priest did not select its legal aligned site")
local refused,why=Doctor.select_immediate_site(pair,stage,
 {short,aligned,aligned,short,short,aligned,aligned},options)
check(not refused and why=="invalid-or-unbounded-current-object-sites",
 "planner examined more than six positions for one object")
local bogus={role="ore-belts",entity_name="transport-belt",
 position={x=1,y=0},native_site_verified=false,
 real_item_available=true}
choice,why=Doctor.select_immediate_site(pair,stage,{bogus},options)
check(not choice and why=="no-native-verified-current-object-site",
 "unverified construction site was preferred")
for _,camp in ipairs(Map.camps)do
 storage.tech_priests.doctrine_argument_0370={by_station={
  ["77"]={current_camp=camp.key}}}
 local current,err=Doctor.active_policy(pair)
 check(current and current.key==camp.key
   and current.source=="live-priest-alignment-0370"
   and current.read_only and not current.construction_authorized,
   "live Conclave camp not mapped "..camp.key..":"..tostring(err))
end
storage.tech_priests.doctrine_argument_0370.by_station["77"].current_camp=
 "mixed_spaghetti"
local pragmatic=Doctor.select_immediate_site(pair,stage,
 {aligned,short},options)
check(pragmatic and pragmatic.position.x==3 and pragmatic.position.y==3,
 "Spaghetti priest did not prefer immediate shorter local handoff")
storage.tech_priests.doctrine_argument_0370.by_station["77"].current_camp=
 "main_bus"
local work={
 objective_id="gear-feed-01",stage=stage,world_revision=0,
 anchor=options.anchor,preferred_axis=options.preferred_axis,
 candidates={short,aligned},
}
local ticket,why=Arterial.preview_next_priest_factory_object(pair,work)
check(ticket and why=="one-priest-doctrine-factory-object-proposed"
 and ticket.position.x==10 and ticket.doctrine_key=="main_bus"
 and ticket.objective_id=="gear-feed-01"
 and ticket.planning_priest_unit==79
 and ticket.one_current_object_only==true
 and ticket.construction_ghosts==0
 and ticket.construction_authorized==false
 and pair.factory_just_in_time_1410.ticket==ticket,
 "arterial integration did not keep a single doctrine-coded intent")
storage.tech_priests.doctrine_argument_0370.by_station["77"].current_camp=
 "mixed_spaghetti"
for tick=101,200 do
 game.tick=tick
 local repeated,why=Arterial.preview_next_priest_factory_object(pair,work)
 check(not repeated and why=="waiting-for-one-original-factory-object"
   and pair.factory_just_in_time_1410.ticket==ticket
   and ticket.doctrine_key=="main_bus",
   "mid-job doctrine change erased an unchanged valid physical objective")
end
local other={objective_id="copper-feed-02",stage={
 key="buffer-chests",name="steel-chest"},world_revision=0,
 anchor={x=0,y=0},candidates={
  {role="buffer-chests",entity_name="steel-chest",
   position={x=2,y=2},native_site_verified=true,
   real_item_available=true}}}
local overridden,why=Arterial.preview_next_priest_factory_object(pair,other)
check(not overridden and why=="waiting-for-original-factory-object"
 and pair.factory_just_in_time_1410.ticket==ticket,
 "another purpose displaced existing in-flight factory intent")
local seen=0
surface.find_entities_filtered=function(spec)
 seen=seen+1
 return {surface.native_entity}
end
local native={valid=true,name="transport-belt",unit_number=505,
 position={x=4,y=3},force=force,surface=surface}
surface.native_entity=native
game.tick=201
local adopted,why=Arterial.preview_next_priest_factory_object(pair,{
 objective_id="gear-feed-01",stage=stage,world_revision=1,
 native_entity=native,native_role_verified=true,
 anchor=options.anchor,candidates={short,aligned}})
check(not adopted and why=="native-player-or-priest-factory-object-adopted"
 and pair.factory_just_in_time_1410.ticket==nil
 and pair.factory_just_in_time_1410.last_native_unit==505
 and seen==1,
 "real native player alternative was not adopted exactly once")
game.tick=202
local cooling,reason=Arterial.preview_next_priest_factory_object(pair,{
 objective_id="gear-feed-01",stage=stage,world_revision=1,
 anchor=options.anchor,candidates={short,aligned}})
check(not cooling and reason=="one-object-factory-planning-cooldown",
 "immediate duplicate object planning bypassed completion cooldown")
game.tick=262
local after=Arterial.preview_next_priest_factory_object(pair,{
 objective_id="gear-feed-02",stage=stage,world_revision=1,
 anchor=options.anchor,preferred_axis="horizontal",
 candidates={aligned,short}})
check(after and after.position.x==3 and after.position.y==3
 and after.doctrine_key=="mixed_spaghetti"
 and after~=ticket,
 "fresh completed-object boundary ignored live priest doctrine revision")
pair.construction_task_0338={request="held-real-item"}
game.tick=263
local held,why=Arterial.preview_next_priest_factory_object(pair,{
 objective_id="gear-feed-02",stage=stage,world_revision=2,
 anchor=options.anchor,candidates={aligned,short}})
check(not held and why=="original-physical-factory-custody-preserved"
 and pair.factory_just_in_time_1410.ticket==after,
 "revised doctrine or world displaced active original item custody")
pair.construction_task_0338=nil
local cancelled,reason=Arterial.preview_next_priest_factory_object(pair,{
 objective_id="gear-feed-02",stage=stage,world_revision=2,
 anchor=options.anchor,candidates={aligned,short}})
check(not cancelled
 and reason=="changed-world-invalidated-one-factory-object"
 and pair.factory_just_in_time_1410.ticket==nil,
 "relevant changed factory world did not invalidate outdated virtual intent")
game.tick=323
local changed=Arterial.preview_next_priest_factory_object(pair,{
 objective_id="gear-feed-02",stage=stage,world_revision=2,
 anchor=options.anchor,candidates={aligned,short}})
check(changed and changed.doctrine_key=="mixed_spaghetti",
 "factory intent not rethought after explicit native world revision")
storage.tech_priests.doctrine_argument_0370.by_station["77"].current_camp=
 "unregistered-heretical"
local unknown,why=Doctor.active_policy(pair)
check(not unknown and why=="unknown-live-priest-doctrine",
 "unknown self-declared doctrine silently became engineering authority")
storage.tech_priests.doctrine_argument_0370.by_station["77"].current_camp=
 "main_bus"
local foreign={valid=true,unit_number=808,surface=surface,force={index=9}}
pair.priest=foreign
local denied,reason=Doctor.active_policy(pair)
check(not denied and reason=="unregistered-or-foreign-planning-priest",
 "foreign priest inherited original registered factory planning authority")
pair.priest=priest
check(pair.construction_request==nil and pair.machine_logistics_custody_0528==nil,
 "doctrine planning made an unauthorized construction/material transfer")
print("[priest-factory-doctrine-1410] PASS 14 live camps, main-bus vs spaghetti, one intent, player adoption, staged revision/custody, zero ghosts")
