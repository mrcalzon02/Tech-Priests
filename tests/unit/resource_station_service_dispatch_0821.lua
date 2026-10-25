-- Regression: a real known-resource relay must advance from the Magos'
-- installed emergency-service wrapper even during the discovery cooldown.
-- All station records are physical-executor fixtures; no free items or ore.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Chain=require("scripts.core.resource_station_chain_0820")
game={tick=100}
local force={name="player"}
local surface={index=1}
local function pair(id,x,rank)
  return {
    station={valid=true,unit_number=id,position={x=x,y=0},
      force=force,surface=surface,name="station-"..rank},
    priest={valid=true,position={x=x,y=0}},
    rank_test=rank,radius=30,
  }
end
local magos=pair(100,0,4)
storage={tech_priests={
  pairs_by_station={[100]=magos},
  station_expansion_0256={},
  station_expansion_next_id_0256=1,
}}
tech_priests_0252_rank_number=function(p)return p.rank_test end
tech_priests_0255_pair_is_magos_planner=function(p)return p==magos end
TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)return p.rank_test end,
  direct_capacity_remaining=function()return 1 end,
  is_direct_subordinate=function(parent,child)
    return parent.rank_test==child.rank_test+1
  end,
}
local requests={}
TECH_PRIESTS_STATION_EXPANSION_0256={
  request_station_expansion=function(commander,need,_,note,angle)
    assert(need=="resource:iron-ore"
      and note=="ranked-remote-resource-chain"
      and math.abs(angle)<0.01)
    local id=storage.tech_priests.station_expansion_next_id_0256
    storage.tech_priests.station_expansion_next_id_0256=id+1
    local rec={id=id,status="active",phase="awaiting-physical-construction",
      requester_station_unit=commander.station.unit_number,
      blocked_item=need,
      ghost_position={x=commander.station.position.x+27,y=0}}
    storage.tech_priests.station_expansion_0256[id]=rec
    requests[#requests+1]=rec
    return true
  end,
}
local original_calls=0
tech_priests_service_independent_emergency_operation_0184=function()
  original_calls=original_calls+1
  return false
end
assert(Chain.start(magos,"iron-ore",{x=160,y=0},"iron-ore"))
-- Resource discovery is intentionally suppressed for far longer than the
-- five-second relay scheduler: the active chain must still be serviced.
magos.resource_expansion_0259.next_tick=999999
dofile("tech-priests_src/scripts/resource_expansion.lua")
assert(tech_priests_service_independent_emergency_operation_0184(magos)==false)
local mission=Chain.status(magos)
assert(original_calls==1 and #requests==1
  and mission.status=="building-station"
  and mission.pending_expansion_id==1
  and mission.segments==0,
  "emergency wrapper failed to dispatch first physical relay")
game.tick=101
tech_priests_service_independent_emergency_operation_0184(magos)
assert(#requests==1 and mission.pending_expansion_id==1,
  "relay bypassed its own bounded service interval")
-- An expansion record cannot advance the hierarchy until an actual
-- registered subordinate pair exists at the completed physical station.
game.tick=401
requests[1].status="complete"
tech_priests_service_independent_emergency_operation_0184(magos)
assert(#requests==1 and mission.status=="awaiting-new-station-pair",
  "completed station record without a priest was treated as delegated")
storage.tech_priests.pairs_by_station[101]=pair(101,27,3)
game.tick=701
tech_priests_service_independent_emergency_operation_0184(magos)
assert(#requests==2 and mission.segments==1
  and mission.current_station_unit==101
  and requests[2].requester_station_unit==101
  and mission.pending_expansion_id==2
  and magos.resource_expansion_0259.next_tick==999999,
  "Magos did not delegate next physical ghost to newly paired Senior")
-- A blocked mission must remain visible, not silently spawn a replacement.
mission.status="blocked"
game.tick=1001
tech_priests_service_independent_emergency_operation_0184(magos)
assert(#requests==2 and mission.status=="blocked",
  "blocked physical relay was silently replaced")
print("[resource-station-service-dispatch-0821] PASS live wrapper, bounded relay, physical pairing, delegated next link")

-- Existing source-validation workflow exercises the physical ore courier.
dofile("tests/unit/resource_return_courier_0837.lua")

-- The same ore must cross every rank using separate real inventory debits.
dofile("tests/unit/resource_return_multihop_0838.lua")
