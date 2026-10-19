-- Lua 5.2: collected physical output may interrupt an unladen manual
-- acquisition route, but never take ownership of already-carried ore.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=2500}
storage={tech_priests={pairs_by_station={}}}
local surface={index=1}
local force={index=1}
local station={valid=true,unit_number=12,position={x=0,y=0},
  surface=surface,force=force}
local priest={valid=true,unit_number=13,position={x=1,y=0},
  surface=surface,force=force}
local machine={valid=true,name="tech-priests-emergency-miner",
  type="assembling-machine",unit_number=55,position={x=4,y=0},
  surface=surface,force=force}
local pair={station=station,priest=priest,station_unit=12,
  order_queue_0469={current={kind="acquisition",status="active",item="iron-ore"}},
  mode="travelling-to-direct-acquisition"}
storage.tech_priests.pairs_by_station[12]=pair
local Logistics=require("scripts.core.logistics_machine_fulfillment_0528")
local Arbiter=require("scripts.core.action_state_arbiter_0488")
_G.TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528=Logistics
_G.TechPriestsDirectAcquisitionExecutor0513={
  current_direct_task=function()return {kind="direct-mine-0336"},
    {kind="direct-mine-0336"} end
}
local function check(ok,detail)
  if not ok then error("machine-output-handoff regression: "..detail,2) end
end
pair.machine_logistics_candidate_0528={
  action="clear-output",item="iron-ore",count=8,
  machine=machine,expires_tick=game.tick+250}
local yield_ok=Logistics.yield_for_bootstrap(pair,"dispatcher")
check(yield_ok==false and pair.machine_logistics_candidate_0528,
  "pending physically produced ore discarded on every direct acquisition pulse")
local rec=Logistics.recommend_action(pair)
check(rec and rec.kind=="machine-logistics" and rec.item=="iron-ore",
  "completed machine output was hidden behind unladen manual acquisition")
local selected=Arbiter.action(pair)
check(selected.kind=="machine-logistics",
  "active acquisition order starved physical machine output collection")

pair.machine_logistics_0528={
  phase="move-to-machine",action="clear-output",machine=machine,
  item="iron-ore",count=8}
pair.machine_logistics_candidate_0528=nil
check(Arbiter.action(pair).kind=="machine-logistics",
  "machine output route lost arbitration after task became active")
check(Logistics.yield_for_bootstrap(pair,"dispatcher")==false,
  "active machine output route was preemptively aborted without custody")

pair.machine_logistics_0528=nil
pair.machine_logistics_candidate_0528={
  action="clear-output",item="iron-ore",count=8,
  machine=machine,expires_tick=game.tick+250}
pair.direct_acquisition_custody_0513={item="coal",count=3}
check(Logistics.recommend_action(pair)==nil,
  "machine route preempted physical direct-acquisition custody")
check(Arbiter.action(pair).kind=="acquisition",
  "arbiter abandoned an already-carried manual acquisition load")
pair.direct_acquisition_custody_0513=nil

-- An ordinary furnace output is useful but must not displace gathering
-- stone/plates before an emergency miner has even been constructed.
local furnace={valid=true,name="stone-furnace",type="furnace",
  unit_number=66,position={x=3,y=1},surface=surface,force=force}
pair.machine_logistics_candidate_0528={
  action="clear-output",item="iron-plate",count=8,
  machine=furnace,expires_tick=game.tick+250}
check(Logistics.recommend_action(pair)==nil,
  "generic furnace cleanup starved early emergency-miner ingredient gathering")
check(Arbiter.action(pair).kind=="acquisition",
  "non-mining output displaced essential initial resource acquisition")
pair.emergency_craft={strict_recipe_0647=true,output_item="iron-gear-wheel"}
check(Logistics.recommend_action(pair)==nil,
  "due strict recipe was preempted by incidental machine output")
print("[machine-output-handoff-regression] PASS scenarios=5")
