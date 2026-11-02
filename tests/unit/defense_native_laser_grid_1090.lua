-- 1090: real Factorio 2.0 electricity proof, NOT geometrical-only power.
-- Exercise the actual production defense planner's read-only support probe.
game={tick=6000}
local force={name="player",index=1}
local enemy={name="enemy",index=2}
local function native_proto(supply)
  return setmetatable({
    get_supply_area_distance=function(_,quality)
      -- Factorio methods can be called as proto.method("normal").
      assert(quality==nil or quality=="normal",
        "laser support requested unexpected quality")
      return supply
    end,
    get_max_wire_distance=function()return 9 end
  },{__index=function(_,name)
    if name=="supply_area_distance" then
      error("Factorio 2.0 no longer exposes 1.1 supply_area_distance property")
    end
  end})
end
local poles={}
local find_calls=0
local surface={}
function surface.find_entities_filtered(filter)
  assert(filter.type=="electric-pole" and filter.force==force
    and filter.limit and filter.limit<=64,
    "laser support bypassed bounded friendly-grid lookup")
  find_calls=find_calls+1
  local found={}
  for _,p in ipairs(poles)do
    if p.valid and p.force==filter.force
      and p.position.x>=filter.area[1][1]
      and p.position.x<=filter.area[2][1]
      and p.position.y>=filter.area[1][2]
      and p.position.y<=filter.area[2][2]then
      found[#found+1]=p
    end
  end
  return found
end
local station={valid=true,surface=surface,force=force}
local pair={station=station}
local position={x=4,y=4}
local function pole(x,y,id,supply,ownership)
  local p={valid=true,force=ownership or force,position={x=x,y=y},
    electric_network_id=id,prototype=native_proto(supply)}
  poles[#poles+1]=p
  return p
end
local original_tick_pair=function()return false end
tick_pair=original_tick_pair
dofile("tech-priests_src/scripts/defense_perimeter.lua")
local bridge=assert(_G.TechPriestsDefensePerimeter0259)
local powered=assert(bridge.connected_laser_supply_at)
assert(not powered(pair,position),
  "a world without electric poles was called laser-supported")
local isolated=pole(4,4,nil,5)
assert(not powered(pair,position),
  "isolated unconnected pole falsely enabled laser placement")
isolated.electric_network_id=0
assert(not powered(pair,position),
  "zero electric network ID falsely enabled laser placement")
isolated.electric_network_id=73
assert(powered(pair,position),
  "real connected pole with native supply area was rejected")
isolated.valid=false
local enemy_pole=pole(4,4,73,5,enemy)
assert(not powered(pair,position),
  "hostile electric grid was treated as owned laser support")
enemy_pole.valid=false
local corner=pole(7,7,73,3)
assert(powered(pair,position),
  "Factorio pole supply area is square, not circular")
corner.position.x=7.8
assert(not powered(pair,position),
  "laser placement reached beyond connected native supply rectangle")
corner.valid=false
local unavailable=pole(4,4,73,nil)
assert(not powered(pair,position),
  "missing Factorio 2 prototype power geometry was guessed")
unavailable.valid=false
local restored=pole(4,4,73,5)
assert(powered(pair,position),"live grid not accepted after restoration")
restored.electric_network_id=nil
assert(not powered(pair,position),
  "disconnected grid remained credited after engine-network loss")
assert(find_calls>=9 and #poles==5,
  "not all real-grid negative controls were executed")
local wire_connected=assert(bridge.connected_laser_pole_site)
local next_proto=native_proto(3)
assert(not wire_connected(pair,next_proto,{x=2,y=2},{}),
  "isolated new laser pole site was accepted with no existing grid")
local real_anchor=pole(0,0,73,3)
local one_site={x=7,y=0}
assert(wire_connected(pair,next_proto,one_site,{real_anchor}),
  "same-grid copper wire reach rejected")
real_anchor.electric_network_id=nil
assert(not wire_connected(pair,next_proto,one_site,{real_anchor}),
  "unconnected original pole was accepted as a wiring source")
real_anchor.electric_network_id=73
assert(not wire_connected(pair,next_proto,{x=9.9,y=0},{real_anchor}),
  "prospective laser support exceeded native wire distance")
real_anchor.force=enemy
assert(not wire_connected(pair,next_proto,one_site,{real_anchor}),
  "laser power support wired to foreign-force grid")
print("[defense-native-laser-grid-1090] PASS actual electrical ID, native square supply geometry, force isolation, outage recovery")
