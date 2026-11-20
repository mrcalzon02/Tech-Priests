-- 1503: pair-state reports must agree with the 0480 command authority.
-- Offline Lua mock, not native Factorio hierarchy/visual acceptance.
package.path = "./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;" .. package.path
local Ledger = require("scripts.core.station_pair_state")
local force, surface = {name="A"}, {index=1,name="nauvis"}
local function make_pair(id, rank, x, name)
  local station = {
    valid=true,unit_number=id,position={x=x,y=0},
    surface=surface,force=force,name=name,backer_name=name,
  }
  local priest = {
    valid=true,unit_number=id+1000,position={x=x+2,y=0},
    surface=surface,force=force,name="junior-tech-priest",
  }
  return {
    station=station,priest=priest,station_unit=id,priest_unit=id+1000,rank=rank,
    mode="idle",command_hierarchy_0480={
      rank=rank,superior_unit=nil,direct_subordinate_units={},peer_units={},
    },
  }
end
local magos=make_pair(10,4,0,"planetary-magos-cogitator-station")
local senior=make_pair(11,3,20,"senior-cogitator-station")
local intermediate=make_pair(12,2,40,"intermediate-cogitator-station")
local junior1=make_pair(13,1,60,"junior-cogitator-station")
local junior2=make_pair(14,1,75,"junior-cogitator-station")
storage={tech_priests={
  pairs_by_station={[10]=magos,[11]=senior,[12]=intermediate,
    [13]=junior1,[14]=junior2},
}}
game={tick=600}
defines={inventory={
  chest=1,assembling_machine_input=2,assembling_machine_output=3,
  furnace_source=4,furnace_result=5,fuel=6,burnt_result=7,
  character_main=8,spider_trunk=9,car_trunk=10,
}}
-- A physical station can exist before 0480 has finished installation.
-- Never interpret nearby rank matches as a verified hierarchy.
local unavailable=Ledger.refresh_pair(magos,"test-unavailable")
assert(unavailable.hierarchy.status=="unavailable")
assert(unavailable.hierarchy.superior_label=="unverified")
assert(unavailable.hierarchy.direct_subordinate_count==nil)
assert(unavailable.hierarchy.peer_count==nil)
assert(table.concat(Ledger.describe_pair(magos),"\n"):find("0480 unavailable",1,true))

_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={_installed=true,max_link_distance=220}
storage.tech_priests.command_hierarchy_0480={enabled=true}
-- All stations are within range, but none is assigned: zero verified edges.
local empty=Ledger.refresh_pair(magos,"test-empty")
assert(empty.hierarchy.status=="verified")
assert(empty.hierarchy.superior_label=="none")
assert(empty.hierarchy.direct_subordinate_count==0)
assert(empty.hierarchy.peer_count==0)
assert(Ledger.refresh_pair(junior1).hierarchy.peer_count==0)

local function direct(parent,child)
  parent.command_hierarchy_0480.direct_subordinate_units[#parent.command_hierarchy_0480.direct_subordinate_units+1]=child.station_unit
  child.command_hierarchy_0480.superior_unit=parent.station_unit
end
direct(magos,senior)
direct(senior,intermediate)
local m=Ledger.refresh_pair(magos)
local s=Ledger.refresh_pair(senior)
assert(m.hierarchy.status=="verified" and m.hierarchy.direct_subordinate_count==1)
assert(s.hierarchy.status=="verified" and s.hierarchy.superior_station_unit==10)
assert(s.hierarchy.superior_label:find("planetary%-magos"))
assert(s.hierarchy.direct_subordinate_count==1)
junior1.command_hierarchy_0480.peer_units={14}
local one_way=Ledger.refresh_pair(junior1)
assert(one_way.hierarchy.status=="inconsistent-slate" and one_way.hierarchy.peer_count==0)
junior2.command_hierarchy_0480.peer_units={13}
assert(Ledger.refresh_pair(junior1).hierarchy.peer_count==1)
assert(Ledger.refresh_pair(junior2).hierarchy.peer_count==1)

-- Stale/one-sided relationships never become visible merely by proximity.
senior.command_hierarchy_0480.superior_unit=nil
m=Ledger.refresh_pair(magos)
assert(m.hierarchy.status=="inconsistent-slate" and m.hierarchy.direct_subordinate_count==0)
assert(Ledger.refresh_pair(senior).hierarchy.superior_station_unit==nil)
senior.command_hierarchy_0480.superior_unit=10
senior.station.force={name="foreign"}
assert(Ledger.refresh_pair(magos).hierarchy.direct_subordinate_count==0)
senior.station.force=force
senior.station.position.x=500
assert(Ledger.refresh_pair(magos).hierarchy.direct_subordinate_count==0)
senior.station.position.x=20

storage.tech_priests.command_hierarchy_0480.enabled=false
local disabled=Ledger.refresh_pair(magos)
assert(disabled.hierarchy.status=="disabled")
assert(disabled.hierarchy.superior_label=="unverified")
assert(disabled.hierarchy.direct_subordinate_count==nil)
assert(table.concat(Ledger.describe_pair(magos),"\n"):find("0480 disabled",1,true))
storage.tech_priests.command_hierarchy_0480.enabled=true
magos.command_hierarchy_0480=nil
assert(Ledger.refresh_pair(magos).hierarchy.status=="slate-pending")

print("[station-pair-hierarchy-truth-1503] PASS: canonical links only; missing/disabled authority distinguished")
