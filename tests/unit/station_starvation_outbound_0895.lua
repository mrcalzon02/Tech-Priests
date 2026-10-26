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
-- 0900: an exact-writ, forward ghost outside CURRENT command range
-- must also be eligible for safe replan, never for out-of-range building.
ghost.position={x=60,y=0}
rec.ghost_position={x=60,y=0}
local range_calls=0
local _,range_why=Outbound.service_first_pickup(magos,rec,command,ghost,
  function(pair,writ,owned)
    range_calls=range_calls+1
    assert(pair==magos and writ==rec and owned==ghost)
    return nil,"no-safe-outward-replan-site"
  end)
assert(range_calls==1
  and range_why=="outbound-original-resource-ghost-unavailable:no-safe-outward-replan-site"
  and rec.ghost_unit==777 and rec.ghost_position.x==60
  and source.stock==1 and #bags==0 and not rec.reversal_outbound_0895,
  "out-of-radius original ghost must replan without touching physical stock")
-- A foreign ghost is never a replan authority, even at the recorded site.
ghost.unit_number=999
local _,foreign_why=Outbound.service_first_pickup(magos,rec,command,ghost,
  function()range_calls=range_calls+1 end)
assert(foreign_why=="outbound-original-resource-ghost-unavailable"
  and range_calls==1 and source.stock==1 and #bags==0,
  "foreign ghost must not trigger restoration or item debit")
ghost.unit_number=777
-- 0899: an existing exact-writ ghost behind the ore must be replanned,
-- never treated as completed forward progress or as a missing item.
ghost.position={x=-20,y=0}
rec.ghost_position={x=-20,y=0}
local backward_calls=0
local _,backward_why=Outbound.service_first_pickup(magos,rec,command,ghost,
  function(pair,writ,owned)
    backward_calls=backward_calls+1
    assert(pair==magos and writ==rec and owned==ghost)
    return nil,"no-safe-outward-replan-site"
  end)
assert(backward_calls==1
  and backward_why=="outbound-original-resource-ghost-unavailable:no-safe-outward-replan-site"
  and rec.ghost_unit==777 and rec.ghost_position.x==-20
  and source.stock==1 and #bags==0 and not rec.reversal_outbound_0895,
  "backward owned ghost must fail closed without consuming real stock")
ghost.position={x=20,y=0}
rec.ghost_position={x=20,y=0}
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
_,why=Outbound.service_first_pickup(magos,rec,command,nil,function()
  error("injected-physical-ghost-restore-failure-0898")
end)
assert(why:find("outbound-ghost-restoration-callback-error:",1,true)==1
  and why:find("injected-physical-ghost-restore-failure-0898",1,true)
  and not rec.reversal_outbound_0895 and rec.ghost_unit==777
  and source.stock==1 and #bags==0,
  "Factorio callback exception must be observable without item debit")
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
wrong_site.destroy=function()wrong_site.valid=false end
_,why=Outbound.service_first_pickup(magos,rec,command,nil,function()
  return wrong_site
end)
assert(why=="outbound-restored-ghost-identity-invalid"
  and rec.ghost_unit==777 and rec.ghost_position.x==20
  and not wrong_site.valid
  and not rec.reversal_outbound_0895 and source.stock==1 and #bags==0,
  "unreachable or backward replacement ghost must be cleaned without moving stock")
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
  and audit_calls==10,
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
  and #bags==1 and audit_calls==10,
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
-- 0898: exercise the production site selector itself, not a callback stub.
-- An obstructed outer perimeter must not block an actually buildable
-- inward site, and no backward or unbuildable site may be selected.
local old_radius=_G.refresh_pair_radius
local old_entity_proto=_G.tech_priests_get_entity_prototype_0440
local old_surface_support=_G.tech_priests_surface_supports_martian_emergency_doctrine_0184
local old_find=surface.find_entities_filtered
local old_can=surface.can_place_entity
_G.refresh_pair_radius=function()return 16 end
_G.tech_priests_get_entity_prototype_0440=function()return {} end
_G.tech_priests_surface_supports_martian_emergency_doctrine_0184=function()return true end
surface.find_entities_filtered=function()return {} end
surface.can_place_entity=function(args)
  local p=args.position
  return p.x>0 and p.x*p.x+p.y*p.y<50
end
local Expansion=dofile("tech-priests_src/scripts/magos_station_expansion.lua")
local site=Expansion.find_outbound_replan_site_0898(magos,item,{x=200,y=0})
assert(site and site.x>0 and site.x*site.x+site.y*site.y<50
  and (site.x-200)^2+site.y^2<200^2,
  "obstructed perimeter must select a real buildable inner forward site")
surface.can_place_entity=function(args)return args.position.x<0 end
assert(Expansion.find_outbound_replan_site_0898(magos,item,{x=200,y=0})==nil,
  "backward-only buildable sites must not be selected")
surface.can_place_entity=function()return false end
assert(Expansion.find_outbound_replan_site_0898(magos,item,{x=200,y=0})==nil,
  "unbuildable sites must fail closed")
-- 0899: functional production callback replaces the exact backward ghost.
local old_create=surface.create_entity
local old={valid=true,name="entity-ghost",ghost_name=item,
  unit_number=777,position={x=-20,y=0},force=force,surface=surface}
local removed=0
old.destroy=function()removed=removed+1;old.valid=false end
rec.ghost_unit=777
rec.ghost_position={x=-20,y=0}
rec.next_outbound_restore_tick_0897=nil
local created={}
local fail_ghost_api_0902=true
surface.can_place_entity=function(args)
  local p=args.position
  return p.x>0 and p.x*p.x+p.y*p.y<50
