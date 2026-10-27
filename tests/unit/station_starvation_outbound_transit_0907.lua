-- 0907 physical outbound walk: source fixture, NOT engine acceptance.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local ITEM="senior-cogitator-station"
local force,surface={index=1},{index=2}
local station={valid=true,unit_number=100,position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,unit_number=101,position={x=0,y=0}}
local magos={station=station,priest=priest,radius=40,
  resource_expansion_0259={chain_0820={target={x=200,y=0}}}}
local original={valid=true,unit_number=201}
local stage={id="reversal-ancestor:9:4:200",phase="in-magos-depot",
  station_item=ITEM,reversal_stage_index=4,leaf_station_unit=200,
  leaf_priest_unit=201,worker_station_unit=100,worker_priest_unit=101}
local function inv(item,n)
  return {valid=true,get_item_count=function(_,which)
    assert(which==item);return n
  end}
end
local source,held=inv(ITEM,0),inv(ITEM,1)
local prior={inv("junior-cogitator-station",1),
  inv("junior-cogitator-station",1),inv("intermediate-cogitator-station",1)}
local entry={status="outbound",record_id=stage.id,item=ITEM,
  magos_station_unit=100,magos_priest_unit=101,leaf_station_unit=200,
  leaf_priest_unit=201,force=force,surface=surface,inventory=source}
local rec={id=9,status="active",station_item=ITEM,station_entity=ITEM,
  worker_station_unit=100,ghost_unit=778,ghost_position={x=24,y=0},
  reversal_stage_0855=stage,reversal_plan_0850={target={x=200,y=0}},
  reversal_stage_0851={station_item="junior-cogitator-station"},
  reversal_stage_0853={station_item="junior-cogitator-station"},
  reversal_stage_0854={station_item="intermediate-cogitator-station"},
  reversal_outbound_0895={phase="senior-carried",writ_id=9,stage_id=stage.id,
    magos_unit=100,magos_priest_unit=101,original_senior_unit=200,
    original_senior_priest=201,ghost_unit=778,ghost_position={x=24,y=0},
    target={x=200,y=0},audited_tick_0906=0,picked_tick=120}}
local state=rec.reversal_outbound_0895
storage={tech_priests={pairs_by_station={[100]=magos},
  pairs_by_priest={[201]={priest=original}},
  station_reversal_depot_0852={[stage.id]=entry}}}
local ghost={valid=true,name="entity-ghost",ghost_name=ITEM,
  unit_number=778,position={x=24,y=0},force=force,surface=surface}
local lease={status="staged",rec_id=stage.id,old_unit=200,
  priest_unit=201,worker_unit=100,reversal_ancestor_0855=true,
  old_station={valid=false},priest=original}
local cargo={status="carrying",inventory=held}
local observations=0
package.loaded["scripts.core.station_starvation_rebuild_0867"]={audit=function()
  return {stage_count=4} end}
package.loaded["scripts.core.station_starvation_depot_0852"]={
  get_staged=function(_,step)
    local k=step==rec.reversal_stage_0851 and 1
      or step==rec.reversal_stage_0853 and 2
      or step==rec.reversal_stage_0854 and 3
    return k and {inventory=prior[k]} or nil end}
package.loaded["scripts.core.station_relocation_0823"]={
  pending_for_record=function(step)return step==stage and lease or nil end}
package.loaded["scripts.core.station_cargo_0824"]={
  get=function()return cargo end,
  observe_carrier=function()
    observations=observations+1;return true,"carrier-position-observed" end}
game={tick=130}
defines={command={go_to_location=1},distraction={none=0}}
local Outbound=require("scripts.core.station_starvation_outbound_0895")
local commands=0
local function command(unit,order)
  assert(unit==priest and order.type==1 and order.destination==ghost.position
    and order.radius==2);commands=commands+1 end
local function service()
  return select(2,Outbound.service_outward_transit(magos,rec,command,ghost)) end
assert(service()=="reversal-senior-carrier-walking-to-ghost"
  and commands==1 and state.transit_started_tick==130)
game.tick=150
assert(service()=="reversal-senior-carrier-walking-to-ghost" and commands==1)
package.loaded["scripts.core.station_starvation_outbound_0895"]=nil
Outbound=require("scripts.core.station_starvation_outbound_0895")
game.tick=190
assert(service()=="reversal-senior-carrier-walking-to-ghost"
  and commands==2 and state.transit_started_tick==130)
priest.position={x=23,y=0};game.tick=191
assert(service()=="reversal-senior-real-item-arrived-at-ghost"
  and state.arrived_tick==191 and state.transit_status=="arrived"
  and commands==2 and observations==4)
assert(source:get_item_count(ITEM)==0 and held:get_item_count(ITEM)==1
  and lease.status=="staged" and original.valid
  and storage.tech_priests.pairs_by_station[200]==nil)
priest.position={x=0,y=0};game.tick=192
assert(service()=="reversal-senior-carrier-walking-to-ghost"
  and state.arrived_tick==nil and commands==3)
local function denied(reason,change,restore)
  change();game.tick=game.tick+1
  assert(service()==reason and commands==3 and held:get_item_count(ITEM)==1
    and source:get_item_count(ITEM)==0,reason)
  restore() end
denied("outbound-original-resource-ghost-unavailable",
  function()ghost.force={index=99} end,function()ghost.force=force end)
denied("outbound-natural-resource-target-changed",
  function()magos.resource_expansion_0259.chain_0820.target={x=201,y=0} end,
  function()magos.resource_expansion_0259.chain_0820.target={x=200,y=0} end)
denied("outbound-real-carrier-or-depot-unverified:nil",
  function()entry.status="stored" end,function()entry.status="outbound" end)
denied("outbound-four-depot-escrow-receipt-invalid",
  function()state.audited_tick_0906=100 end,
  function()state.audited_tick_0906=0 end)
denied("outbound-prior-depot-custody-lost:2",
  function()prior[2]=inv("junior-cogitator-station",0) end,
  function()prior[2]=inv("junior-cogitator-station",1) end)
local cargo_module=package.loaded["scripts.core.station_cargo_0824"]
local observe=cargo_module.observe_carrier
cargo_module.observe_carrier=function()return false,"injected-position-readback-refusal" end
game.tick=198
assert(service()=="outbound-carrier-position-unverified:injected-position-readback-refusal"
  and commands==3)
cargo_module.observe_carrier=observe
state.transit_started_tick=1;game.tick=7203
assert(service()=="outbound-physical-transit-timeout"
  and state.transit_status=="timed-out" and commands==3)
print("[station-starvation-outbound-transit-0907] PASS real carrier walk, reload, original priest, ghost, depot and timeout refusals")
