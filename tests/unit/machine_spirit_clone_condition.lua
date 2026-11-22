-- Physical clone custody: no healing, quality reset, or duplicated identity.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Clone=require("scripts.core.consecration.clone_condition")
local force={index=1}
local function entity(unit,quality,name,group)
  return {valid=true,unit_number=unit,force=group or force,name=name or "assembling-machine-3",
    type="assembling-machine",quality={name=quality or "normal"}}
end
local original=entity(100,"normal")
local fresh=entity(101,"legendary")
local from={unit_number=100,entity=original,sanctification=18,max_sanctification=32,
  machine_id_0446=8,completed_operations_seen_0417=79,
  machine_spirit_module_snapshot={order=20},machine_spirit_module_resample_tick=1000}
local into={unit_number=101,entity=fresh,sanctification=100,max_sanctification=100,
  machine_id_0446=9,quality_at_initial_consecration="legendary"}
local ok,why=Clone.transfer(from,into,original,fresh)
assert(ok and why==nil,"valid physical clone rejected")
assert(into.sanctification==18 and into.max_sanctification==32,"clone healed real wear")
assert(into.legacy_50_cap_migrated==true,"scarred cap vulnerable to obsolete migration")
assert(into.machine_id_0446==9 and into.quality_at_initial_consecration=="legendary",
  "new identity or destination quality overwritten")
assert(into.machine_spirit_module_snapshot==nil and into.completed_operations_seen_0417==nil,
  "source module cache or operation history was duplicated")
assert(from.sanctification==18 and from.max_sanctification==32 and from.machine_id_0446==8,
  "physical clone changed original machine")
local high={unit_number=100,sanctification=130,max_sanctification=140}
local constrained={unit_number=101,max_sanctification=120,sanctification=90}
assert(Clone.transfer(high,constrained,original,fresh),"capped clone rejected")
assert(constrained.sanctification==120 and constrained.max_sanctification==120,
  "clone exceeded destination's researched cap")
local function refused(source, dest, src, dst)
  local before=dest.sanctification
  local ok2=Clone.transfer(source,dest,src,dst)
  assert(ok2==false and dest.sanctification==before,"invalid clone accepted or mutated destination")
end
refused(from,{unit_number=101,max_sanctification=100,sanctification=50},original,entity(101,"normal","electric-furnace"))
refused(from,{unit_number=101,max_sanctification=100,sanctification=50},original,entity(101,"normal",nil,{index=2}))
refused(from,{unit_number=100,max_sanctification=100,sanctification=50},original,original)
refused({unit_number=100,sanctification=0/0,max_sanctification=100},
  {unit_number=101,max_sanctification=100,sanctification=50},original,fresh)
refused({unit_number=100,sanctification=60,max_sanctification=-5},
  {unit_number=101,max_sanctification=100,sanctification=50},original,fresh)
refused(from,{unit_number=102,max_sanctification=100,sanctification=50},original,fresh)
print("[machine-spirit-clone-condition] PASS distinct ID, persisted scars, force/name validation, quality, invalid state")
