package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.rail_route_choice_1403")
local f={unit_number=100,position={x=99,y=1}}
local target={x=512,y=6}
local raw={
 {name="straight-rail",position={x=101,y=1},direction=4,from_rail_unit=100},
 {name="curved-rail-a",position={x=103,y=5},direction=2,from_rail_unit=100},
 {name="curved-rail-a",position={x=103,y=5},direction=2,from_rail_unit=100},
 {name="straight-rail",position={x=97,y=1},direction=4,from_rail_unit=100},
 {name="straight-rail",position={x=101,y=1},direction=4,from_rail_unit=999},
 {name="straight-rail",position={x=99,y=1},direction=4,from_rail_unit=100},
 {name="rail-ramp",position={x=0/0,y=1},direction=4,from_rail_unit=100},
}
local a,why=M.rank(f,raw,target)
assert(why=="native-progressive-rail-options-1403" and #a==2)
assert(a[1].name=="curved-rail-a" and a[2].name=="straight-rail")
assert(a[1].position.x==103 and a[1].from_rail_unit==100)
assert(#raw==7 and raw[1].position.x==101,"immutable source")
local broken,reason=M.rank(f,raw,{x=1,y=1})
assert(#broken==1 and broken[1].position.x==97)
assert(reason=="native-progressive-rail-options-1403")
local none,why=M.rank({unit_number=101,position=f.position},raw,target)
assert(#none==0 and why=="no-progressive-rail-extension-1403")
local invalid,why=M.rank(f,raw,{x=0/0,y=1})
assert(#invalid==0 and why=="invalid-rail-geometry-1403")
local empty,reason=M.rank(f,raw,target,{max_input=0})
assert(#empty==0 and reason=="no-progressive-rail-extension-1403")
local one=M.rank(f,raw,target,{max_output=1})
assert(#one==1 and one[1].name=="curved-rail-a")
print("[rail-route-choice-1403] PASS progressive native geometry, stable ranking, no backward/foreign/invalid rails")
