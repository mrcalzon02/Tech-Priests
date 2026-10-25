-- Resource relay tests: parent->child->child physical station proof, with
-- no free ore, station items, ghost completion or forced pair creation.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Chain=require("scripts.core.resource_station_chain_0820")
game={tick=100}
local force={name="player"}
local surface={index=1}
surface.find_entities_filtered=function(opts)
  if opts.type=="resource" and opts.name=="iron-ore"
      and opts.area and opts.area[1][1]<=154
      and opts.area[2][1]>=154
      and opts.area[1][2]<=0 and opts.area[2][2]>=0 then
    return {{valid=true,name="iron-ore",position={x=154,y=0}}}
  end
  return {}
end
_G.TechPriestsScanRouting0610={
  find_entities=function(surface_arg,filters)
    assert(surface_arg==surface and filters.type=="resource"
      and filters.limit==1,"resource scan escaped physical station surface")
    return surface.find_entities_filtered(filters)
  end,
}
local function pair(id,x,rank)
  local st={valid=true,unit_number=id,position={x=x,y=0},
    force=force,surface=surface,name="station-"..rank}
  return {station=st,priest={valid=true},radius=30,rank_test=rank}
end
_G.tech_priests_0252_rank_number=function(p)return p.rank_test end
local magos=pair(100,0,4)
local hierarchy_locked=false
local hierarchy_capacity=true
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)return p.rank_test end,
  direct_capacity_remaining=function(_)return hierarchy_capacity and 1 or 0 end,
  is_direct_subordinate=function(parent,child)
    return not hierarchy_locked and child.rank_test==parent.rank_test-1
  end,
  peers=function(parent)
    local others={}
    for _,candidate in pairs(storage.tech_priests.pairs_by_station) do
      if candidate~=parent and candidate.rank_test==1 then
        others[#others+1]=candidate
      end
    end
    if hierarchy_locked then return {} end
    return others
  end,
  peer_limit_for=function()return 16 end,
}
storage={tech_priests={
  pairs_by_station={[100]=magos},
  station_expansion_0256={},
  station_expansion_next_id_0256=1,
}}
local started,why=Chain.start(magos,"iron-ore",{x=154,y=0},"iron-ore")
assert(started and why=="mission-created","cannot plan known distant patch")
assert(not Chain.start(magos,"copper-ore",{x=300,y=0},"copper-ore"),
  "active mission was overwritten by competing resource")
local mission=Chain.status(magos)
assert(mission and mission.segments==0 and mission.current_station_unit==100
  and mission.target.x==154 and mission.status=="planning")
