-- 1131: real 0480 rank topology, no fictional station/construction credits.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local H=require("scripts.core.command_hierarchy_0480")
game={tick=600}
local surface={name="nauvis",index=1}
local force={name="player",index=1}
local foreign_surface={name="vulcanus",index=2}
local foreign_force={name="enemy",index=2}
local names={[4]="planetary-magos",[3]="senior",
  [2]="intermediate",[1]="junior"}
local function make(unit,x,rank,s,f)
 local name=names[rank].."-cogitator-station"
 return {station={valid=true,unit_number=unit,name=name,
     position={x=x,y=0},surface=s or surface,force=f or force},
   priest={valid=true,unit_number=unit+1000,position={x=x,y=0}},
   rank=name,radius=26}
end
local root=make(10,0,4)
local pairs={[10]=root}
storage={tech_priests={pairs_by_station=pairs}}
local function checked_count(n)
 local a=H.network_coverage_snapshot(root)
 assert(a.stations==n,"expected "..n.." paired stations; got "..a.stations)
 return a
end
local function expect_coverage(x,id,depth)
 local yes,detail=H.position_in_network(root,{x=x,y=0})
 assert(yes and detail and detail.station_unit==id
     and detail.depth==depth,
   "wrong coverage owner at x="..x.." expected "..id)
end
H.rebuild("forced")
assert(checked_count(1).maximum_radial_extent==26)
assert(not H.position_in_network(root,{x=71,y=0}),
  "Magos has unearned territory")
local loose_priest={valid=true,name="senior-tech-priest"}
assert(loose_priest.valid and checked_count(1).stations==1,
  "unpaired extra priest fabricated coverage")
pairs[20]=make(20,48,3)
H.rebuild("forced")
expect_coverage(71,20,1)
assert(checked_count(2).by_rank[3]==1)
pairs[21]=make(21,96,2)
H.rebuild("forced")
expect_coverage(119,21,2)
assert(checked_count(3).by_rank[2]==1)
pairs[22]=make(22,144,1)
H.rebuild("forced")
expect_coverage(168,22,3)
local complete=checked_count(4)
assert(complete.deepest_grade==3
  and complete.maximum_radial_extent==170
  and complete.by_rank[1]==1)
assert(not H.position_in_authority(root,{x=168,y=0}),
  "transitive coverage improperly enlarged immediate movement authority")
pairs[40]=make(40,48,3,foreign_surface,force)
pairs[41]=make(41,48,3,surface,foreign_force)
pairs[42]=make(42,400,3,surface,force)
H.rebuild("forced")
checked_count(4)
pairs[30]=make(30,-48,3)
pairs[31]=make(31,-96,3)
H.rebuild("forced")
assert(checked_count(5).by_rank[3]==2
  and not H.position_in_network(root,{x=-121,y=0}),
  "third Senior bypassed the Magos two-socket limit")
pairs[21].priest.valid=false
H.rebuild("forced")
assert(checked_count(3).by_rank[2]==nil
  and not H.position_in_network(root,{x=119,y=0})
  and not H.position_in_network(root,{x=168,y=0}),
  "lost Intermediate priest left phantom descendant coverage")
pairs[21].priest.valid=true
H.rebuild("forced")
assert(checked_count(5).by_rank[1]==1)
pairs[22].command_hierarchy_0480.direct_subordinate_units={20}
checked_count(5)
-- 1156: two real Junior-only peer relays are beyond the Intermediate's
-- direct range. They must expand the network coverage WITHOUT giving the
-- Magos unauthorized direct movement authority or crediting a loose priest.
pairs[23]=make(23,320,1)
pairs[24]=make(24,480,1)
H.rebuild("forced")
local peer_chain=checked_count(7)
assert(peer_chain.by_rank[1]==3 and peer_chain.deepest_grade==5
    and peer_chain.maximum_radial_extent==506,
  "legitimate peer-only Junior stations did not extend ranked coverage")
expect_coverage(503,24,5)
assert(not H.position_in_authority(root,{x=503,y=0}),
  "peer network improperly became immediate Magos movement authority")
-- A one-way/forged peer link must not borrow another station's coverage.
pairs[24].command_hierarchy_0480.peer_units={}
assert(checked_count(6).by_rank[1]==2
  and not H.position_in_network(root,{x=503,y=0}),
  "unreciprocated Junior peer falsely expanded network territory")
H.rebuild("forced")
expect_coverage(503,24,5)
-- Losing a middle priest must disconnect every beyond-range peer,
-- not leave phantom area or a stale traversal cycle.
pairs[23].priest.valid=false
H.rebuild("forced")
assert(checked_count(5).by_rank[1]==1
  and not H.position_in_network(root,{x=503,y=0}),
  "dead relay priest left downstream Junior territory")
pairs[23].priest.valid=true
H.rebuild("forced")
expect_coverage(503,24,5)
print("[priest-coverage-1131] PASS physical paired Magos-Senior-Intermediate-Junior and peer network expands, invalid links shrink, command boundaries preserved")
