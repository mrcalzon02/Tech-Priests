-- Regression 1480: fully indexed dense regions may bypass the single-query cap.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}}
game={tick=0}
local I=require("scripts.core.efficiency_economy_0579")
local surface={index=1,name="nauvis"}
local area={{0,0},{64,64}}
local entities={}
for i=1,1100 do
  entities[i]={valid=true,type="assembling-machine",name="assembling-machine-1",
    unit_number=i,position={x=((i-1)%50)+0.2,
      y=math.floor((i-1)/50)+0.2},surface=surface}
end
assert(I.note_area_scan(surface,area,entities,768,true),
  "complete multi-query index note rejected")
assert(I.entities_for_area(surface,area,768)==nil,
  "legacy cap unexpectedly allowed expanded records")
local expanded=I.entities_for_area(surface,area,768,true)
assert(type(expanded)=="table" and #expanded==1100,
  "explicit expanded cache failed to reuse the complete 1100-entity scan")
local seen,last={},nil
for _,entity in ipairs(expanded) do
  local key="u:"..entity.unit_number
  assert(not seen[key],"duplicate cached entity")
  if last then assert(last<key,"expanded cache returned nondeterministic order") end
  seen[key]=true
  last=key
end
local root=I.root()
assert(root.stats.expanded_area_cache_hits_1480==1,
  "expanded cache hit telemetry missing")
I.mark_entity_dirty(entities[1],"built")
assert(I.entities_for_area(surface,area,768,true)==nil,
  "dirty cell falsely returned complete expanded cache")
game.tick=10
local many={}
for i=1,2100 do
  many[i]={valid=true,type="assembling-machine",name="assembling-machine-1",
    unit_number=2000+i,position={x=(i%60)+0.1,
      y=math.floor(i/60)+0.1},surface=surface}
end
assert(I.note_area_scan(surface,area,many,768,true))
assert(I.entities_for_area(surface,area,768,true)==nil,
  "entity index cap was bypassed by expanded mode")
print("[catalog-expanded-cache-1480] PASS")
