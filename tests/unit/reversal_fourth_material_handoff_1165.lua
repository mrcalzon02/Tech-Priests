-- 1165: exercise ACTUAL 0855 fourth-stage recovery against ACTUAL 0640
-- source-owned uncommitted planning, with three separate counted depots.
-- No stubbed material grant, settlement, station-mine or movement debit.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local names={"scripts.core.station_recycling_0822",
  "scripts.core.station_relocation_0823",
  "scripts.core.station_cargo_0824",
  "scripts.core.station_starvation_depot_0852",
  "scripts.core.station_starvation_rebuild_0867",
  "scripts.core.cooperative_labor_allocator_0690"}
local old={}
for _,n in ipairs(names)do old[n]=package.loaded[n] end
local force,surface={index=1},{index=1}
local magos={
 station={valid=true,unit_number=10,
   name="planetary-magos-cogitator-station",surface=surface,force=force,
   position={x=0,y=0}},
 priest={valid=true,unit_number=110,position={x=0,y=0}},
 mode="infrastructure-material-acquisition-0647"}
local senior={
 station={valid=true,unit_number=20,name="senior-cogitator-station",
   surface=surface,force=force,position={x=40,y=0}},
 priest={valid=true,unit_number=120,position={x=40,y=0}}}
magos.command_hierarchy_0480={direct_subordinate_units={20}}
senior.command_hierarchy_0480={superior_unit=10,
  direct_subordinate_units={},peer_units={}}
local stage_items={"junior-cogitator-station",
  "junior-cogitator-station","intermediate-cogitator-station"}
local units,parents={50,40,30},{40,30,20}
local receipts={}
local rec={id=42,status="active",station_item="senior-cogitator-station",
  worker_station_unit=10,requester_station_unit=10}
local plan={status="leaf-first-preflight-only",stages={},
  root_station_unit=10,required_item=rec.station_item,
  target={x=1000,y=1000}}
local stage_keys={"reversal_stage_0851","reversal_stage_0853",
  "reversal_stage_0854"}
for i=1,3 do
  local item=stage_items[i]
  local inv={valid=true}
  inv.get_item_count=function(q)return q==item and 1 or 0 end
  local stage={id=i==1 and "reversal-leaf:42:50"
    or "reversal-ancestor:42:"..i..":"..units[i],
    phase="in-magos-depot",station_item=item,
    leaf_station_unit=units[i],worker_station_unit=parents[i]}
  receipts[stage]=inv
  plan.stages[i]={item=item,station_unit=units[i],
    parent_station_unit=parents[i]}
  rec[stage_keys[i]]=stage
end
plan.stages[4]={item=rec.station_item,station_unit=20,
  parent_station_unit=10}
rec.reversal_plan_0850=plan
magos.station_expansion_0256=rec
magos.resource_expansion_0259={chain_0820={target={x=1000,y=1000}}}
local tp={
 pairs_by_station={[10]=magos,[20]=senior},
 pairs_by_priest={[110]=magos,[120]=senior},
 station_expansion_0256={[42]=rec},
 station_expansion_by_worker_0256={[10]=42}}
storage={tech_priests=tp}
game={tick=45000}
defines={command={go_to_location=1},distraction={none=1}}
TECH_PRIESTS_COMMAND_HIERARCHY_0480={
 rank=function(p)return p==magos and 4 or p==senior and 3 or 0 end,
 is_direct_subordinate=function(p,c)return p==magos and c==senior end}
package.loaded[names[1]]={
 check_candidate=function(p,c,item)
   assert(p==magos and c==senior and item=="senior-cogitator-station")
   return true
 end}
package.loaded[names[2]]={
 try_stage_leaf=function()
   error("planning handoff must never mine a station") end}
package.loaded[names[3]]={}
package.loaded[names[4]]={
 get_staged=function(root,stage)
   if root~=magos or not receipts[stage]
       or receipts[stage].get_item_count(stage.station_item)~=1 then
     return nil,"missing-real-depot" end
   return {inventory=receipts[stage]}
 end}
package.loaded[names[5]]={audit=function()return nil end}
package.loaded[names[6]]={}
local Senior=require("scripts.core.station_starvation_senior_0855")
local Governor=require("scripts.core.infrastructure_first_governor_0640")
TechPriestsInfrastructureFirstGovernor0640=Governor
TechPriestsStationStarvationReversal0850={
 future_worker_reserved=function(p)return p==magos,rec end}
