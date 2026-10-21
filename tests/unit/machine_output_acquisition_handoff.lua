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

-- Physically completed emergency Electronics output is an actual bootstrap
-- dependency. It must be collected through the priest's machine-logistics
-- movement/custody path even when generic raw-material acquisition is active.
-- Unlike remote inventories, this is the local machine's real output slot.
local cable_items={["copper-cable"]=4}
local cable_inventory={valid=true,
  get_item_count=function(item)return cable_items[item] or 0 end}
local workshop={valid=true,name="tech-priests-emergency-assembler",
  type="assembling-machine",unit_number=77,position={x=4,y=1},
  surface=surface,force=force}
workshop.get_inventory=function()return cable_inventory end
pair.machine_logistics_candidate_0528={
  action="clear-output",item="copper-cable",count=4,
  source_inventory=cable_inventory,
  machine=workshop,expires_tick=game.tick+250}
local routed=Logistics.recommend_action(pair)
check(routed and routed.kind=="machine-logistics"
    and routed.item=="copper-cable" and routed.target==workshop,
  "genuinely manufactured copper cable was stranded during raw acquisition")
check(Arbiter.action(pair).kind=="machine-logistics",
  "real electronics output was hidden behind an unladen mining order")
check(Logistics.yield_for_bootstrap(pair,"electronics-output")==false
    and pair.machine_logistics_candidate_0528,
  "raw-reserve governor discarded the physical electronics collection route")
pair.direct_acquisition_custody_0513={item="coal",count=2}
check(Logistics.recommend_action(pair)==nil
    and Arbiter.action(pair).kind=="acquisition",
  "electronics output priority stole real coal held by the mining priest")
pair.direct_acquisition_custody_0513=nil
cable_items["copper-cable"]=0
check(Logistics.recommend_action(pair)==nil,
  "stale empty output candidate interrupted physical acquisition")
cable_items["copper-cable"]=4
pair.emergency_craft={strict_recipe_0647=true,output_item="iron-gear-wheel"}
check(Logistics.recommend_action(pair)==nil,
  "finished cable preempted a genuinely active strict recipe")
pair.emergency_craft=nil
pair.machine_logistics_candidate_0528=nil

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
-- Terminal cleanup must release only the machine family's own movement
-- lease. The dispatcher must be able to resume physical prerequisites without
-- waiting for an obsolete priority-740 path to expire.
local prior_controller=rawget(_G,"TECH_PRIESTS_MOVEMENT_CONTROLLER_0418")
local owner="logistics_machine_fulfillment_0528"
local current_owner=owner
local stops=0
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418={
  request_status=function() return {active=true,owner=current_owner} end,
  stop=function(_,reason)
    check(reason=="machine-logistics-terminal-0528","wrong terminal movement reason")
    stops=stops+1
    return true
  end,
}
pair.machine_logistics_0528={phase="move-to-machine",machine=machine,
  action="clear-output",item="iron-ore",count=1}
local terminated=Logistics.abort_pair(pair,"unit-terminal")
check(terminated.acted==1 and stops==1,
  "terminal machine logistics did not release its active movement lease")
check(pair.machine_logistics_0528.phase=="failed",
  "machine logistics did not retain truthful terminal status")
pair.machine_logistics_0528={phase="move-to-machine",machine=machine,
  action="clear-output",item="iron-ore",count=1}
current_owner="direct-acquisition-0513"
local foreign=Logistics.abort_pair(pair,"unit-foreign-owner")
check(foreign.acted==1 and stops==1,
  "machine terminal cleanup stopped another family's movement")
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418=prior_controller

-- Sparse order/task fields must not truncate the read-only target fallback.
pair.machine_logistics_0528=nil
pair.machine_logistics_candidate_0528=nil
pair.emergency_craft=nil
pair.direct_acquisition_custody_0513=nil
pair.target=nil
pair.order_queue_0469.current.target=nil
pair.direct_acquisition_task_0336={kind="direct-mine-0336",
  current={kind="direct-mine-0336",entity=machine}}
selected=Arbiter.action(pair)
check(selected.kind=="acquisition" and selected.target==machine
  and selected.position==machine.position,
  "nil order fields masked physical direct-acquisition target")
pair.order_queue_0469.current.target=furnace
selected=Arbiter.action(pair)
check(selected.target==furnace and selected.position==furnace.position,
  "explicit order target lost priority to direct-acquisition fallback")
pair.order_queue_0469.current.target=nil
pair.direct_acquisition_task_0336=nil
pair.target=machine
selected=Arbiter.action(pair)
check(selected.target==machine and selected.position==machine.position,
  "nil intermediate fields masked final pair target")
-- Physically held machine output must return before an overlapping strict
-- craft, even when the order changes from acquisition to crafting.
pair.order_queue_0469.current.kind="crafting"
pair.order_queue_0469.current.status="active"
pair.order_queue_0469.current.target=nil
pair.direct_acquisition_task_0336=nil
pair.target=nil
pair.mode="idle"
pair.emergency_craft={strict_recipe_0647=true,
  craft_due_tick=game.tick+90,output_item="iron-gear-wheel"}
pair.machine_logistics_0528={phase="return-custody-to-station",
  action="clear-output",machine=machine,item="iron-ore",
  custody={item="iron-ore",count=5}}
pair.machine_logistics_custody_0528=pair.machine_logistics_0528.custody
selected=Arbiter.action(pair)
check(selected.kind=="machine-logistics" and selected.target==station,
  "strict crafting displaced physical machine-output custody")
pair.order_queue_0469.current.kind="acquisition"
check(Arbiter.action(pair).kind=="machine-logistics",
  "acquisition displaced physical machine-output custody")
pair.order_queue_0469.current.kind="crafting"
pair.machine_logistics_0528=nil
pair.machine_logistics_custody_0528=nil
check(Arbiter.action(pair).kind=="crafting",
  "strict crafting did not resume after machine custody returned")
print("[machine-output-handoff-regression] PASS scenarios=13")
