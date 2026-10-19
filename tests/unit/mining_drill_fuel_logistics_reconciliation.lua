-- Lua 5.2 regression: genuine burner drill fuel supply through 0528.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
defines={inventory={fuel=1,chest=2,assembling_machine_input=3,
  assembling_machine_output=4,furnace_source=5,furnace_result=6}}
prototypes={item={coal={}}}
storage={tech_priests={pairs_by_station={}}}
local bound
_G.TechPriestsRuntimeTickBroker0600={
  register_service=function(s)
    if s.name=="machine_logistics_discovery_0528" then bound=s.fn end
    return true
  end
}
local inventory={valid=true,items={}}
inventory.get_item_count=function(n)return inventory.items[n] or 0 end
inventory.get_contents=function()return inventory.items end
inventory.insert=function(stack)
  inventory.items[stack.name]=(inventory.items[stack.name] or 0)+stack.count
  return stack.count
end
local force={index=1,name="player"}
local surface={index=1,name="nauvis",valid=true}
local drill={valid=true,type="mining-drill",name="burner-mining-drill",unit_number=100,
  position={x=6,y=0},surface=surface,force=force}
drill.get_inventory=function(id)if id==defines.inventory.fuel then return inventory end end
surface.find_entities_filtered=function(opts)
  if type(opts.type)=="table" then
    for _,kind in ipairs(opts.type)do if kind=="mining-drill" then return {drill} end end
  end
  return {}
end
local station={valid=true,unit_number=1,name="test-station",surface=surface,
  force=force,position={x=0,y=0}}
local priest={valid=true,unit_number=2,name="priest",surface=surface,force=force,
  position={x=0,y=0}}
local pair={station=station,priest=priest,station_unit=1,radius=18}
storage.tech_priests.pairs_by_station[1]=pair
_G.TechPriestsStorageRoleAuthority0686={
  generic_item_count=function(_,item)return item=="coal" and 7 or 0 end
}
local M=require("scripts.core.logistics_machine_fulfillment_0528")
local function check(ok,why)
  if not ok then error("drill-fuel-regression: "..why,2)end
end
check(M.install(),"discovery service was not installed")
check(type(bound)=="function","broker was not registered")
local ok=bound(nil,2)
check(ok~=nil,"machine fuel discovery did not run")
local candidate=pair.machine_logistics_candidate_0528
check(candidate and candidate.machine==drill,"burner drill omitted from machine candidate")
check(candidate.action=="supply-fuel" and candidate.item=="coal",
  "candidate was not physical coal fuel")
check(candidate.count>0 and candidate.count<=M.max_transfer,
  "fuel planning ignored station stock or bounded transfer")
inventory.insert({name="coal",count=3})
game.tick=game.tick+M.no_task_cooldown+100
pair.machine_logistics_candidate_0528=nil
bound(nil,2)
check(pair.machine_logistics_candidate_0528==nil,
  "already-fueled drill continued requesting fuel")
local stopped=0
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418={
  request_status=function(p)
    local req=p.movement_request_0418
    return req and {active=true,owner=req.owner} or {active=false}
  end,
  stop=function(p)
    stopped=stopped+1;p.movement_request_0418=nil;return true
  end,
}
pair.local_infrastructure_gate_0640={state="assigned-local-step",item="iron-gear-wheel"}
pair.emergency_craft={strict_recipe_0647=true,output_item="iron-gear-wheel"}
pair.machine_logistics_candidate_0528={machine=drill,action="supply-fuel",item="coal"}
pair.machine_logistics_0528={phase="move-to-station",machine=drill,action="supply-fuel"}
pair.movement_request_0418={owner="logistics_machine_fulfillment_0528"}
pair.mode="machine-logistics"
local yielded,why=M.yield_for_bootstrap(pair,"test-prerequisite")
check(yielded and why=="bootstrap-owned","bootstrap did not release unladen machine logistics")
check(stopped==1 and pair.movement_request_0418==nil,
  "obsolete logistics movement was not released")
