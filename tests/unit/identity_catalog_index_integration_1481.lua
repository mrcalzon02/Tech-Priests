-- Regression 1481: precise shared identity must avoid merging unitless resources.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
game={tick=0}
storage={tech_priests={pairs_by_station={}}}
local Id=require("scripts.core.entity_identity_1481")
local C=require("scripts.core.station_catalog")
local I=require("scripts.core.efficiency_economy_0579")
local surf={index=7,name="nauvis"}
local force={index=1,name="player"}
local function rock(x,unit)
 return {valid=true,type="simple-entity",name="rock-huge",
   surface=surf,force=force,unit_number=unit,position={x=x,y=11.02}}
end
local a,b=rock(10.011),rock(10.019)
local ka,kb=Id.key(a),Id.key(b)
assert(ka~=kb and C.entity_key(a)==ka and C.entity_key(b)==kb,
  "catalog and canonical keys disagree or distinct rocks were merged")
assert(I.index_entity(a,"regression") and I.index_entity(b,"regression"))
assert(I.note_area_scan(surf,{{0,0},{32,32}},{a,b},768,true))
local rec=I.entities_for_area(surf,{{0,0},{32,32}},768,true)
assert(rec and #rec==2,"spatial index lost a unitless rock")
local index=I.root()
assert(index.entity_cells[ka] and index.entity_cells[kb],
  "spatial index reused coarse coordinate keys")
local pair={station={valid=true,unit_number=51,force=force,surface=surf,
  name="junior-cogitator-station",position={x=16,y=16}}}
local pair2={station={valid=true,unit_number=52,force=force,surface=surf,
  name="junior-cogitator-station",position={x=20,y=20}}}
storage.tech_priests.pairs_by_station[51]=pair
storage.tech_priests.pairs_by_station[52]=pair2
assert(C.claim_built_entity(pair,a,"mineable"))
assert(C.claim_built_entity(pair,b,"mineable"))
local root=storage.tech_priests[C.storage_key]
assert(root.owned_resources[ka]==51 and root.owned_resources[kb]==51,
  "one rock displaced the other in the ownership map")
assert(C.claim_built_entity(pair2,b,"mineable")==false,
  "another station stole an existing precise claim")
local c=rock(10.017)
local old=surf.name..":"..c.name..":"..math.floor(c.position.x*10)
  ..":"..math.floor(c.position.y*10)
root.owned_resources[old]=51
assert(C.claim_built_entity(pair2,c,"mineable")==false,
  "identity migration allowed theft of a legacy claim")
assert(C.claim_built_entity(pair,c,"mineable"),
  "original owner could not migrate to a precise key")
index.cache_schema_1476=1
index.surfaces["7"].cells["0:0"].known_tick=0
assert(I.root().cache_schema_1476==2 and next(index.surfaces)==nil,
  "migration retained ambiguous derived index cells")
assert(root.owned_resources[ka]==51 and root.owned_resources[kb]==51,
  "cache migration destroyed physical ownership")
print("[identity-catalog-index-integration-1481] PASS")