local requests={}
_G.TECH_PRIESTS_STATION_EXPANSION_0256={
  request_station_expansion=function(commander,need,_,note,angle)
    assert((need=="resource:iron-ore" or need=="resource:copper-ore")
      and note=="ranked-remote-resource-chain")
    assert(math.abs(angle)<0.01,"resource chain forgot true patch direction")
    local id=storage.tech_priests.station_expansion_next_id_0256
    storage.tech_priests.station_expansion_next_id_0256=id+1
    local x=commander.station.position.x+27
    local rec={id=id,status="active",
      requester_station_unit=commander.station.unit_number,
      station_item="station-"..math.max(1,commander.rank_test-1),
      blocked_item=need,ghost_position={x=x,y=0},
      phase="awaiting-physical-construction"}
    storage.tech_priests.station_expansion_0256[id]=rec
    requests[#requests+1]=rec
    return true
  end
}
hierarchy_capacity=false
local refused,limit=Chain.service_pair(magos)
assert(not refused and limit=="command-capacity-full"
  and #requests==0 and mission.pending_expansion_id==nil,
  "full command hierarchy spawned an unowned child ghost")
hierarchy_capacity=true
game.tick=game.tick+301
local worked,status=Chain.service_pair(magos)
assert(worked and status=="station-ghost-assigned"
  and #requests==1 and mission.pending_expansion_id==1
  and mission.segments==0 and mission.status=="building-station",
  "planner counted a ghost as constructed")
game.tick=game.tick+301
assert(not Chain.service_pair(magos)
  and mission.segments==0
  and mission.current_station_unit==100,
  "planner advanced past unbuilt ghost")
requests[1].status="complete"
game.tick=game.tick+301
local _,waiting=Chain.service_pair(magos)
assert(waiting=="awaiting-child-pair" and mission.segments==0,
  "new station item without paired priest was treated as delegated")
storage.tech_priests.pairs_by_station[101]=pair(101,27,3)
hierarchy_locked=true
game.tick=game.tick+301
local joined,link=Chain.service_pair(magos)
assert(not joined and link=="awaiting-hierarchy"
  and mission.segments==0 and mission.pending_expansion_id==1,
  "registered physical child bypassed authoritative command ownership")
hierarchy_locked=false
for i=1,5 do
  game.tick=game.tick+301
  local _,detail=Chain.service_pair(magos)
  if mission.status=="reached-resource" then break end
  assert(mission.current_station_unit==100+i
    and mission.segments==i and mission.pending_expansion_id
    and #requests==i+1,
    "new subordinate failed to inherit remote resource objective at link "..i)
  local child=storage.tech_priests.pairs_by_station[100+i]
  assert(child.remote_resource_assignment_0820
    and child.remote_resource_assignment_0820.root_station_unit==100
    and child.remote_resource_assignment_0820.target.x==154
    and child.remote_resource_assignment_0820.segment==i,
    "physical newly paired subordinate received no resource mission")
  local rec=requests[i+1]
  assert(rec.requester_station_unit==child.station.unit_number
    and rec.ghost_position.x>child.station.position.x,
    "relay ghost did not project outward from the NEW station")
  rec.status="complete"
  local child_x=rec.ghost_position.x
  local child_rank=math.max(1,child.rank_test-1)
  storage.tech_priests.pairs_by_station[101+i]=pair(101+i,child_x,child_rank)
end
if mission.status~="reached-resource" then
  game.tick=game.tick+301
  Chain.service_pair(magos)
end
assert(mission.status=="reached-resource"
  and mission.segments>=4 and mission.segments<=Chain.max_segments
  and mission.pending_expansion_id==nil,
  "bounded physical relay did not reach real resource patch")
-- Natural ore coverage is not delivery: verify every actual upstream
-- station and its rank, parent identity, force and command-radius edge.
local route,reason=Chain.return_route(magos)
assert(route and reason=="verified-physical-upstream-route"
  and #route==mission.segments+1
  and route[1]==mission.current_station_unit
  and route[#route]==magos.station.unit_number
  and mission.return_route_hops==mission.segments,
  "natural ore endpoint has no verified physical upstream route")
for i=1,mission.segments do
  local child=storage.tech_priests.pairs_by_station[mission.route_station_units[i+1]]
  assert(child.remote_resource_assignment_0820.parent_station_unit
    ==mission.route_station_units[i],"exact upstream parent not persisted")
end
local endpoint=storage.tech_priests.pairs_by_station[mission.current_station_unit]
local original_parent=endpoint.remote_resource_assignment_0820.parent_station_unit
endpoint.remote_resource_assignment_0820.parent_station_unit=999999
assert(not Chain.return_route(magos),"wrong upstream parent accepted")
endpoint.remote_resource_assignment_0820.parent_station_unit=original_parent
local last_id=mission.route_station_units[#mission.route_station_units]
mission.route_station_units[#mission.route_station_units]=mission.root_station_unit
assert(not Chain.return_route(magos),"duplicate station route accepted")
mission.route_station_units[#mission.route_station_units]=last_id
local old_rank=endpoint.rank_test
endpoint.rank_test=2
assert(not Chain.return_route(magos),"wrong-rank return link accepted")
endpoint.rank_test=old_rank
local old_surface=endpoint.station.surface
endpoint.station.surface={index=999}
assert(not Chain.return_route(magos),"foreign surface return link accepted")
endpoint.station.surface=old_surface
local saved_route=mission.route_station_units
mission.route_station_units=nil
local legacy=Chain.return_route(magos)
assert(legacy and #legacy==#route and mission.route_station_units
  and mission.route_station_units[#mission.route_station_units]==last_id,
  "unique legacy paired route did not reconstruct")
mission.route_station_units=nil
local duplicate=pair(999,140,1)
duplicate.remote_resource_assignment_0820={
  root_station_unit=mission.root_station_unit,segment=mission.segments}
storage.tech_priests.pairs_by_station[999]=duplicate
assert(not Chain.return_route(magos),"ambiguous legacy segment accepted")
storage.tech_priests.pairs_by_station[999]=nil
mission.route_station_units=saved_route
local station=endpoint.station
endpoint.station={valid=false}
assert(not Chain.return_route(magos),"missing physical station accepted")
endpoint.station=station
-- Lua module reload exercises persisted primitive IDs only. Actual Factorio
-- save/restart and counted ore transfer remain independent engine gates.
package.loaded["scripts.core.resource_station_chain_0820"]=nil
local ReloadedChain=require("scripts.core.resource_station_chain_0820")
assert(ReloadedChain.return_route(magos),"persisted route not revalidated")
local last=storage.tech_priests.pairs_by_station[mission.current_station_unit]
assert((last.station.position.x-154)^2<=last.radius^2
  and last.remote_resource_assignment_0820
  and last.remote_resource_assignment_0820.need=="iron-ore",
  "final subordinate cannot work patch within its own station radius")
-- Existing paired resource coverage or an unverified ghost must not be
-- counted as mission progress.
game.tick=game.tick+500
local failed_root=pair(200,0,4)
storage.tech_priests.pairs_by_station[200]=failed_root
assert(Chain.start(failed_root,"copper-ore",{x=120,y=0},"copper-ore"))
Chain.service_pair(failed_root)
local rec=storage.tech_priests.station_expansion_0256[
  Chain.status(failed_root).pending_expansion_id]
rec.status="failed"
rec.note="ghost-site-invalid"
game.tick=game.tick+301
local progressed,failure=Chain.service_pair(failed_root)
assert(not progressed and failure=="station-construction-failed:ghost-site-invalid"
  and Chain.status(failed_root).status=="blocked",
  "construction failure was disguised as resource access")
print("[resource-station-chain-0820] PASS bounded ranked relay, real pairing, inheritance, and failed-build hold")
-- Verify the real ghost/inventory/physical station builder separately.
dofile("tests/unit/resource_station_physical_0820.lua")
-- Independent long-haul rail strategy must detect genuine starvation rather
-- than disguising another Cogitator relay chain as a train.
dofile("tests/unit/remote_rail_outpost_0835.lua")
