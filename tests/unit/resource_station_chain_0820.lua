-- Resource relay tests: parent->child->child physical station proof, with
-- no free ore, station items, ghost completion or forced pair creation.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Chain=require("scripts.core.resource_station_chain_0820")
game={tick=100}
local force={name="player"}
local surface={index=1}
local function pair(id,x,rank)
  local st={valid=true,unit_number=id,position={x=x,y=0},
    force=force,surface=surface,name="station-"..rank}
  return {station=st,priest={valid=true},radius=30,rank_test=rank}
end
_G.tech_priests_0252_rank_number=function(p)return p.rank_test end
local magos=pair(100,0,4)
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
    assert(need=="resource:iron-ore" and note=="ranked-remote-resource-chain")
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
