-- Regression 1484: never reuse a station snapshot after world-state changes.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Guard=require("scripts.core.station_catalog_reuse_guard_1484")
local station={valid=true,unit_number=42,name="junior-cogitator-station",
  backer_name="Citadel East",position={x=5.25,y=-10.75},
  surface={valid=true,index=1,name="nauvis"},
  force={valid=true,index=2,name="player"}}
local pair={station=station,station_unit=42}
local cat=Guard.snapshot(pair,32)
assert(cat and Guard.matches(pair,cat,32)==true,
  "stable station was denied snapshot reuse")
local function check(reason, mutate, restore)
  mutate()
  local same,why=Guard.matches(pair,cat,32)
  assert(not same and why==reason,
    "snapshot reused despite "..reason.." (got "..tostring(why)..")")
  restore()
  assert(Guard.matches(pair,cat,32)==true,"test restoration failed")
end
check("station-position-changed",function() station.position={x=5.5,y=-10.75} end,
  function() station.position={x=5.25,y=-10.75} end)
check("station-surface-changed",function() station.surface={valid=true,index=3} end,
  function() station.surface={valid=true,index=1,name="nauvis"} end)
check("station-force-changed",function() station.force={valid=true,index=3} end,
  function() station.force={valid=true,index=2,name="player"} end)
check("station-label-changed",function() station.backer_name="Renamed" end,
  function() station.backer_name="Citadel East" end)
check("station-identity-changed",function() station.unit_number=99 end,
  function() station.unit_number=42 end)
local okay,why=Guard.matches(pair,cat,24)
assert(not okay and why=="station-radius-changed","radius change ignored")
local old={station_unit=42,radius=32,station_name=station.name}
okay,why=Guard.matches(pair,old,32)
assert(not okay and why=="legacy-or-incomplete-snapshot",
  "older save without geometry should fail closed")
station.valid=false
assert(Guard.matches(pair,cat,32)==false and Guard.snapshot(pair,32)==nil,
  "invalid station allowed to reuse saved catalog")
print("[station-catalog-reuse-guard-1484] PASS: station move, force, surface, radius, labels")
