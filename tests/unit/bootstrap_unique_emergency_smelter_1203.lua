-- 1203: a real same-force emergency smelter fulfills the one-time
-- local bootstrap role even if built somewhere other than the ghost tile.
-- The ghosts are only proposals: never duplicate the physical smelter or
-- discard an already-debited 0338 item/custody route.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=36000}
storage={tech_priests={pairs_by_station={}}}
defines={direction={north=0},distraction={none=0}}
prototypes={entity={["tech-priests-emergency-smelter"]={
  type="assembling-machine"}},item={
 ["tech-priests-emergency-smelter"]={
  place_result={name="tech-priests-emergency-smelter"}}}}
local force={valid=true,index=1,name="player"}
local other_force={valid=true,index=2,name="enemy"}
local surface={index=1}
local station={valid=true,unit_number=300,name="intermediate-cogitator-station",
 position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,unit_number=301,position={x=0,y=0},
 force=force,surface=surface}
local existing={valid=true,unit_number=302,name="tech-priests-emergency-smelter",
 type="assembling-machine",position={x=9,y=0},
 force=force,surface=surface,
 bounding_box={left_top={x=8.6,y=-0.4},
 right_bottom={x=9.4,y=0.4}}}
local ghost
local function make_ghost()
 local g={valid=true,unit_number=303,name="entity-ghost",
 ghost_name="tech-priests-emergency-smelter",
 position={x=2,y=0},surface=surface,force=force,
 selection_box={left_top={x=1.5,y=-0.5},
 right_bottom={x=2.5,y=0.5}}}
 g.destroy=function()g.valid=false;return true end
 ghost=g
 return g
end
surface.find_entities_filtered=function(args)
 -- Mimic Factorio's filtered real-entity query; the ghost proximity query
 -- also sees the distant smelter, but their bounding boxes do not overlap.
 if args.name=="tech-priests-emergency-smelter" then return {existing} end
 return {existing,ghost}
end
local pair={station=station,priest=priest,station_unit=300}
storage.tech_priests.pairs_by_station[300]=pair
_G.TechPriestsMasterInfrastructurePlan0644={
 build_plan=function()
  return {stage="basic-crafting",target={
   preferred_item="tech-priests-emergency-smelter",
   class="smelting"}}
 end}
local Ghosts=require("scripts.core.construction_bootstrap_ghost_planner_0645")
local function assign_ghost()
 local g=make_ghost()
 local r={item="tech-priests-emergency-smelter",
 entity_name="tech-priests-emergency-smelter",ghost=g,position=g.position,
 status="ghosted"}
 pair.construction_bootstrap_ghost_0645=r
 pair.construction_candidate_0338={
  request_field="construction_bootstrap_ghost_0645",
  request_value=r,entity_name=r.entity_name,position=r.position}
 return r,g
end
local record,g=assign_ghost()
local ok,why=Ghosts.service_pair(pair,"already-built")
assert(ok==false and why=="bootstrap-facility-already-physical"
 and not g.valid and not pair.construction_bootstrap_ghost_0645
 and not pair.construction_candidate_0338 and existing.valid,
 "stale ghost did not retire when a real local smelter exists")
-- A task holding construction custody cannot be erased by the ghost planner.
record,g=assign_ghost()
pair.construction_task_0338={phase="move-site",
 request_field="construction_bootstrap_ghost_0645",
 request_value=record,item_name=record.item,entity_name=record.entity_name,
 position=g.position,ghost=g,started_tick=game.tick}
pair.construction_custody_0338={item_name=record.item,count=1}
ok,why=Ghosts.service_pair(pair,"custody-pending")
assert(ok==false and why=="bootstrap-smelter-custody-pending"
 and g.valid and pair.construction_task_0338
 and pair.construction_custody_0338.count==1,
 "ghost planner discarded real in-flight construction custody")
-- The sole physical builder returns exactly that item to its real source.
local stocked=0
local inventory={valid=true,
 insert=function(stack)stocked=stocked+stack.count;return stack.count end}
pair.construction_task_0338.source_entity=station
pair.construction_task_0338.source_inv=inventory
pair.construction_task_0338.carried={item_name=record.item,count=1}
local Construction=require("scripts.core.construction_planner")
local result=Construction.service_pair(pair,"duplicate-present")
assert(result and pair.construction_task_0338==nil
 and pair.construction_custody_0338==nil
 and stocked==1 and existing.valid
 and pair.construction_last_task_0338
 and pair.construction_last_task_0338.result:find(
  "bootstrap-smelter-already-physical-1203",1,true),
 "physical 0338 cargo was not refunded after duplicate detection")
ok,why=Ghosts.service_pair(pair,"after-refund")
assert(ok==false and why=="bootstrap-facility-already-physical"
 and not g.valid and pair.construction_bootstrap_ghost_0645==nil,
 "stale ghost survived after exact-item refund")
-- Foreign forces and remote machines never satisfy the local bootstrap role.
record,g=assign_ghost()
existing.force=other_force
ok,why=Ghosts.service_pair(pair,"foreign-machine")
assert(ok==false and why=="active-ghost-present" and g.valid,
 "foreign machine wrongly retired our planning ghost")
existing.force=force
existing.position={x=40,y=0}
ok,why=Ghosts.service_pair(pair,"outside-station-range")
assert(ok==false and why=="active-ghost-present" and g.valid,
 "distant machine wrongly satisfied local construction")
-- The native engine previously built two starter smelters despite the
-- bootstrap-only guard. Cover the older direct request paths as well.
existing.position={x=9,y=0}
g.destroy()
pair.construction_bootstrap_ghost_0645=nil
pair.construction_candidate_0338=nil
pair.construction_requested_item="tech-priests-emergency-smelter"
local before=stocked
local result=Construction.service_pair(pair,"direct-request-already-built")
assert(result and not pair.construction_requested_item
 and not pair.construction_task_0338 and not pair.construction_candidate_0338
 and stocked==before and existing.valid,
 "non-ghost request debited another physical smelter")
-- An already-debited machine must return to its real inventory before its
-- obsolete commissioning request is retired.
pair.structure_construction_requested_item="tech-priests-emergency-smelter"
pair.construction_task_0338={
 phase="move-site",request_field="structure_construction_requested_item",
 request_value=pair.structure_construction_requested_item,
 item_name="tech-priests-emergency-smelter",
 entity_name="tech-priests-emergency-smelter",position={x=5,y=0},
 source_entity=station,source_inv=inventory,
 carried={item_name="tech-priests-emergency-smelter",count=1},
 started_tick=game.tick}
pair.construction_custody_0338={
 item_name="tech-priests-emergency-smelter",count=1}
result=Construction.service_pair(pair,"non-ghost-custody-return")
assert(result and not pair.structure_construction_requested_item
 and not pair.construction_task_0338 and not pair.construction_custody_0338
 and stocked==before+1 and existing.valid
 and pair.construction_last_task_0338
 and pair.construction_last_task_0338.result:find(
   "bootstrap-smelter-already-physical-1205",1,true),
 "non-ghost duplicate did not refund original physical custody")
print("[bootstrap-unique-emergency-smelter-1203] PASS ghost and direct request uniqueness, counted custody refunds, force/radius isolation")
