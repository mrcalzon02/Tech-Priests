-- Lua 5.2 regression: the distant-action visual contract must not compete
-- with physical acquisition, machine cargo or other accepted movement routes.
package.path = "tech-priests_src/?.lua;tech-priests_src/?/init.lua;" .. package.path
game = { tick = 1000 }
storage = { tech_priests = { pairs_by_station = {} } }
defines = { command = { stop = 1, go_to_location = 2 },
  distraction = { none = 0, by_enemy = 1 } }
_G.TechPriestsPairBucketRegistry0600 = { force_bucket = function() end }
local Movement = require("scripts.core.movement_controller")
local Behavior = require("scripts.core.behavior_contracts_0479")
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418 = Movement
_G.tech_priests_request_movement_0418 = function(pair, pos, reason, opts)
  return Movement.request(pair, pos, reason, opts)
end
local function check(ok, message)
  if not ok then error("behavior-contract-movement-handoff: " .. message, 2) end
end
local force = { index = 1, name = "player" }
local surface = { index = 1 }
local station = { valid = true, name = "junior-cogitator-station",
  unit_number = 7, force = force, surface = surface, position = {x = 0,y = 0} }
local priest = { valid = true, unit_number = 8, name = "tech-priest",
  position = {x = 0,y = 0}, force = force, surface = surface,
  commandable = {valid = true, set_command = function() end} }
local resource = { valid = true, unit_number = 9, name = "iron-ore",
  type = "resource", position = {x = 10,y = 0}, force = {name="neutral"},
  surface = surface }
local pair = {station=station,priest=priest,station_unit=7,mode="acquisition",
  target=resource,radius=30}
storage.tech_priests.pairs_by_station[7]=pair
local function stats() return storage.tech_priests.movement_controller_0419.stats end
local function behavior_stats() return storage.tech_priests.behavior_contracts_0479.stats end
local ok = Movement.request(pair,{x = 7,y = 1},"machine-logistics-return-custody-0528",
  {owner = "logistics_machine_fulfillment_0528",priority=740,ttl=600})
check(ok == true, "machine output route was rejected")
local cargo_route=pair.movement_request_0418
check(Behavior.service_pair(pair)==true,"remote visual suppression was not applied")
check(pair.movement_request_0418==cargo_route,
  "observer overrode live machine logistics movement")
check((stats().lower_priority_retargets_denied or 0)==0,
  "observer submitted a competing priority-700 movement command")
check((behavior_stats().movement_delegated_to_owner or 0)==1,
  "observer delegation to an existing owner was not recorded")

Movement.stop(pair,"test-direct")
_G.TechPriestsDirectAcquisitionExecutor0513 = {
  current_direct_task=function()
    return {kind="direct-mine-0336"},{kind="direct-mine-0336"}
  end
}
check(Behavior.service_pair(pair)==true,"physical acquisition was not visually guarded")
check(pair.movement_request_0418==nil,
  "observer stole movement while physical executor awaited its dispatch")
check((behavior_stats().movement_delegated_to_direct_executor or 0)==1,
  "idle interval of physical executor was not delegated")
_G.TechPriestsDirectAcquisitionExecutor0513=nil

check(Behavior.service_pair(pair)==true,"legacy acquisition failed to issue fallback")
local fallback=pair.movement_request_0418
check(fallback and fallback.owner=="behavior-contract-0479" and fallback.priority==500,
  "legacy fallback can outrank direct extraction or failed to register")
check(fallback.expires_tick==game.tick+Behavior.move_ttl_ticks,
  "observer fallback retained an excessive movement lease")
local count=behavior_stats().fallback_move_requests
for _=1,40 do check(Behavior.service_pair(pair)==true,"duplicate guarded service failed") end
check(pair.movement_request_0418==fallback,
  "redundant visual observer calls replaced an accepted request")
check((behavior_stats().fallback_move_requests or 0)==count,
  "observer reissued dozens of identical movement requests")
check((behavior_stats().duplicate_movement_skipped or 0)>=40,
  "observer did not deduplicate repeated target intent")

local accepted=Movement.request(pair,{x=11,y=1},"direct-acquisition-travel-0513",
  {owner="direct-acquisition-0513",priority=650,ttl=600})
check(accepted==true and pair.movement_request_0418.owner=="direct-acquisition-0513",
  "legacy fallback lease blocked the actual physical acquisition")
check((stats().lower_priority_retargets_denied or 0)==0,
  "legitimate direct path was priority-denied by observer")

local real_direct=pair.movement_request_0418
check(Behavior.service_pair(pair)==true and pair.movement_request_0418==real_direct,
  "observer re-contested a physical acquisition route")

pair.direct_acquisition_custody_0513={item="iron-ore",count=3}
check(Behavior.service_pair(pair)==false,
  "cargo return was not exempted from stale remote acquisition visual")
check(pair.movement_request_0418==real_direct and
  pair.direct_acquisition_custody_0513.count==3,
  "observer altered a physical cargo return")
pair.direct_acquisition_custody_0513=nil

-- Make one genuine competing request to prove the arbitration metric still
-- counts conflicts; the cleanup must not merely silence this counter.
local blocked,why=Movement.request(pair,{x=12,y=5},"unrelated-intent",
  {owner="other-writer",priority=400,ttl=600})
check(blocked==false and why=="higher-priority-movement-owned",
  "genuine priority conflict was unexpectedly accepted")
local root=storage.tech_priests.movement_controller_0419
check((root.priority_denials_by_requester[
  "other-writer -> direct-acquisition-0513"] or 0)==1,
  "denial telemetry hid which family submitted the conflict")

-- An equal-priority retarget with an unrelated destination is deferred, not
-- falsely marked as accepted. No cargo or command may be overwritten.
Movement.stop(pair,"test-retarget")
game.tick=2000
check(Movement.request(pair,{x=8,y=1},"plain-a",
  {owner="plain-a",priority=550,ttl=600})==true,"plain route not accepted")
local prior=pair.movement_request_0418
local retarget,detail=Movement.request(pair,{x=9,y=8},"plain-b",
  {owner="plain-b",priority=550,ttl=600})
check(retarget==false and detail=="retarget-held",
  "fresh same-priority retarget was falsely reported as accepted")
check(pair.movement_request_0418==prior,
  "held retarget stole the incumbent route")
print("[behavior-contract-movement-handoff] PASS scenarios=8")
