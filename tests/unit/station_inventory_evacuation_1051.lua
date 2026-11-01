-- 1051: physical distant inventory evacuation regression (no remote deposits).
-- Executed from the existing station-relocation source-validation step.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local function inventory(items,capacity)
  local inv={valid=true}
  local slots={}
  for i=1,capacity do
    local item=items[i]
    local s={valid=true,valid_for_read=item~=nil,
      name=item and item.name or nil,count=item and item.count or 0,
      quality=item and item.quality or nil}
    s.transfer_stack=function(from,amount)
      assert(not s.valid_for_read and from.valid_for_read)
      assert(amount>0 and from.count>=amount)
      s.name,s.count,s.quality=from.name,amount,from.quality
      s.valid_for_read=true
      from.count=from.count-amount
      if from.count==0 then
        from.valid_for_read=false
        from.name,from.quality=nil,nil
      end
      return true
    end
    slots[i]=s
  end
  setmetatable(inv,{__len=function()return capacity end,
    __index=function(_,key)return slots[key] end})
  inv.get_contents=function()
    local out={}
    for _,s in ipairs(slots) do
      if s.valid_for_read then
        out[#out+1]={name=s.name,count=s.count,quality=s.quality}
      end
    end
    return out
  end
  inv.destroy=function() inv.valid=false end
  return inv
end
local force={name="player"}
local surface={index=1,find_logistic_network_by_position=function()return nil end}
local function pair(id,rank,name,pos,inv)
  local station={valid=true,unit_number=id,name=name,
    force=force,surface=surface,position={x=pos,y=0},minable=true,
    prototype={mineable_properties={products={{name=name,type="item",amount=1}}}}}
  local priest={valid=true,unit_number=id+100,
    force=force,surface=surface,position={x=20,y=0},
    get_main_inventory=function()return inventory({},1)end}
  return {station=station,priest=priest,rank=rank,mode="idle",
    inventory=inv,command_hierarchy_0480={
      superior_unit=id==11 and 10 or nil,
      direct_subordinate_units={},peer_units={}}}
end
defines={inventory={chest=1},
  command={go_to_location=1},distraction={none=0}}
game={tick=1051,create_inventory=function(n)return inventory({},n)end}
local parent_inv=inventory({},2)
local child_inv=inventory({
  {name="iron-ore",count=13,quality="normal"},
  {name="copper-plate",count=7,quality="uncommon"}},3)
local parent=pair(10,2,"intermediate-cogitator-station",0,parent_inv)
local child=pair(11,1,"junior-cogitator-station",20,child_inv)
local rec={id=1051,status="active",worker_station_unit=10,
  station_item="junior-cogitator-station",
  recycling_candidate_unit_0822=11,ghost_unit=300,
  ghost_position={x=30,y=0}}
storage={tech_priests={pairs_by_station={[10]=parent,[11]=child},
  pairs_by_priest={[110]=parent,[111]=child},
  station_by_priest={[110]=10,[111]=11},
  station_expansion_0256={[1051]=rec},
  station_expansion_by_worker_0256={[10]=1051}}}
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)return p.rank end,
  is_direct_subordinate=function(p,c)
    return c.command_hierarchy_0480.superior_unit==p.station.unit_number
  end,peers=function()return {}end,rebuild=function()return true end}
_G.tech_priests_0358_station_sources_for_pair=function(p)
  return {{owner=p.station,inv=p.inventory}}
