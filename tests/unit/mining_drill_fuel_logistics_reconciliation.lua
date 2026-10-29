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
pair.emergency_craft=nil
pair.direct_acquisition_task_0336=nil
pair.machine_logistics_0528={phase="failed"}
pair.movement_request_0418=nil
pair.order_queue_0469=nil
pair.local_infrastructure_gate_0640=nil
local chest_items={["iron-ore"]=7}
local chest_inventory={valid=true}
chest_inventory.get_contents=function() return chest_items end
chest_inventory.get_item_count=function(n)return chest_items[n] or 0 end
local receiver={valid=true,name="iron-chest",type="container",unit_number=102,
  position={x=8.5,y=0.5},force=force,surface=surface}
receiver.get_inventory=function(id)
  if id==defines.inventory.chest then return chest_inventory end
end
drill.drop_position={x=8.5,y=0.5}
drill.drop_target=receiver
surface.find_entities_filtered=function()return {drill,receiver}end
game.tick=game.tick+M.no_task_cooldown+100
pair.machine_logistics_candidate_0528=nil
bound(nil,2)
local output=pair.machine_logistics_candidate_0528
check(output and output.machine==receiver
  and output.action=="clear-output" and output.item=="iron-ore"
  and output.count==7,
  "actual connected drill chest was not recognized as physical ore output")
drill.drop_target=nil
receiver.position={x=14,y=9}
game.tick=game.tick+M.no_task_cooldown+100
pair.machine_logistics_candidate_0528=nil
bound(nil,2)
check(pair.machine_logistics_candidate_0528==nil,
  "unrelated unconnected storage chest became a machine output source")
-- A furnace holding real ore and no fuel is an industrial dependency,
-- not a lower-value task than routine drill refueling. The ore and coal
-- inventories are physical; discovery must not fabricate stock.
local hot_fuel={valid=true,items={}}
hot_fuel.get_item_count=function(name)return hot_fuel.items[name] or 0 end
hot_fuel.get_contents=function()return hot_fuel.items end
local hot_ore={valid=true,items={["iron-ore"]=4}}
hot_ore.get_item_count=function(name)return hot_ore.items[name] or 0 end
hot_ore.get_contents=function()return hot_ore.items end
local waiting_furnace={valid=true,type="furnace",name="stone-furnace",
 unit_number=122,position={x=16,y=0},surface=surface,force=force}
waiting_furnace.get_inventory=function(id)
 if id==defines.inventory.fuel then return hot_fuel end
 if id==defines.inventory.furnace_source then return hot_ore end
end
inventory.items.coal=0
surface.find_entities_filtered=function()
 return {drill,waiting_furnace}
end
pair.machine_logistics_0528={phase="failed"}
pair.machine_logistics_candidate_0528=nil
game.tick=game.tick+M.no_task_cooldown+300
bound(nil,2)
local urgent=pair.machine_logistics_candidate_0528
check(urgent and urgent.machine==waiting_furnace and
 urgent.action=="supply-fuel" and urgent.item=="coal",
 "ore-loaded unpowered furnace was starved behind routine drill refueling")
-- When the furnace is no longer awaiting ore conversion, drill fueling
-- remains useful and must not be suppressed by the new dependency priority.
hot_ore.items["iron-ore"]=0
pair.machine_logistics_candidate_0528=nil
game.tick=game.tick+M.no_task_cooldown+300
bound(nil,2)
local fallback=pair.machine_logistics_candidate_0528
check(fallback and fallback.machine==drill and
 fallback.action=="supply-fuel" and fallback.item=="coal",
 "ordinary drill fuel could not resume after furnace dependency ended")
-- Finished electronics components outrank incidental raw output and
-- routine drill fuel. Discovery must select actual machine output, not
-- invent a station item or remove it during read-only candidate ranking.
local cable_stacks={["copper-cable"]=4}
local ore_stacks={["iron-ore"]=12}
local function output_inventory(items)
 return {valid=true,
  get_item_count=function(name)return items[name] or 0 end,
  get_contents=function()return items end}
end
local cable_inventory=output_inventory(cable_stacks)
local ore_output=output_inventory(ore_stacks)
local emergency_workshop={valid=true,type="assembling-machine",
  name="tech-priests-emergency-assembler",unit_number=133,
  position={x=7,y=0},surface=surface,force=force}
emergency_workshop.get_inventory=function(id)
 if id==defines.inventory.assembling_machine_output then return cable_inventory end
end
local emergency_miner={valid=true,type="assembling-machine",
  name="tech-priests-emergency-miner",unit_number=134,
  position={x=5,y=0},surface=surface,force=force}
emergency_miner.get_inventory=function(id)
 if id==defines.inventory.assembling_machine_output then return ore_output end
end
surface.find_entities_filtered=function(opts)
 return {drill,emergency_miner,emergency_workshop,waiting_furnace}
end
pair.machine_logistics_candidate_0528=nil
pair.machine_logistics_0528={phase="failed"}
game.tick=game.tick+M.no_task_cooldown+300
bound(nil,2)
local electronics=pair.machine_logistics_candidate_0528
check(electronics and electronics.machine==emergency_workshop
  and electronics.action=="clear-output"
  and electronics.item=="copper-cable" and electronics.count==4,
  "electronics output lost discovery ranking to ordinary ore/drill fuel")
check(cable_stacks["copper-cable"]==4 and ore_stacks["iron-ore"]==12,
  "read-only electronics candidate discovery consumed real factory output")
check((M.root().stats["electronics-output-observed-0528"] or 0)>0
    and (M.root().stats["electronics-output-selected-0528"] or 0)>0,
  "physical electronics output was not actually recognized in discovery telemetry")
