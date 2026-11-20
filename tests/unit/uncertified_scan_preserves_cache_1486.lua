-- Regression 1486 (Claude T2-04): filtered/uncapped observations never
-- invalidate a known-complete 0579 cell or certify an unknown one.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}}
game={tick=10}
local I=require("scripts.core.efficiency_economy_0579")
local surface={index=13,name="nauvis"}
local full={{0,0},{32,32}}
local partial={{0,0},{16,32}}
local function ent(id,x)
 return {valid=true,unit_number=id,name="assembling-machine-1",
   type="assembling-machine",surface=surface,
   position={x=x,y=5}}
end
local first,second=ent(1,5),ent(2,20)
assert(I.note_area_scan(surface,full,{first,second},768,true))
local known=I.entities_for_area(surface,full,768,true)
assert(known and #known==2,"authoritative scan failed to seed index")
local root=I.root()
local cell=root.surfaces["13"].cells["0:0"]
local certified_at=cell.known_tick
-- Work-queue filtered scans pass no limit: old code poisoned this cell.
game.tick=11
assert(I.note_area_scan(surface,full,{first})==true)
local reused=I.entities_for_area(surface,full,768,true)
assert(reused and #reused==2 and cell.known_tick==certified_at,
 "filtered observation discarded a complete snapshot")
assert(root.surfaces["13"].dirty["0:0"]==nil,
 "observation inserted an invalid dirty marker")
-- An explicitly bounded but incomplete scan likewise cannot poison it.
game.tick=12
assert(I.note_area_scan(surface,full,{second},1,false))
assert(#I.entities_for_area(surface,full,768,true)==2,
 "capped scan dirtied a previously complete cell")
assert(I.note_area_scan(surface,partial,{first},nil,false))
assert(#I.entities_for_area(surface,full,768,true)==2,
 "partial filtered observation damaged full-cell knowledge")
-- An uncapped observation alone must not manufacture completeness.
local other={index=14,name="another"}
local lone={valid=true,unit_number=3,name="furnace",type="furnace",
 surface=other,position={x=4,y=4}}
assert(I.note_area_scan(other,full,{lone},nil)==true)
assert(I.entities_for_area(other,full,768,true)==nil,
 "non-authoritative observation certified an unknown cell")
-- A real world event still invalidates immediately.
I.mark_entity_dirty(second,"removed")
assert(I.entities_for_area(surface,full,768,true)==nil,
 "actual world mutation did not wake the catalog")
game.tick=15
assert(I.note_area_scan(surface,full,{first},768,true))
local latest=I.entities_for_area(surface,full,768,true)
assert(latest and #latest==1 and latest[1]==first,
 "complete rescan did not remove absent machine from index")
assert((root.stats.uncertified_observations_preserved or 0)>=4,
 "uncertified preservation counter missing")
print("[uncertified-scan-preserves-cache-1486] PASS")
