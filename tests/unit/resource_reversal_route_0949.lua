-- 0949: only four actually rebuilt original priests/stations may turn a
-- starvation reversal writ into an ore-return route. No synthetic ore/items.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
package.loaded["scripts.core.resource_station_chain_0820"]=nil
local Chain=require("scripts.core.resource_station_chain_0820")
local force={index=1}
local surface={index=1}
local names={"planetary-magos-cogitator-station","senior-cogitator-station",
  "intermediate-cogitator-station","junior-cogitator-station",
  "junior-cogitator-station"}
local pairs,by_priest={},{}
local function pair(id,x,rank,priest)
  local p={station={valid=true,unit_number=id,name=names[5-rank],
    position={x=x,y=0},force=force,surface=surface},
    priest={valid=true,unit_number=priest,position={x=x,y=0}},
    rank_test=rank,radius=30}
  pairs[id]=p
  by_priest[priest]=p
  return p
end
local magos=pair(100,0,4,500)
local senior=pair(101,20,3,501)
local intermediate=pair(102,40,2,502)
local junior=pair(103,60,1,503)
local peer=pair(104,80,1,504)
-- The five old stations are absent. Original priests 500..504 are alive
-- and registered to the NEW real station entities.
local original={201,202,203,204}
local stages={}
local records={}
local depot={}
local chain={magos,senior,intermediate,junior,peer}
for i=1,4 do
  local item=names[i+1]
  local id="reversal-leaf:17:"..original[i]
  stages[i]={id=id,leaf_station_unit=original[i],
    leaf_priest_unit=500+i}
  local inv={valid=true,amount=0}
  inv.get_item_count=function() return inv.amount end
  depot[id]={status="outbound",inventory=inv}
  records[16+i]={id=16+i,status="complete",station_item=item,
    blocked_item="resource:iron-ore",
    requester_station_unit=chain[i].station.unit_number,
    worker_station_unit=chain[i].station.unit_number,
    ghost_position={x=chain[i+1].station.position.x,y=0}}
end
local rec=records[17]
rec.reversal_plan_0850={status="leaf-first-preflight-only",
  root_station_unit=100,target={x=84,y=0},
  required_item="senior-cogitator-station"}
rec.reversal_stage_0855=stages[1]
rec.reversal_stage_0854=stages[2]
rec.reversal_stage_0853=stages[3]
rec.reversal_stage_0851=stages[4]
rec.reversal_next_0911={child_writ_id=18}
rec.reversal_junior_0919={child_writ_id=19}
rec.reversal_second_junior_0943={child_writ_id=20}
local ore={valid=true,type="resource",name="iron-ore",
  amount=9,position={x=84,y=0},surface=surface}
_G.TechPriestsScanRouting0610={find_entities=function(s,filters,opts)
  assert(s==surface and filters.name=="iron-ore"
    and opts.require_fresh==true)
  return {ore}
end}
local peers_linked=true
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)return p.rank_test end,
  is_direct_subordinate=function(parent,child)
    return child.rank_test==parent.rank_test-1
      and child.station.position.x-parent.station.position.x==20
  end,
  peers=function(p)
    if peers_linked and p==junior then return {peer} end
    return {}
  end,
}
_G.game={tick=1000}
local mission={status="building-station",root_station_unit=100,
  current_station_unit=100,current_rank=4,segments=0,
  pending_expansion_id=17,route_station_units={100},
  target={x=84,y=0},resource_name="iron-ore",need="iron-ore",
  next_tick=0}
magos.resource_expansion_0259={chain_0820=mission}
_G.storage={tech_priests={pairs_by_station=pairs,pairs_by_priest=by_priest,
  station_expansion_0256=records,station_reversal_depot_0852=depot,
  station_cargo_0824={},station_relocation_0823={}}}