-- 0983: execute the actual 0528 physical receiver debit and canonical
-- station deposit, not merely read-only drill candidate discovery.
_G.TechPriestsWorkReservations0601={
  claim=function(kind,machine,worker)
    return kind=="machine-logistics" and machine==receiver and worker==pair
  end,
  release=function()return true end,
}
local delivered={}
_G.TechPriestsStorageRoleAuthority0686.deposit_exact=function(worker,item,n,reason,opts)
  check(worker==pair and item=="iron-ore" and n>0
    and reason=="machine-output-deposit-0528"
    and opts.role=="retention","drill deposit bypassed canonical storage")
  delivered[item]=(delivered[item] or 0)+n
  return true,"real-station-deposit",n
end
chest_inventory.remove=function(stack)
  local n=math.min(chest_items[stack.name] or 0,stack.count)
  chest_items[stack.name]=(chest_items[stack.name] or 0)-n
  return n
end
chest_inventory.insert=function(stack)
  chest_items[stack.name]=(chest_items[stack.name] or 0)+stack.count
  return stack.count
end
receiver.position={x=8.5,y=0.5}
drill.drop_target=receiver
drill.drop_position={x=8.5,y=0.5}
surface.find_entities_filtered=function()return {drill,receiver}end
chest_items["iron-ore"]=7
pair.priest.position={x=8.5,y=0.5}
pair.machine_logistics_0528={phase="failed"}
pair.machine_logistics_candidate_0528={
  machine=receiver,drill_source_0983=drill,
  action="clear-output",item="iron-ore",
  count=7,kind="retention",source_inventory=chest_inventory,
  expires_tick=game.tick+200,
}
local picked=M.service_pair(pair,"drill-receiver-0983")
local active=pair.machine_logistics_0528
check(picked.acted==1 and active.phase=="return-custody-to-station"
  and chest_items["iron-ore"]==0
  and active.custody and active.custody.count==7
  and active.drill_pickup_0983
  and active.drill_pickup_0983.source_before==7
  and active.drill_pickup_0983.source_after==0
  and active.drill_pickup_0983.drill_unit==drill.unit_number
  and delivered["iron-ore"]==nil,
  "connected drill output did not physically debit into retained custody")
pair.priest.position={x=0,y=0}
game.tick=game.tick+1
local deposited=M.service_pair(pair,"drill-receiver-return-0983")
local receipts=pair.drill_output_receipts_0983
check(deposited.acted==1 and delivered["iron-ore"]==7
  and chest_items["iron-ore"]==0
  and receipts and #receipts==1
  and receipts[1].count==7 and receipts[1].source_before==7
  and receipts[1].source_after==0
  and receipts[1].drill_unit==drill.unit_number
  and receipts[1].receiver_unit==receiver.unit_number
  and receipts[1].deposit_tick>=receipts[1].pickup_tick
  and pair.machine_logistics_custody_0528==nil,
  "canonical real-station deposit lacked exact persisted drill receipt")
package.loaded["scripts.core.logistics_machine_fulfillment_0528"]=nil
M=require("scripts.core.logistics_machine_fulfillment_0528")
check(pair.drill_output_receipts_0983==receipts and #receipts==1,
  "drill-output physical receipt disappeared on module reload")
-- A previously connected receiver may be disconnected before the priest
-- arrives. It must never be debited on the strength of a stale candidate.
drill.drop_target=nil
drill.drop_position={x=20,y=20}
chest_items["iron-ore"]=5
pair.priest.position={x=8.5,y=0.5}
pair.machine_logistics_0528={phase="failed"}
pair.machine_logistics_candidate_0528={
  machine=receiver,drill_source_0983=drill,
  action="clear-output",item="iron-ore",count=5,
  source_inventory=chest_inventory,expires_tick=game.tick+200,
}
local disconnected=M.service_pair(pair,"drill-disconnected-0983")
check(disconnected.acted==1 and chest_items["iron-ore"]==5
  and delivered["iron-ore"]==7 and #receipts==1
  and pair.machine_logistics_0528.phase=="failed",
  "stale disconnected receiver was treated as physical drill output")
-- A post-mutation callback exception must be reconciled from the
-- actual source inventory delta, never retried as a second withdrawal.
local ordinary_remove=chest_inventory.remove
chest_inventory.remove=function(stack)
  ordinary_remove(stack)
  error("simulated-post-mutation-drill-receiver-callback")
end
-- A corrupted in-flight proof cannot release held items into storage.
drill.drop_target=receiver
pair.machine_logistics_0528={phase="failed"}
pair.machine_logistics_candidate_0528={
  machine=receiver,drill_source_0983=drill,
  action="clear-output",item="iron-ore",count=5,
  kind="retention",source_inventory=chest_inventory,
  expires_tick=game.tick+200,
}
local again=M.service_pair(pair,"drill-tamper-pickup-0983")
check(again.acted==1 and chest_items["iron-ore"]==0,
  "second connected receiver pickup did not physically debit")
pair.machine_logistics_0528.drill_pickup_0983.drill_unit=0
pair.priest.position={x=0,y=0}
game.tick=game.tick+1
local denied=M.service_pair(pair,"drill-tamper-deposit-0983")
check(denied.blocked==1
  and pair.machine_logistics_0528.phase=="custody-uncertain-0983"
  and pair.machine_logistics_custody_0528.count==5
  and delivered["iron-ore"]==7 and #receipts==1,
  "corrupt physical receiver proof released or destroyed custody")
local refused=M.abort_pair(pair,"combat-priority")
check(refused.blocked==1 and delivered["iron-ore"]==7
  and pair.machine_logistics_custody_0528.count==5,
  "quarantined drill output was silently refunded or duplicated")
print("[drill-fuel-regression] PASS scenarios=17 with 0983 physical receiver receipts")
