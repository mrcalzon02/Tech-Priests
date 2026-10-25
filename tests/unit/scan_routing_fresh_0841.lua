-- The indexed 0579 spatial catalog can be stale after generation of a
-- remote natural ore chunk. Courier inventory safety requires a bounded
-- fresh read from the *existing* canonical scan authority.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Scan=require("scripts.core.scan_routing_0610")
local old_index=rawget(_G,"tech_priests_efficiency_0579_entities_for_area")
local old_note=rawget(_G,"tech_priests_efficiency_0579_note_area_scan")
local indexed,scanned,notes=0,0,0
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
_G.tech_priests_efficiency_0579_entities_for_area=old_index
_G.tech_priests_efficiency_0579_note_area_scan=old_note
print("[scan-routing-fresh-0841] PASS bounded physical ore scan bypassed stale cache")