check(pair.machine_logistics_candidate_0528==nil
  and pair.machine_logistics_0528.phase=="failed",
  "unladen machine reservation/candidate survived bootstrap preemption")
check(pair.mode=="emergency-production-station-craft",
  "logistics left strict craft stranded in wrong mode")
check(M.recommend_action(pair)==nil,"bootstrap gate allowed machine to monopolize dispatcher")

pair.machine_logistics_0528={phase="move-to-machine",machine=drill,
  custody={item="coal",count=2}}
pair.machine_logistics_custody_0528=pair.machine_logistics_0528.custody
pair.movement_request_0418={owner="logistics_machine_fulfillment_0528"}
local owned,blocked=M.yield_for_bootstrap(pair,"cargo-holding")
check(not owned and blocked=="machine-custody-owned",
  "machine custody was silently dropped")
check(pair.machine_logistics_custody_0528.count==2 and stopped==1,
  "physical coal custody or lease was changed by bootstrap")
pair.machine_logistics_custody_0528=nil
pair.machine_logistics_0528={phase="move-to-station",machine=drill}
pair.order_queue_0469={current={kind="machine-logistics",status="active",
  key="explicit-fuel-order"}}
local explicit,explain=M.yield_for_bootstrap(pair,"explicit-order")
check(not explicit and explain=="explicit-machine-order",
  "explicit user/queue order was stolen by bootstrap")
check(pair.machine_logistics_0528.phase=="move-to-station",
  "explicit machine order was aborted")

pair.order_queue_0469=nil
pair.machine_logistics_0528={phase="failed"}
pair.emergency_craft=nil
pair.local_infrastructure_gate_0640={state="waiting-recipe-material",item="stone-furnace"}
pair.machine_logistics_candidate_0528={
  machine=drill,action="supply-fuel",item="coal",expires_tick=game.tick+100}
check(M.recommend_action(pair) and
  M.recommend_action(pair).kind=="machine-logistics",
  "persistent infrastructure gate starved an existing burner drill")
local optional,why=M.yield_for_bootstrap(pair,"generic-gate")
check(not optional and why=="no-active-physical-prerequisite",
  "generic infrastructure gate incorrectly preempted physical fuel transport")
pair.direct_acquisition_task_0336={current={kind="direct-mine-0336"}}
pair.machine_logistics_0528={phase="move-to-station",machine=drill}
pair.machine_logistics_candidate_0528={machine=drill,action="supply-fuel",item="coal"}
pair.movement_request_0418={owner="logistics_machine_fulfillment_0528"}
pair.mode="machine-logistics"
check(M.recommend_action(pair)==nil,
  "physical acquisition was displaced by unrelated furnace or drill fueling")
local ceded,direct_why=M.yield_for_bootstrap(pair,"acquisition-prerequisite")
check(ceded and direct_why=="bootstrap-owned"
  and pair.mode=="direct-acquisition"
  and pair.machine_logistics_0528.phase=="failed",
  "unladen machine transport did not hand back execution to direct acquisition")
pair.direct_acquisition_task_0336=nil
pair.emergency_craft={current={kind="direct-mine-0336",output_item="stone"}}
pair.machine_logistics_0528={phase="move-to-station",machine=drill}
pair.machine_logistics_candidate_0528={machine=drill,action="supply-fuel",item="coal",
  expires_tick=game.tick+100}
pair.movement_request_0418={owner="logistics_machine_fulfillment_0528"}
pair.mode="machine-logistics"
check(M.recommend_action(pair)==nil,
  "mining owned through emergency_craft.current was not recognized")
local legacy_yield,legacy_why=M.yield_for_bootstrap(pair,"embedded-direct")
check(legacy_yield and legacy_why=="bootstrap-owned"
  and pair.mode=="direct-acquisition",
  "embedded physical mining task failed to recover canonical dispatch")
print("[drill-fuel-regression] PASS scenarios=8")
