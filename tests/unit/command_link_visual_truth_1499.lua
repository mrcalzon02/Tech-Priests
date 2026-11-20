-- No Factorio APIs needed: verifies the exact 0480 link slate contracts.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Truth = require('scripts.core.command_link_visual_truth_1499')
local surface, force = {}, {}
local function pair(unit, rank, x, force_override, surface_override)
  return {
    station = {valid=true, unit_number=unit, force=force_override or force,
      surface=surface_override or surface, position={x=x,y=0}},
    priest = {valid=true, unit_number=unit+1000},
    command_hierarchy_0480 = {rank=rank, superior_unit=nil,
      direct_subordinate_units={}, peer_units={}},
  }
end
local magos, senior, intermediate = pair(10,4,0), pair(11,3,30), pair(12,2,50)
local junior_a, junior_b = pair(13,1,72), pair(14,1,84)
local function direct(parent,child)
  parent.command_hierarchy_0480.direct_subordinate_units[#parent.command_hierarchy_0480.direct_subordinate_units+1] = child.station.unit_number
  child.command_hierarchy_0480.superior_unit = parent.station.unit_number
end
local function kind(a,b)
  return Truth.classify(a,b,220)
end
-- Proximity is not authority, regardless of rank or shared force.
assert(kind(magos,senior)==nil)
assert(kind(junior_a,junior_b)==nil)
-- One-sided stale slates are not enough.
magos.command_hierarchy_0480.direct_subordinate_units={11}
assert(kind(magos,senior)==nil)
magos.command_hierarchy_0480.direct_subordinate_units={}
senior.command_hierarchy_0480.superior_unit=10
assert(kind(magos,senior)==nil)
senior.command_hierarchy_0480.superior_unit=nil
-- Real 0480 parent+child has one solid line, not a nearest-rank guess.
direct(magos,senior)
assert(kind(magos,senior)=='direct' and kind(senior,magos)=='direct')
direct(senior,intermediate)
assert(kind(senior,intermediate)=='direct')
assert(kind(magos,intermediate)==nil)
-- A one-sided Junior peer is not a confirmed mutual connection.
junior_a.command_hierarchy_0480.peer_units={14}
assert(kind(junior_a,junior_b)==nil)
junior_b.command_hierarchy_0480.peer_units={13}
assert(kind(junior_a,junior_b)=='peer')
-- Constraints: invalid physical pairing, force, surface, range, and old rank.
local distant = pair(20,3,500)
direct(magos,distant)
assert(kind(magos,distant)==nil)
assert(Truth.classify(magos,senior,20)==nil)
local foreign = pair(21,3,25, {})
direct(magos,foreign)
assert(kind(magos,foreign)==nil)
local elsewhere = pair(22,3,25,nil,{})
direct(magos,elsewhere)
assert(kind(magos,elsewhere)==nil)
local dead = pair(23,3,25)
direct(magos,dead)
dead.priest.valid=false
assert(kind(magos,dead)==nil)
local stale = pair(24,3,35)
direct(magos,stale)
stale.command_hierarchy_0480=nil
assert(kind(magos,stale)==nil)
local unknown = pair(25,3,35)
direct(magos,unknown)
unknown.command_hierarchy_0480.rank=2
assert(kind(magos,unknown)==nil)
assert(Truth.collect({magos,senior,intermediate,junior_a,junior_b},10,220)[1].kind=='direct')
local links = Truth.collect({magos,senior,intermediate,junior_a,junior_b},10,220)
assert(#links==3)
assert(links[1].kind=='direct' and links[2].kind=='direct' and links[3].kind=='peer')
assert(#Truth.collect({magos,senior,intermediate,junior_a,junior_b},2,220)==2)
assert(#Truth.collect({magos,senior},100,nil)==0)
print('PASS: verified command links only, bounded lines, no inferred peers')
