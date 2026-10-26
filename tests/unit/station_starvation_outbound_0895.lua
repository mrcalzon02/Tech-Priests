-- 0895: exercise the real 0824 inventory debit through the outbound service.
-- This is a Lua fixture, not Factorio engine acceptance.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local item="senior-cogitator-station"
local force={name="player"}
local ghost_present=true
local surface={index=1}
local ghost={valid=true,name="entity-ghost",ghost_name=item,
  unit_number=777,position={x=20,y=0},force=force,surface=surface}
surface.find_entities_filtered=function()
  return ghost_present and {ghost} or {}
end
local station={valid=true,unit_number=100,position={x=0,y=0},
  force=force,surface=surface}
local priest={valid=true,unit_number=101,position={x=10,y=0}}
local magos={station=station,priest=priest,radius=40,
  resource_expansion_0259={chain_0820={target={x=200,y=0}}}}
local original_priest={valid=true,unit_number=201}
local original_pair={priest=original_priest,station={valid=false},
  relocation_pending_0823=true,station_unit=200}
local stage={id="reversal-ancestor:9:4:200",
  phase="in-magos-depot",station_item=item,reversal_stage_index=4,
  leaf_station_unit=200,leaf_priest_unit=201,
  worker_station_unit=100,worker_priest_unit=101}
local prior={}
local function inventory(name,n)
  local inv={valid=true,stock=n}
  inv.get_item_count=function(which)
    assert(which==name)
    return inv.stock
  end
  inv.remove=function(stack)
    assert(stack.name==name)
    local taken=math.min(inv.stock,stack.count)
    inv.stock=inv.stock-taken
    return taken
  end
  inv.insert=function(stack)
    assert(stack.name==name)
    local added=math.min(1-inv.stock,stack.count)
    inv.stock=inv.stock+added
    return added
  end
  return inv
end
prior[1]=inventory("junior-cogitator-station",1)
prior[2]=inventory("junior-cogitator-station",1)
prior[3]=inventory("intermediate-cogitator-station",1)
local source=inventory(item,1)
local depot={status="stored",record_id=stage.id,item=item,
  magos_station_unit=100,magos_priest_unit=101,
  leaf_station_unit=200,leaf_priest_unit=201,
  force=force,surface=surface,inventory=source}
storage={tech_priests={
  pairs_by_station={[100]=magos},
  pairs_by_priest={[201]=original_pair},
  station_reversal_depot_0852={[stage.id]=depot}
}}
local rec={id=9,status="active",station_item=item,station_entity=item,
  worker_station_unit=100,ghost_unit=777,ghost_position={x=20,y=0},
  reversal_stage_0855=stage,
  reversal_plan_0850={target={x=200,y=0}},
  reversal_stage_0851={id="first",station_item="junior-cogitator-station"},
  reversal_stage_0853={id="second",station_item="junior-cogitator-station"},
  reversal_stage_0854={id="third",station_item="intermediate-cogitator-station"}}
local audit_calls=0
package.loaded["scripts.core.station_starvation_rebuild_0867"]={
  audit=function()
    audit_calls=audit_calls+1
    return {stage_count=4},"four-real-depots-and-original-priests-verified"
  end}
package.loaded["scripts.core.station_starvation_depot_0852"]={
  get_staged=function(_,step)
    if step==rec.reversal_stage_0851 then return {inventory=prior[1]} end
    if step==rec.reversal_stage_0853 then return {inventory=prior[2]} end
    if step==rec.reversal_stage_0854 then return {inventory=prior[3]} end
  end}
local lease={status="staged",rec_id=stage.id,old_unit=200,
  priest_unit=201,worker_unit=100,reversal_ancestor_0855=true,
  old_station={valid=false},priest=original_priest}
package.loaded["scripts.core.station_relocation_0823"]={
  pending_for_record=function(step)
    return step==stage and lease or nil
  end}
