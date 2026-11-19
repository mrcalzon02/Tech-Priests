-- Regression 1479: dense catalog scans retain claims until absence is proven.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
game={tick=0}
storage={tech_priests={pairs_by_station={}}}
settings={global={}}
defines={inventory={chest=1}}
local entries,queries={},0
local surface={name="nauvis",index=1,valid=true}
surface.find_entities_filtered=function(options)
  queries=queries+1
  local a,b=options.area[1],options.area[2]
  local out={}
  for _,e in ipairs(entries) do
    local x,y=e.position.x,e.position.y
    if x>=a[1] and x<b[1] and y>=a[2] and y<b[2] then
      out[#out+1]=e
      if #out>=options.limit then break end
    end
  end
  return out
end
local force={index=1,name="player",valid=true}
local station={valid=true,name="junior-cogitator-station",
 unit_number=99,position={x=32,y=32},surface=surface,force=force}
local pair={station=station,priest={valid=true,unit_number=199},
 station_unit=99,radius=32}
storage.tech_priests.pairs_by_station[99]=pair
local function make(id,x,y,kind)
  return {valid=true,unit_number=id,position={x=x,y=y},
    name=kind=="resource" and "iron-ore" or "assembling-machine-1",
    type=kind=="resource" and "resource" or "assembling-machine",
    amount=250,surface=surface,force=force}
end
local C=require("scripts.core.station_catalog")
for i=1,1100 do
  entries[i]=make(i,((i-1)%33)*1.7+0.1,
    math.floor((i-1)/33)*1.7+0.1)
end
local complete=C.scan_pair(pair)
assert(complete and not complete.scan_incomplete_1478
  and complete.scan_entities_1478==1100
  and complete.scan_queries_1478==5,
  "bounded dense catalog did not enumerate 1100 entities")
assert(queries==5 and complete.scan_source_1478=="direct",
  "catalog query budget or source metadata inaccurate")
local root=storage.tech_priests[C.storage_key]
assert(root.stats.dense_scans_completed_1478==1,
  "complete dense sweep telemetry missing")
game.tick=1000
local resource=make(9000,62,62,"resource")
entries={resource}
local baseline=C.scan_pair(pair)
assert(baseline and not baseline.scan_incomplete_1478
  and root.owned_resources["u:9000"]==99,
  "ordinary complete sweep failed to establish a resource claim")
game.tick=2000
entries={}
for i=1,2400 do entries[i]=make(10000+i,
  2+(i%17)*0.001,2+(i%23)*0.001) end
entries[#entries+1]=resource  -- real resource still exists, outside truncated prefix
C.max_dense_scan_queries_1478=1
local last_queries=queries
local partial=C.scan_pair(pair)
assert(partial and partial.scan_incomplete_1478
  and partial.scan_reason_1478=="query-budget"
  and queries-last_queries==1,
  "bounded partial scan was concealed or exceeded its query budget")
assert(root.owned_resources["u:9000"]==99
  and pair.catalog_owned_resource_keys_0327["u:9000"]==true,
  "partial snapshot falsely released a physically present claim")
game.tick=3000
C.max_dense_scan_queries_1478=13
entries={}
local clean=C.scan_pair(pair)
assert(clean and not clean.scan_incomplete_1478
  and root.owned_resources["u:9000"]==nil,
  "complete empty scan failed to release a truly absent claim")
print("[station-catalog-dense-integration-1479] PASS")
