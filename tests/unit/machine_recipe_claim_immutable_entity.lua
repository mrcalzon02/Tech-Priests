-- Lua 5.2: engine-owned LuaEntity rejects invented fields. Reservation
-- ownership is retained in the canonical persistent claim ledger instead.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
storage={tech_priests={}}
local reservations=require("scripts.core.efficiency_economy_0576")
local force={index=1}
local surface={index=1}
local machine=setmetatable({
  valid=true,unit_number=77,name="tech-priests-emergency-miner",
  position={x=4,y=3},surface=surface,force=force
},{__newindex=function(_,name)
  error("illegal engine LuaEntity mutation: "..tostring(name))
end})
local stationA={valid=true,unit_number=11}
local stationB={valid=true,unit_number=21}
local priestA={valid=true,unit_number=12}
local priestB={valid=true,unit_number=22}
local pairA={station=stationA,priest=priestA,station_unit=11,priest_unit=12}
local pairB={station=stationB,priest=priestB,station_unit=21,priest_unit=22}
local granted,why=reservations.claim_machine_for_recipe(
  pairA,machine,"tech-priests-emergency-mine-iron-ore","continuity")
assert(granted==true,"claim of immutable live machine failed: "..tostring(why))
local ledger=reservations.root().machine_claims
local claim=ledger["1:77"]
assert(claim and claim.owner=="11:12" and claim.recipe=="tech-priests-emergency-mine-iron-ore",
  "machine claim not persisted in storage")
local granted_other=reservations.claim_machine_for_recipe(pairB,machine,
  "tech-priests-emergency-mine-coal","another-station")
assert(granted_other==false,"another station stole a live machine claim")
game.tick=1000+reservations.claim_ttl_ticks+1
local later=reservations.claim_machine_for_recipe(pairB,machine,
  "tech-priests-emergency-mine-coal","expired-lease-recovery")
assert(later==true and ledger["1:77"].owner=="21:22",
  "expired claim could not be safely recovered")
assert(reservations.release_machine_claim(pairB,machine,"complete")==true,
  "claim owner could not release ledger entry")
assert(ledger["1:77"]==nil,"released machine claim remained live")
print("[machine-recipe-claim-regression] PASS immutable_entity ownership expiry release")