local bags={}
game={tick=500,create_inventory=function(size)
  assert(size==1)
  local bag=inventory(item,0)
  bag.destroy=function()
    assert(bag.stock==0)
    bag.valid=false
  end
  bag.is_empty=function()return bag.stock==0 end
  bags[#bags+1]=bag
  return bag
end}
defines={command={go_to_location=1},distraction={none=0}}
local Cargo=require("scripts.core.station_cargo_0824")
local Outbound=require("scripts.core.station_starvation_outbound_0895")
local orders=0
local command=function(_,order)
  assert(order.type==1 and order.destination==station.position)
  orders=orders+1
end
-- 0896: the engine observed the original ghost missing after four real
-- depots. No ghost may be restored before the strict custody preflight.
ghost_present=false
local _,why=Outbound.service_first_pickup(magos,rec,command,nil)
assert(why=="outbound-original-resource-ghost-unavailable"
  and rec.ghost_unit==777 and not rec.reversal_outbound_0895
  and source.stock==1 and #bags==0,
  "missing ghost without authority must leave the real item untouched")
local restore_calls=0
local function denied_restore()
  restore_calls=restore_calls+1
  return nil
end
_,why=Outbound.service_first_pickup(magos,rec,command,nil,denied_restore)
assert(why=="outbound-original-resource-ghost-unavailable"
  and restore_calls==1 and not rec.reversal_outbound_0895
  and source.stock==1 and #bags==0,
  "failed physical ghost restoration must preserve original custody")
magos.resource_expansion_0259.chain_0820.target={x=201,y=0}
_,why=Outbound.service_first_pickup(magos,rec,command,nil,denied_restore)
assert(why=="outbound-natural-resource-target-changed"
  and restore_calls==1 and rec.ghost_unit==777,
  "retargeted resource must not permit a replacement ghost")
magos.resource_expansion_0259.chain_0820.target={x=200,y=0}
prior[2].stock=0
_,why=Outbound.service_first_pickup(magos,rec,command,nil,denied_restore)
assert(why=="outbound-prior-depot-custody-lost:2"
  and restore_calls==1 and rec.ghost_unit==777,
  "missing protected station item must forbid ghost restoration")
prior[2].stock=1
-- 0897: a callback cannot move the writ to a site that fails the
-- original command-radius/ore-progress check. Neither identity nor stock
-- may be altered by the rejected physical placement.
local wrong_site={valid=true,name="entity-ghost",ghost_name=item,
  unit_number=779,position={x=-5,y=0},force=force,surface=surface}
_,why=Outbound.service_first_pickup(magos,rec,command,nil,function()
  return wrong_site
end)
assert(why=="outbound-restored-ghost-identity-invalid"
  and rec.ghost_unit==777 and rec.ghost_position.x==20
  and not rec.reversal_outbound_0895 and source.stock==1 and #bags==0,
  "unreachable or backward replacement ghost must not move the writ")
local replacement={valid=true,name="entity-ghost",ghost_name=item,
  unit_number=778,position={x=24,y=0},force=force,surface=surface}
_,why=Outbound.service_first_pickup(magos,rec,command,nil,function(pair,writ)
  restore_calls=restore_calls+1
  assert(pair==magos and writ==rec and rec.ghost_unit==777
    and source.stock==1 and #bags==0)
  ghost=replacement
  ghost_present=true
  return replacement
end)
assert(why=="outbound-magos-walking-to-physical-depot"
  and restore_calls==2 and orders==1 and source.stock==1
  and rec.ghost_unit==778 and rec.ghost_position.x==24
  and rec.reversal_outbound_0895
  and rec.reversal_outbound_0895.ghost_unit==778
  and rec.reversal_outbound_0895.ghost_position.x==24
  and rec.reversal_outbound_0895.restored_ghost_0896
  and rec.reversal_outbound_0895.replanned_ghost_0897
  and #bags==0,
  "verified ghost replacement must retain exact writ and real cargo")
priest.position={x=0,y=0}
_,why=Outbound.service_first_pickup(magos,rec,command,ghost_present and ghost or nil)
assert(why=="reversal-senior-real-item-carried-outward"
  and source.stock==0 and #bags==1 and bags[1].stock==1
  and depot.status=="outbound" and rec.reversal_outbound_0895
  and rec.reversal_outbound_0895.phase=="senior-carried"
  and audit_calls==6,
  "counted Senior item was not transferred to the original Magos carrier")
for i=1,3 do assert(prior[i].stock==1) end
assert(lease.status=="staged" and original_priest.valid
  and storage.tech_priests.pairs_by_station[200]==nil and ghost.valid,
  "outbound pickup stole another station item, priest or ghost")
_,why=Outbound.service_first_pickup(magos,rec,command,ghost_present and ghost or nil)
assert(why=="reversal-senior-real-item-carried-outward"
  and #bags==1 and source.stock==0 and bags[1].stock==1,
  "repeated service duplicated or consumed the one item")
package.loaded["scripts.core.station_starvation_outbound_0895"]=nil
Outbound=require("scripts.core.station_starvation_outbound_0895")
_,why=Outbound.service_first_pickup(magos,rec,command,ghost_present and ghost or nil)
assert(why=="reversal-senior-real-item-carried-outward"
  and #bags==1 and audit_calls==6,
  "module reload lost the persisted original item and custody")
magos.resource_expansion_0259.chain_0820.target={x=201,y=0}
_,why=Outbound.service_first_pickup(magos,rec,command,ghost_present and ghost or nil)
assert(why=="outbound-natural-resource-target-changed"
  and bags[1].stock==1 and source.stock==0,
  "retargeted mission must quarantine carried original item")
magos.resource_expansion_0259.chain_0820.target={x=200,y=0}
ghost_present=false
_,why=Outbound.service_first_pickup(magos,rec,command,ghost_present and ghost or nil)
assert(why=="outbound-original-resource-ghost-unavailable"
  and bags[1].stock==1 and source.stock==0,
  "missing original ghost must not trigger a replacement item")
ghost_present=true
prior[2].stock=0
_,why=Outbound.service_first_pickup(magos,rec,command,ghost_present and ghost or nil)
assert(why=="outbound-prior-depot-custody-lost:2"
  and bags[1].stock==1 and source.stock==0,
  "loss of another protected depot must fail closed")
prior[2].stock=1
magos.priest={valid=true,unit_number=999,position={x=0,y=0}}
_,why=Outbound.service_first_pickup(magos,rec,command,ghost_present and ghost or nil)
assert(why=="outbound-writ-or-original-identity-changed"
  and bags[1].stock==1 and source.stock==0,
  "replacement Magos must not inherit the original priest cargo remotely")
print("[station-starvation-outbound-0895] PASS 0897 blocked-site replan, original-priest custody, physical 0824 pickup, reload and refusals")
