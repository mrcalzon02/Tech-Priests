-- 1241: real, already-installed normal assemblers and laboratories must
-- fulfill their infrastructure roles without triggering emergency substitutes.
-- Audit-only service computes the actual 0640 next step without issuing work.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=9000}
storage={tech_priests={pairs_by_station={},
  infrastructure_first_governor_0640={enabled=true,audit_only=true,
    stats={},recent={}}}}
defines={inventory={chest=1}}
local force={index=1,valid=true,recipes={
  ["automation-science-pack"]={enabled=true},
  ["electronic-circuit"]={enabled=true},
}}
local enemy={index=2,valid=true}
local surface={index=1}
local other_surface={index=2}
local station={valid=true,unit_number=41,
  name="planetary-magos-cogitator-station",
  position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,unit_number=42,
  position={x=0,y=1},force=force,surface=surface}
local pair={station=station,priest=priest,radius=30,mode="idle"}
storage.tech_priests.pairs_by_station[41]=pair
local inventory={valid=true,get_item_count=function()return 0 end}
station.get_inventory=function(id)
  return id==1 and inventory or nil
end
local function entity(name,kind,x,f,s)
  return {valid=true,name=name,type=kind,
    position={x=x,y=0},force=f or force,surface=s or surface}
end
local miner=entity("electric-mining-drill","mining-drill",8)
local furnace=entity("stone-furnace","furnace",6)
local assembler=entity("assembling-machine-1","assembling-machine",11)
local lab=entity("lab","lab",14)
local enemy_assembler=entity("assembling-machine-2",
  "assembling-machine",12,enemy)
local far_lab=entity("lab","lab",120)
local ghost=entity("entity-ghost","entity-ghost",15)
local installed={miner,furnace,assembler,lab}
surface.find_entities_filtered=function(q)
  if q.type=="resource" then return {} end
  if type(q.type)=="table" then return installed end
  return {}
end
_G.TechPriestsStorageRoleAuthority0686={
  generic_item_count=function()return 0 end,
}
prototypes={item={
  ["automation-science-pack"]={name="automation-science-pack"},
  ["electronic-circuit"]={name="electronic-circuit"},
  ["tech-priests-emergency-assembler"]={
    name="tech-priests-emergency-assembler"},
  ["tech-priests-emergency-miner"]={
    name="tech-priests-emergency-miner"},
}}
local Governor=require("scripts.core.infrastructure_first_governor_0640")
local r=storage.tech_priests.infrastructure_first_governor_0640
local function next_need(label,expected)
  local before=#r.recent
  local ok,reason=Governor.service_pair(pair,label)
  assert(not ok and reason=="audit-only",
    label..": unexpected non-audit construction execution")
  assert(#r.recent==before+1,
    label..": missing per-pair read-only infrastructure decision")
  local detail=r.recent[#r.recent].detail
  assert(detail:find("needed="..expected.." ",1,true),
    label..": expected "..expected..", observed "..detail)
  assert(pair.emergency_craft==nil and pair.construction_task_0338==nil
    and pair.direct_acquisition_custody_0513==nil,
    label..": audit granted physical work or created material custody")
end
next_need("installed-standard-factory-produces-first-science",
  "automation-science-pack")
-- No lab: the existing standard assembler should plan first electronics,
-- not another emergency assembler, even when no 0640 special-facility
-- ownership record exists.
installed={miner,furnace,assembler}
next_need("standard-assembler-without-lab","electronic-circuit")
-- No assembler: physical furnace/drill/lab alone do not satisfy the
-- workshop role; retain a real infrastructure construction objective.
installed={miner,furnace,lab}
next_need("missing-workshop-not-satisfied-by-lab",
  "tech-priests-emergency-assembler")
-- Only foreign/distant/ghost machinery must not satisfy missing local roles.
installed={miner,furnace,enemy_assembler,far_lab,ghost}
next_need("foreign-distant-or-ghost-machine-not-installed",
  "tech-priests-emergency-assembler")
-- Restore actual standard machines; they should again be recognized.
installed={miner,furnace,assembler,lab}
next_need("real-local-machines-regain-authority",
  "automation-science-pack")
print("[installed-standard-factory-roles-1241] PASS standard assembler/lab recognition, missing equipment, foreign/distant/ghost refusal and no synthetic custody")