end
package.loaded["scripts.core.station_recycling_0822"]=nil
package.loaded["scripts.core.station_inventory_evacuation_1048"]=nil
local Recovery=require("scripts.core.station_recycling_0822")
local Evac=require("scripts.core.station_inventory_evacuation_1048")
local ok,why=Recovery.check_candidate(parent,child,rec.station_item)
assert(not ok and why=="station-inventory-not-empty")
assert(Recovery.check_evacuable_candidate(parent,child,rec.station_item,rec.id))
local chosen=Recovery.find_candidate(parent,rec.station_item,{x=40,y=0})
assert(not chosen,"ordinary candidate search must not select occupied stock")
chosen=Recovery.find_candidate(parent,rec.station_item,{x=40,y=0},true)
assert(chosen==child,"occupied candidate requires safe evacuation preflight")
local commands={}
local function command(_,spec)
  commands[#commands+1]=spec
  return true
end
-- 1055: An expansion reservation must not preempt a live incumbent
-- task or engine-owned custody. Denial must not allocate a carrier or
-- remove real stock; once cleared, the exact original writ may resume.
local conflict_keys={"active_task","current_task","active_task_0285",
  "construction_custody_0338","active_craft_0479",
  "emergency_production_custody_0514"}
for _,key in ipairs(conflict_keys) do
  parent[key]={owner="other-physical-executor"}
  local denied,reason=Evac.service_remote(parent,child,rec,command)
  assert(not denied and reason=="evacuation-worker-busy-or-carried-custody"
    and not Evac.remote_record(child)
    and child_inv[1].count==13 and child_inv[2].count==7
    and not parent_inv[1].valid_for_read and #commands==0,
    "conflicting worker duty must refuse before engine cargo allocation: "..key)
  parent[key]=nil
end
-- Pickup must happen at the CHILD; no parent inventory may change remotely.
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-counted-source-pickup")
local entry=Evac.remote_record(child)
assert(entry and entry.bag.valid and entry.bag[1].count==13
  and not child_inv[1].valid_for_read
  and not parent_inv[1].valid_for_read)
assert(not Recovery.check_candidate(parent,child,rec.station_item,nil,false,rec.id),
  "an in-flight inventory must reserve the physical station against mining")
parent.current_task={owner="competing-physical-executor"}
local blocked,blocked_reason=Evac.service_remote(parent,child,rec,command)
assert(not blocked and blocked_reason=="evacuation-worker-busy-or-carried-custody"
  and Evac.remote_record(child)==entry and entry.bag[1].count==13
  and child_inv[1].count==0 and not parent_inv[1].valid_for_read
  and #commands==0,
  "incumbent task during carry must retain original engine inventory and writ")
parent.current_task=nil
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-carrying-to-parent"
  and #commands==1 and commands[1].destination.x==0
  and parent.priest.position.x==20 and not parent_inv[1].valid_for_read)
-- 1052: a second stocked station must not seize a worker carrying the first.
local sibling_inv=inventory({{name="iron-ore",count=3,quality="normal"}},1)
local sibling=pair(12,1,"junior-cogitator-station",24,sibling_inv)
-- The second leaf is another real direct Junior subordinate, not an
-- unrelated station: its hierarchy edge must be explicit in this fixture.
sibling.command_hierarchy_0480.superior_unit=10
local other={id=1052,status="active",worker_station_unit=10,
  station_item="junior-cogitator-station",
  recycling_candidate_unit_0822=12,ghost_unit=301,
  ghost_position={x=34,y=0}}
local tp=storage.tech_priests
tp.pairs_by_station[12]=sibling
tp.pairs_by_priest[112]=sibling
tp.station_by_priest[112]=12
tp.station_expansion_0256[1052]=other
local holds_created=0
local original_create_inventory=game.create_inventory
game.create_inventory=function(n)
  holds_created=holds_created+1
  return original_create_inventory(n)
end
local before_holds=holds_created
ok,why=Evac.service_remote(parent,sibling,other,command)
assert(not ok and why=="evacuation-worker-writ-not-reserved"
  and holds_created==before_holds and sibling_inv[1].count==3)
tp.station_expansion_by_worker_0256[10]=1052
ok,why=Evac.service_remote(parent,sibling,other,command)
assert(not ok and why=="evacuation-worker-other-custody-active"
  and holds_created==before_holds and sibling_inv[1].count==3)
tp.station_expansion_by_worker_0256[10]=1051
-- An incorrect writ/worker cannot take the existing engine-owned hold.
rec.worker_station_unit=999
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-physical-owner-invalid"
  and entry.bag[1].count==13)
rec.worker_station_unit=10
-- A save/reload must retain the SAME LuaInventory and custody receipt.
package.loaded["scripts.core.station_inventory_evacuation_1048"]=nil
Evac=require("scripts.core.station_inventory_evacuation_1048")
assert(Evac.remote_record(child)==entry)
parent.priest.position={x=0,y=0}
game.tick=1052
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-counted-parent-deposit"
  and parent_inv[1].name=="iron-ore" and parent_inv[1].count==13
  and entry.bag[1].count==0)