tech_priests_0248_higher_priority_probe=function()
 return {priority="idle"} end
local function pending()
 magos.mode="infrastructure-material-acquisition-0647"
 magos.infrastructure_recipe_request_0647={
   item="burner-mining-drill",missing="iron-plate"}
 magos.requested_item="iron-plate"
 magos.logistic_requested_item="iron-plate"
 magos.logistic_requested_count=4
 magos.local_infrastructure_gate_0640={item="burner-mining-drill"}
end
local function depots_intact()
 for i=1,3 do local s=rec[stage_keys[i]]
   assert(receipts[s].get_item_count(s.station_item)==1) end
end
pending()
magos.machine_logistics_custody_0528={item="coal",count=1}
local ok,reason=Senior.yield_uncommitted_magos_material_plan_1165(
 magos,rec,plan)
assert(not ok and reason:find("active%-duty")
 and magos.mode=="infrastructure-material-acquisition-0647"
 and magos.machine_logistics_custody_0528.count==1
 and magos.requested_item=="iron-plate",
 "real coal custody preempted by fourth-stage planning")
magos.machine_logistics_custody_0528=nil
local stage3=rec.reversal_stage_0854
rec.reversal_stage_0854=nil
ok,reason=Senior.yield_uncommitted_magos_material_plan_1165(
 magos,rec,plan)
assert(not ok and reason:find("preflight")
 and magos.mode=="infrastructure-material-acquisition-0647",
 "missing third physical depot allowed a premature Senior")
rec.reversal_stage_0854=stage3
local read=receipts[stage3].get_item_count
receipts[stage3].get_item_count=function()return 0 end
ok=Senior.yield_uncommitted_magos_material_plan_1165(
 magos,rec,plan)
assert(not ok and magos.mode=="infrastructure-material-acquisition-0647",
 "empty physical Intermediate depot authorized Senior recovery")
receipts[stage3].get_item_count=read
tp.station_expansion_by_worker_0256[10]=nil
ok,reason=Senior.yield_uncommitted_magos_material_plan_1165(
 magos,rec,plan)
assert(not ok and reason=="fourth-magos-original-writ-not-owned",
 "foreign original worker writ took ownership of Magos")
tp.station_expansion_by_worker_0256[10]=42
magos.requested_item="copper-plate"
ok,reason=Senior.yield_uncommitted_magos_material_plan_1165(
 magos,rec,plan)
assert(not ok and reason:find("foreign%-request")
 and magos.requested_item=="copper-plate",
 "foreign acquisition request cleared without inventory custody")
magos.requested_item="iron-plate"
local served,why=Senior.service(magos,rec,plan,function()return true end)
assert(served and why=="reversal-senior-magos-walking-to-station"
 and rec.reversal_stage_0855
 and rec.reversal_stage_0855.phase=="to-leaf"
 and rec.reversal_stage_0855.leaf_station_unit==20
 and magos.mode=="idle"
 and magos.infrastructure_recipe_request_0647==nil
 and magos.requested_item==nil and magos.logistic_requested_item==nil
 and magos.local_infrastructure_gate_0640==nil
 and rec.reversal_senior_material_yield_1165.accepted==true
 and tp.pairs_by_station[20]==senior,
 "original Senior 0855 service failed valid 0640 uncommitted handoff")
depots_intact()
local original=rec.reversal_stage_0855
local repeated,next_reason=Senior.service(magos,rec,plan,
 function()return true end)
assert(repeated and next_reason=="reversal-senior-magos-walking-to-station"
 and rec.reversal_stage_0855==original,
 "fourth Senior leg duplicated its physical stage")
pending()
original.phase="to-magos"
ok,reason=Senior.yield_uncommitted_magos_material_plan_1165(
 magos,rec,plan)
assert(not ok and reason=="fourth-magos-uncommitted-plan-domain-or-stage-invalid"
 and magos.mode=="infrastructure-material-acquisition-0647",
 "live physical Senior cargo was discarded as idle planning")
depots_intact()
for _,n in ipairs(names)do package.loaded[n]=old[n] end
print("[reversal-fourth-material-handoff-1165] PASS original owner 0640 planning yield, 0855 third-depot preflight, active cargo, foreign work and no duplicate Senior stage")