end
surface.create_entity=function(args)
  assert(args.name=="entity-ghost" and args.inner_name==item
    and args.force==force and args.position.x>0
    and args.expires==nil,
    "Factorio 2.0 ghost creation must not pass unsupported expires")
  if fail_ghost_api_0902 then
    error("injected-physical-ghost-api-error-0902")
  end
  local new={valid=true,name="entity-ghost",ghost_name=item,
    unit_number=900+#created,position=args.position,force=force,surface=surface}
  new.destroy=function()new.valid=false end
  created[#created+1]=new
  return new
end
-- 0902: a real create_entity exception must be surfaced, and a retry
-- must preserve the original owned ghost and all recovered physical stock.
local api_rejected,api_reason=Expansion.restore_outbound_ghost_0896(magos,rec,old)
assert(not api_rejected
  and api_reason:find("physical-ghost-api-error:",1,true)==1
  and api_reason:find("injected-physical-ghost-api-error-0902",1,true)
  and old.valid and removed==0 and #created==0
  and source.stock==0 and bags[1].stock==1,
  "ghost API error must not destroy the original or debit real cargo")
local _,api_backoff=Expansion.restore_outbound_ghost_0896(magos,rec,old)
assert(api_backoff:find("physical-site-retry-backoff:physical-ghost-api-error:",1,true)==1
  and source.stock==0 and bags[1].stock==1,
  "ghost API refusal must survive same-tick retry throttling")
rec.next_outbound_restore_tick_0897=nil
fail_ghost_api_0902=false
local repl=Expansion.restore_outbound_ghost_0896(magos,rec,old)
assert(repl==created[1] and repl.valid and not old.valid
  and removed==1 and repl.position.x>0
  and source.stock==0 and bags[1].stock==1,
  "actual callback must replace only the owned ghost and conserve cargo")
local refusing={valid=true,name="entity-ghost",ghost_name=item,
  unit_number=777,position={x=-20,y=0},force=force,surface=surface}
refusing.destroy=function()return false end
rec.next_outbound_restore_tick_0897=nil
local refused,denial=Expansion.restore_outbound_ghost_0896(magos,rec,refusing)
assert(not refused and denial=="owned-ghost-replan-old-destroy-refused"
  and refusing.valid and created[2] and not created[2].valid
  and source.stock==0 and bags[1].stock==1,
  "refused old ghost destruction must clean the replacement and conserve stock")
-- 0901: the same tick's repeated service must retain the real first refusal.
local throttled,throttle_reason=Expansion.restore_outbound_ghost_0896(
  magos,rec,refusing)
assert(not throttled
  and throttle_reason=="physical-site-retry-backoff:owned-ghost-replan-old-destroy-refused"
  and rec.outbound_restore_last_refusal_0901==
    "owned-ghost-replan-old-destroy-refused"
  and refusing.valid and source.stock==0 and bags[1].stock==1,
  "restore backoff must preserve the exact engine refusal and item custody")
-- 0900: the production callback must also relocate a forward but
-- out-of-radius original ghost. It must destroy only that original and
-- leave the already-carried real item untouched.
local outside_old={valid=true,name="entity-ghost",ghost_name=item,
  unit_number=777,position={x=20,y=0},force=force,surface=surface}
local outside_removed=0
outside_old.destroy=function()outside_removed=outside_removed+1;outside_old.valid=false end
rec.ghost_unit=777
rec.ghost_position={x=20,y=0}
rec.next_outbound_restore_tick_0897=nil
local outside_replacement=Expansion.restore_outbound_ghost_0896(magos,rec,outside_old)
assert(outside_replacement==created[3] and outside_replacement.valid
  and not outside_old.valid and outside_removed==1
  and outside_replacement.position.x>0
  and outside_replacement.position.x^2+outside_replacement.position.y^2<50
  and source.stock==0 and bags[1].stock==1,
  "forward out-of-range original must replan safely without changing real cargo")
-- 0901: a different writ's ghost at the old site must remain intact.
-- The original Magos may instead create a new ghost at an independently
-- buildable forward site, without adopting/destroying the foreign ghost.
local foreign={valid=true,name="entity-ghost",ghost_name=item,
  unit_number=987,position={x=2,y=0},force=force,surface=surface}
local foreign_removed=0
foreign.destroy=function()foreign_removed=foreign_removed+1;foreign.valid=false end
rec.ghost_unit=777
rec.ghost_position={x=2,y=0}
rec.next_outbound_restore_tick_0897=nil
surface.find_entities_filtered=function(args)
  local a=args and args.area
  if args.name=="entity-ghost" and a
      and a[1][1]<=2 and a[2][1]>=2
      and a[1][2]<=0 and a[2][2]>=0 then
    return {foreign}
  end
  return {}
end
local foreign_replacement,foreign_reason=
  Expansion.restore_outbound_ghost_0896(magos,rec,nil)
assert(foreign_replacement==created[4] and foreign_replacement.valid
  and foreign_replacement.unit_number~=foreign.unit_number
  and foreign_replacement.position.x>0
  and foreign_replacement.position.x~=2
  and foreign.valid and foreign_removed==0
  and rec.ghost_unit==777 and rec.ghost_position.x==2
  and source.stock==0 and bags[1].stock==1
  and foreign_reason==nil,
  "foreign original-site ghost must survive safe alternative replan")
surface.create_entity=old_create
surface.find_entities_filtered=old_find
surface.can_place_entity=old_can
_G.refresh_pair_radius=old_radius
_G.tech_priests_get_entity_prototype_0440=old_entity_proto
_G.tech_priests_surface_supports_martian_emergency_doctrine_0184=old_surface_support
print("[station-starvation-outbound-0895] PASS 0902 Factorio 2.0 ghost API arguments, exception readback, same-tick refusal, physical cargo conservation; 0901 foreign ghost, 0900 range, 0899 cleanup, reload and custody")