-- Second real stack cannot be collected until walking BACK to the source.
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-returning-to-child"
  and child_inv[2].count==7 and entry.bag[1].count==0)
parent.priest.position={x=20,y=0}
game.tick=1053
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-counted-source-pickup"
  and not child_inv[2].valid_for_read
  and entry.bag[1].count==7 and entry.bag[1].quality=="uncommon")
-- Destination congestion must not erase or remotely credit carried stock.
parent_inv[2].valid_for_read=true
parent_inv[2].name="stone"
parent_inv[2].count=1
parent_inv[2].quality="normal"
parent.priest.position={x=0,y=0}
game.tick=1054
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-parent-inventory-full"
  and entry.bag[1].count==7 and parent_inv[1].count==13)
parent_inv[2].valid_for_read=false
parent_inv[2].name,parent_inv[2].quality=nil,nil
parent_inv[2].count=0
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-counted-parent-deposit"
  and parent_inv[2].name=="copper-plate"
  and parent_inv[2].quality=="uncommon"
  and parent_inv[2].count==7)
assert(not Evac.complete_remote(rec,11),
  "a remote evacuation cannot complete until the worker returns to the child")
parent.priest.position={x=20,y=0}
game.tick=1055
ok,why=Evac.service_remote(parent,child,rec,command)
assert(ok and why=="evacuation-complete"
  and entry.status=="ready-to-mine")
assert(Recovery.check_candidate(parent,child,rec.station_item,nil,false,rec.id))
assert(not Recovery.check_candidate(parent,child,rec.station_item),
  "unrelated mining must not consume the reserved station")
assert(Evac.complete_remote(rec,11) and not entry.bag.valid
  and not Evac.remote_record(child))
assert(rec.inventory_evacuation_1048.physical_carrier
  and rec.inventory_evacuation_1048.item_counts["iron-ore"]==13
  and rec.inventory_evacuation_1048.item_counts["copper-plate"]==7
  and rec.inventory_evacuation_1048.stack_transfers==2)
assert(parent_inv[1].count==13 and parent_inv[2].count==7)
-- Finalizing the first receipt releases the priest for another exact writ.
tp.station_expansion_by_worker_0256[10]=1052
ok,why=Evac.service_remote(parent,sibling,other,command)
assert(not ok and why=="evacuation-counted-source-pickup"
  and not sibling_inv[1].valid_for_read
  and Evac.remote_record(sibling).bag[1].count==3)
