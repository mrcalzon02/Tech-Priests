-- Plain Lua 5.2: quality influences *initial* sanctity without resetting wear.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path

local Q = require("scripts.core.consecration.quality_baseline")
local function same(a,b,label)
  assert(math.abs(a-b)<0.000001, (label or "value").." expected "..tostring(b).." got "..tostring(a))
end
local tiers={normal=50,uncommon=60,rare=70,epic=85,legendary=100}
for name, value in pairs(tiers) do same(Q.starting_sanctification(50,100,name),value,name) end
local researched={normal=90,uncommon=96,rare=102,epic=111,legendary=120}
for name, value in pairs(researched) do same(Q.starting_sanctification(90,120,name),value,"researched-"..name) end
same(Q.starting_sanctification(130,120,"legendary"),120,"clamped-start")
same(Q.starting_sanctification(50,100,"unknown-quality"),50,"unrecognized-quality")
assert(Q.entity_quality_name({valid=true, quality={name="legendary"}})=="legendary")
assert(Q.entity_quality_name({valid=true})=="normal")

-- Exercise the actual record-registry lifecycle with the existing normalization.
get_base_sanctification_start=function(force) return force.start end
get_base_sanctification_max=function(force) return force.maximum end
get_min_degraded_sanctification_max=function() return 25 end
get_minimum_sanctification_value_fraction=function() return 0.05 end
ensure_storage=function()
  storage.tech_priests=storage.tech_priests or {}
  storage.tech_priests.consecration=storage.tech_priests.consecration or {machines={},renders={}}
end
storage={tech_priests={consecration={machines={},renders={}}}}
game={tick=100}
require("scripts.core.consecration.detritus")
require("scripts.core.consecration.registry")
local force={start=50,maximum=100}
local function create(n,name)
  return {valid=true,unit_number=n,name="assembling-machine-2",type="assembling-machine",
    force=force,quality=name and {name=name} or nil}
end
for i, name in ipairs({"normal","uncommon","rare","epic","legendary"}) do
  local entity=create(i,name)
  local rec=get_consecration_record(entity)
  same(rec.sanctification,tiers[name],"registered-"..name)
  same(rec.max_sanctification,100,"preserve-cap-"..name)
  assert(rec.quality_at_initial_consecration==name,"registered quality not recorded")
end
local leg=create(5,"legendary")
local existing=get_consecration_record(leg)
existing.sanctification=31
same(get_consecration_record(leg).sanctification,31,"no-heal-on-reregistration")
local older=create(99,"legendary")
storage.tech_priests.consecration.machines[99]={entity=older,unit_number=99,
  sanctification=22,max_sanctification=100}
same(get_consecration_record(older).sanctification,22,"no-heal-existing-save")
local vanilla=create(100,nil)
same(get_consecration_record(vanilla).sanctification,50,"no-quality-mod")
print("[machine-spirit-quality-baseline] PASS quality starts, research, caps, persistence")
