-- Unitless entities require exact coordinates, surface, force, and prototype.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local I=require("scripts.core.entity_identity_1481")
local surface={index=1,name="nauvis"}
local force={index=2,name="player"}
local function rock(x,y,force_arg,surface_arg)
 return {valid=true, name="rock-huge",type="simple-entity",
   surface=surface_arg or surface,force=force_arg or force,position={x=x,y=y}}
end
local a=rock(10.011,11.02)
local b=rock(10.019,11.02)
assert(I.key(a)~=I.key(b),"fractional positions were merged")
assert(I.key(rock(10.011,11.02))==I.key(a),"same world entity coordinates unstable")
assert(I.key(rock(10.011,11.02,{index=3}))~=I.key(a),"different forces merged")
assert(I.key(rock(10.011,11.02,force,{index=5}))~=I.key(a),"different surfaces merged")
assert(I.key({valid=true,unit_number=17})=="u:17","unit identity changed")
assert(I.key({valid=false,unit_number=17})==nil,"invalid entity returned identity")
assert(I.key({valid=true,name="iron-ore",type="resource",surface=surface,
  position={x=-0.00390625,y=-120000.1015625}})
  ~=I.key({valid=true,name="iron-ore",type="resource",surface=surface,
  position={x=0.00390625,y=-120000.1015625}}),"negative fractional offset rounded")
print("[entity-identity-1481] PASS")