-- 0952: The real 0256 Senior pickup previously erased the original
-- 0850 plan after physical depot debit. Verify exact provenance retention
-- while refusing stale, foreign or unarmed preflight state.
local Outbound=require("scripts.core.station_starvation_outbound_0895")
local plan=rec.reversal_plan_0850
plan.stages={
  {station_unit=204,parent_station_unit=203,item="junior-cogitator-station"},
  {station_unit=203,parent_station_unit=202,item="junior-cogitator-station"},
  {station_unit=202,parent_station_unit=201,item="intermediate-cogitator-station"},
  {station_unit=201,parent_station_unit=100,item="senior-cogitator-station"},
}
local senior_stage=rec.reversal_stage_0855
senior_stage.phase="in-magos-depot"
senior_stage.reversal_stage_index=4
senior_stage.station_item="senior-cogitator-station"
rec.reversal_outbound_0895={
  phase="senior-build-authorized",writ_id=17,stage_id=senior_stage.id,
  magos_unit=100,magos_priest_unit=500,
  original_senior_unit=201,original_senior_priest=501,
  target={x=84,y=0}}
rec.status="active"
assert(Outbound.preserve_root_reversal_plan_after_pickup(magos,rec),
  "original four-depot Senior pickup lost its 0850 provenance")
local outbound=rec.reversal_outbound_0895
outbound.phase="senior-carried"
assert(not Outbound.preserve_root_reversal_plan_after_pickup(magos,rec),
  "premature outward transit must not preserve an unarmed preflight")
outbound.phase="senior-build-authorized"
outbound.magos_priest_unit=999
assert(not Outbound.preserve_root_reversal_plan_after_pickup(magos,rec),
  "foreign Magos priest must not preserve the root writ")
outbound.magos_priest_unit=500
outbound.target.x=85
assert(not Outbound.preserve_root_reversal_plan_after_pickup(magos,rec),
  "retargeted outbound escrow must not preserve the root writ")
outbound.target.x=84
mission.status="cancelled"
assert(not Outbound.preserve_root_reversal_plan_after_pickup(magos,rec),
  "cancelled reversal must not preserve a stale preflight")
mission.status="building-station"
rec.reversal_stage_0854=nil
assert(not Outbound.preserve_root_reversal_plan_after_pickup(magos,rec),
  "missing intermediate custody stage must not preserve the root writ")
rec.reversal_stage_0854=stages[2]
assert(Outbound.preserve_root_reversal_plan_after_pickup(magos,rec),
  "restored exact original staged writ must remain identifiable")
rec.status="complete"
rec.reversal_outbound_0895=nil
local executor_source=assert(io.open(
  "tech-priests_src/scripts/magos_station_expansion.lua","r"))
local executor_text=executor_source:read("*a")
executor_source:close()
assert(executor_text:find(
  "StarvationOutbound0895.preserve_root_reversal_plan_after_pickup(",
  1,true),"native 0256 pickup is not wired to the provenance guard")

local function try_reconcile()
  game.tick=game.tick+301
  return Chain.service_pair(magos)
end
local function untouched()
  assert(mission.status=="building-station"
    and mission.pending_expansion_id==17 and mission.segments==0
    and mission.current_station_unit==100 and #mission.route_station_units==1
    and not junior.remote_resource_assignment_0820,
    "unverified reversal advanced the mission or wrote an ore route")
end
records[20].status="active"
local ok,why=try_reconcile()
assert(not ok and why:find("not-verified",1,true))
untouched()
records[20].status="complete"
peers_linked=false
ok,why=try_reconcile()
assert(not ok and why=="reversal-original-junior-peer-missing")
untouched()
peers_linked=true
depot[stages[4].id].inventory.amount=1
ok,why=try_reconcile()
assert(not ok and why=="reversal-original-depot-not-empty:4")
untouched()
depot[stages[4].id].inventory.amount=0
ore.amount=0
ok,why=try_reconcile()
assert(not ok and why=="reversal-natural-ore-not-observed")
untouched()
ore.amount=9
local saved=by_priest[504]
by_priest[504]=nil
ok,why=try_reconcile()
assert(not ok and why:find("not-verified",1,true))
untouched()
by_priest[504]=saved
-- 0950: the periodic 0820 owner may have blocked its old single-child
-- mission before the four original physical station reconstructions finished.
-- A block must NOT bypass any physical acceptance gate or reopen an
-- unrelated/cancelled mission; only the exact original reversal writ can
-- reconcile after all original priests and real inventories are verified.
mission.status="blocked"
mission.last_reason="prior-single-child-expansion-blocked"
records[20].status="active"
ok,why=try_reconcile()
assert(not ok and why:find("not-verified",1,true)
  and mission.status=="blocked" and mission.pending_expansion_id==17,
  "blocked reversal was credited before final native station construction")
