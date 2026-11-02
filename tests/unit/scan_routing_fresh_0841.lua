-- The indexed 0579 spatial catalog can be stale after generation of a
-- remote natural ore chunk. Courier inventory safety requires a bounded
-- fresh read from the *existing* canonical scan authority.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Scan=require("scripts.core.scan_routing_0610")
local old_index=rawget(_G,"tech_priests_efficiency_0579_entities_for_area")
local old_note=rawget(_G,"tech_priests_efficiency_0579_note_area_scan")
local old_metric=rawget(_G,"tech_priests_runtime_metric_0606")
local indexed,scanned,notes,physical_direct_metric=0,0,0,0
_G.tech_priests_runtime_metric_0606=function(key,n)
  if key=="direct_surface_scans" then
    physical_direct_metric=physical_direct_metric+(n or 1)
  end
end
_G.game={tick=120}
_G.storage={tech_priests={}}
local ore={valid=true,name="iron-ore",type="resource",position={x=200,y=20},
  amount=15}
local surface={valid=true}
function surface.find_entities_filtered(filter)
  scanned=scanned+1
  assert(filter.limit==8 and filter.name=="iron-ore" and filter.type=="resource"
    and filter.area[1][1]==196 and filter.area[2][1]==204,
    "fresh ore scan widened or changed the natural target area")
  return {ore}
end
_G.tech_priests_efficiency_0579_entities_for_area=function()
  indexed=indexed+1
  return {}
end
_G.tech_priests_efficiency_0579_note_area_scan=function(_,_,found)
  notes=notes+1
  assert(#found==1 and found[1]==ore)
  -- The real 0579 catalog emits the physical direct-scan metric itself.
  _G.tech_priests_runtime_metric_0606("direct_surface_scans",1)
  return true
end
local filter={type="resource",name="iron-ore",
  area={{196,16},{204,24}},limit=8}
local cached,from=Scan.find_entities(surface,filter,{category="resource",limit=8})
assert(#cached==0 and from=="indexed-0579" and indexed==1
  and scanned==0 and notes==0,"test failed to reproduce the stale cache")
local fresh,source=Scan.find_entities(surface,filter,
  {category="resource",limit=8,require_fresh=true})
assert(#fresh==1 and fresh[1]==ore and source=="direct-scan"
  and indexed==1 and scanned==1 and notes==1,
  "fresh physical courier scan incorrectly reused stale index or invented ore")
-- A loaded 0579 delegate is already the same catalog method as require().
-- Dirty/unknown cells must NOT trigger two identical index scans before the
-- live engine surface query; direct fallback preserves source/custody truth.
local module_name="scripts.core.efficiency_economy_0579"
local prior_loaded=package.loaded[module_name]
local duplicate_attempts=0
package.loaded[module_name]={
  entities_for_area=function()
    duplicate_attempts=duplicate_attempts+1
    return {ore}
  end,
}
_G.tech_priests_efficiency_0579_entities_for_area=function()
  indexed=indexed+1
  return nil -- existing 0579 index is dirty/unknown
end
local first_miss,first_reason=Scan.find_entities(surface,filter,{category="resource",limit=8})
assert(first_reason=="direct-scan" and first_miss[1]==ore
  and duplicate_attempts==0 and indexed==2 and scanned==2 and notes==2,
  "index miss performed a duplicate 0579 catalog search before live surface")
_G.tech_priests_efficiency_0579_entities_for_area=function()
  indexed=indexed+1
  error("catalog temporarily unavailable")
end
local failed_index,failed_reason=Scan.find_entities(surface,filter,{category="resource",limit=8})
assert(failed_reason=="direct-scan" and failed_index[1]==ore
  and duplicate_attempts==0 and indexed==3 and scanned==3 and notes==3,
  "index error was retried or blocked honest direct-surface recovery")
-- The require() fallback remains available before the global 0579 delegate
-- is installed. Do not change startup semantics while saving cache-miss cost.
_G.tech_priests_efficiency_0579_entities_for_area=nil
local boot_cache,boot_reason=Scan.find_entities(surface,filter,{category="resource",limit=8})
assert(boot_reason=="indexed-0579" and boot_cache[1]==ore
  and duplicate_attempts==1 and scanned==3 and notes==3,
  "pre-install catalog fallback was removed by cache miss optimization")
assert(physical_direct_metric==3,
  "catalog and router double-counted one of three actual surface queries")
-- With indexing disabled, 0610 must count each direct surface read itself.
_G.tech_priests_efficiency_0579_note_area_scan=function(_,_,found)
  notes=notes+1
  assert(found[1]==ore)
  return false
end
local without_catalog,without_source=Scan.find_entities(surface,filter,
  {category="resource",limit=8,require_fresh=true})
assert(without_source=="direct-scan" and without_catalog[1]==ore
  and physical_direct_metric==4 and scanned==4 and notes==4,
  "disabled catalog suppressed or double-counted an actual surface scan")
package.loaded[module_name]=prior_loaded
_G.tech_priests_efficiency_0579_entities_for_area=old_index
_G.tech_priests_efficiency_0579_note_area_scan=old_note
_G.tech_priests_runtime_metric_0606=old_metric
print("[scan-routing-fresh-0841] PASS honest live scans, single catalog attempt and exactly-once scan metrics")
