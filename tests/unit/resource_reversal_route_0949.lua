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
  depot[id]={status="outbound",inventory={valid=true,amount=0,
    get_item_count=function(self,item_name)
      return self.amount
    end}}
  records[16+i]={id=16+i,status="complete",station_item=item,
    requester_station_unit=chain[i].station.unit_number,
    worker_station_unit=chain[i].station.unit_number,
    ghost_position={x=chain[i+1].station.position.x,y=0}}
end
local rec=records[17]
rec.reversal_plan_0850={status="leaf-first-preflight-only"}
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