-- 1054: The real walking courier must not have its Factorio path reset on
-- every executor tick. Its persisted command lease survives reload, refreshes
-- only after 180 ticks, and NEVER extends the physical travel deadline.
local before_commands=#commands
game.tick=1056
ok,why=Evac.service_remote(parent,sibling,other,command)
assert(not ok and why=="evacuation-carrying-to-parent"
  and #commands==before_commands+1)
local sibling_hold=assert(Evac.remote_record(sibling))
assert(sibling_hold.travel_last_command_tick==1056
  and sibling_hold.travel_started_tick==1056)
game.tick=1057
ok,why=Evac.service_remote(parent,sibling,other,command)
assert(not ok and why=="evacuation-carrying-to-parent"
  and #commands==before_commands+1
  and sibling_hold.bag[1].count==3)
-- Rebinding the module simulates reload of the same engine-owned inventory
-- and persisted movement lease. The next pulse must not reissue a command.
package.loaded["scripts.core.station_inventory_evacuation_1048"]=nil
Evac=require("scripts.core.station_inventory_evacuation_1048")
game.tick=1060
ok,why=Evac.service_remote(parent,sibling,other,command)
assert(not ok and why=="evacuation-carrying-to-parent"
  and #commands==before_commands+1
  and Evac.remote_record(sibling)==sibling_hold)
game.tick=1236
ok,why=Evac.service_remote(parent,sibling,other,command)
assert(not ok and why=="evacuation-carrying-to-parent"
  and #commands==before_commands+2
  and sibling_hold.travel_last_command_tick==1236
  and sibling_hold.travel_started_tick==1056)
game.tick=1056+60*120+1
ok,why=Evac.service_remote(parent,sibling,other,command)
assert(not ok and why=="evacuation-physical-travel-timeout"
  and #commands==before_commands+2
  and sibling_hold.bag[1].count==3
  and sibling_inv[1].count==0
  and parent_inv[1].count==13 and parent_inv[2].count==7,
  "timed-out physical travel must preserve all real cargo and receipts")
-- 1053: Source regression for a real Factorio 2.0.77 crash observed in
-- runtime run 41327636596. The live harness must not require the evacuation
-- module from relocation_engine_service() during on_tick.
local harness_file=assert(io.open("tests/scenarios/all-ground-ranks/ground_rank_harness.lua","r"))
local harness=harness_file:read("*a")
harness_file:close()
assert(harness:find('local EVAC_ENGINE_1048=SAVE_RELOAD_SMOKE and require("scripts.core.station_inventory_evacuation_1048")',1,true),
  "Factorio evacuation authority must be bound at control parsing")
assert(harness:find("local evac=EVAC_ENGINE_1048",1,true),
  "live engine probe must use the prebound authority")
assert(not harness:find('local evac=require("scripts.core.station_inventory_evacuation_1048")',1,true),
  "Factorio cannot require a module from a live tick")
-- 1056: Native positive gate must actually mine physical world fixtures into
-- a real LuaInventory, move those mined stacks into the occupied Junior, and
-- refuse to report successful relocation without two distinct journeys and
-- a counted original-priest recovery receipt. This is fixture-stock proof,
-- not natural-ore acquisition or independent-process mid-carry proof.
assert(harness:find("local function relocation_engine_stock_child(test,child)",1,true),
  "native positive test must prepare occupied physical source stock")
assert(harness:find("chest.mine{inventory=hold,force=false}",1,true)
  and harness:find("inv[i].transfer_stack(hold[1],1)",1,true),
  "fixture stock must come from physical entity mining and native stack transfer")
assert(harness:find("recovery.check_evacuable_candidate(",1,true),
  "native test must preserve the occupied-station hierarchy/custody preflight")
assert(harness:find("relocation_engine_observe_stock(test,parent,pairs[test.old_station_unit],rec)",1,true),
  "native test must observe the live executor's physical transport")
assert(harness:find('emit("PASS RELOCATION_ENGINE_STOCK_EVACUATION tick="',1,true)
  and harness:find("receipt.stack_transfers==2",1,true)
  and harness:find('receipt.item_counts["wooden-chest"]==1',1,true)
  and harness:find('receipt.item_counts["iron-chest"]==1',1,true),
  "native acceptance must require two counted deliveries before station rebind")
-- 1057: independent Factorio processes, not simulated Lua reload, must
-- checkpoint a genuinely carried native stack and read it before delivery.
assert(harness:find('game.auto_save("tech-priests-ci-stock-carried")',1,true)
  and harness:find('RELOCATION_ENGINE_STOCK_CARRY_SAVE_CUSTODY_INVALID',1,true)
  and harness:find('TP_CI_STOCK_RELOAD_PROBE',1,true)
  and harness:find('RELOCATION_ENGINE_STOCK_CARRY_RELOAD_CUSTODY_INVALID',1,true)
  and harness:find('test.stock_reload_verified',1,true),
  "native stock-carry checkpoint must fail closed on identity or item loss")
local runner_file=assert(io.open("tools/run_factorio_save_reload_smoke.py","r"))
local runner=runner_file:read("*a")
runner_file:close()
assert(runner:find('STOCK_CARRY_SAVE_NAME',1,true)
  and runner:find('verify_stock_carry_reload_log(fourth_log, content)',1,true)
  and runner:find('five real Factorio processes, four CRC-verified saves',1,true),
  "native runner must restart a separate Factorio process from stock-carry save")
print("[station-inventory-evacuation-1051] PASS: counted journeys, reload, congestion, exclusive worker custody, command lease/reload/timeout, release, mining gate, engine prebind and native stocked-station proof")