records[20].status="complete"
local original_plan=rec.reversal_plan_0850
rec.reversal_plan_0850=nil
ok,why=try_reconcile()
assert(not ok and why=="no-active-chain" and mission.status=="blocked",
  "unrelated blocked chain must not be reopened")
rec.reversal_plan_0850=original_plan
mission.status="cancelled"
ok,why=try_reconcile()
assert(not ok and why=="no-active-chain" and mission.status=="cancelled",
  "cancelled mission must not be reactivated by a reversal writ")
-- 0951: Real 0950 engine logs show pending=nil and a blocked mission
-- (physical-resource-depleted-or-missing) after the generic owner consumed
-- the original writ. Restore it ONLY for strict physical reconciliation.
mission.status="blocked"
mission.last_reason="physical-resource-depleted-or-missing"
mission.pending_expansion_id=nil
mission.segments=1
mission.current_station_unit=101
mission.current_rank=3
mission.route_station_units={100,101}
records[20].status="active"
ok,why=try_reconcile()
assert(not ok and why:find("not-verified",1,true)
  and mission.pending_expansion_id==nil and mission.segments==1
  and mission.status=="blocked",
  "incomplete original second Junior bypassed custody or altered blocked mission")
records[20].status="complete"
local saved_target=original_plan.target.x
original_plan.target.x=999
ok,why=try_reconcile()
assert(not ok and why=="no-active-chain"
  and mission.pending_expansion_id==nil and mission.status=="blocked",
  "wrong-target reversal writ recovered an unrelated blocked mission")
original_plan.target.x=saved_target
records[21]={id=21,status="complete",
  station_item="senior-cogitator-station",
  blocked_item="resource:iron-ore",
  requester_station_unit=100,worker_station_unit=100,
  reversal_plan_0850=original_plan}
ok,why=try_reconcile()
assert(not ok and why=="reversal-original-writ-ambiguous"
  and mission.pending_expansion_id==nil and mission.status=="blocked",
  "ambiguous original writ was selected without unique custody")
records[21]=nil
mission.pending_expansion_id=99
ok,why=try_reconcile()
assert(not ok and why=="reversal-original-writ-conflicting-pending"
  and mission.pending_expansion_id==99 and mission.status=="blocked",
  "foreign active construction writ was overwritten")
mission.pending_expansion_id=nil
ok,why=try_reconcile()
assert(ok and why=="reversal-original-five-station-route-and-natural-ore-verified"
  and mission.status=="reached-resource" and mission.segments==4
  and mission.pending_expansion_id==nil
  and mission.current_station_unit==104
  and mission.return_route_hops==4)
local route,reason=Chain.return_route(magos)
assert(route and reason=="verified-physical-upstream-route"
  and table.concat(route,",")=="104,103,102,101,100")
for i=2,5 do
  local assignment=chain[i].remote_resource_assignment_0820
  assert(assignment and assignment.root_station_unit==100
    and assignment.parent_station_unit==chain[i-1].station.unit_number
    and assignment.segment==i-1)
end
package.loaded["scripts.core.resource_station_chain_0820"]=nil
local Reloaded=require("scripts.core.resource_station_chain_0820")
assert(Reloaded.return_route(magos),"reconciled original-priest route lost on reload")
print("[resource-reversal-route-0949] PASS original five priests, four physical empty depots, natural ore, strict hierarchy and save-safe counted route")
