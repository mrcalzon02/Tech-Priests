-- Source-level eligibility check; no Factorio runtime or CI scheduler changes.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local function deepcopy(value)
  if type(value)~="table" then return value end
  local copy={}
  for key,item in pairs(value) do copy[deepcopy(key)]=deepcopy(item) end
  return copy
end
table.deepcopy=table.deepcopy or deepcopy
defines={direction={north=0}}
pipecoverspictures=function() return {} end
package.preload["__base__.prototypes.entity.assembler-pictures"]=function()
  return {assembler2pipepictures={}}
end
local Factories=require("prototypes.faction_factories")
local function has(values,needle)
  for _,value in ipairs(values or {}) do if value==needle then return true end end
  return false
end
local function exercise(quality_enabled,upstream_restricted)
  feature_flags={quality=quality_enabled}
  local output={}
  local prototype={
    name="assembling-machine-2",
    type="assembling-machine",
    module_slots=2,
    allowed_effects={"speed","consumption","productivity"}
  }
  if upstream_restricted then prototype.allowed_module_categories={"speed"} end
  data={
    raw={["assembling-machine"]={["assembling-machine-2"]=prototype}},
    extend=function(_,entries)
      for _,entry in ipairs(entries) do
        local key=entry.type..":"..entry.name
        assert(not output[key],"duplicate prototype "..key)
        output[key]=entry
      end
    end
  }
  Factories.register()
  assert(prototype.module_slots==2,"upstream assembler mutated")
  for _,def in ipairs(Factories.definitions) do
    local machine=assert(output["assembling-machine:"..def.name],"missing "..def.name)
    assert(machine.module_slots==4,"four doctrine slots missing "..def.name)
    assert(machine.quality_affects_module_slots==false,"quality must not expand four fixed slots")
    for _,effect in ipairs({"speed","consumption","pollution"}) do
      assert(has(machine.allowed_effects,effect),"doctrine native effect refused "..effect)
    end
    assert(not has(machine.allowed_effects,"productivity"),
      "combat-unit recruitment must not silently enable native productivity")
    assert(has(machine.allowed_effects,"quality")==quality_enabled,
      "optional Quality effect gating incorrect")
    if upstream_restricted then
      assert(has(machine.allowed_module_categories,"speed"),"inherited category discarded")
      assert(has(machine.allowed_module_categories,"tech-priests-machine-spirit-order"),
        "Order module category rejected")
      assert(has(machine.allowed_module_categories,"tech-priests-machine-spirit-chaos"),
        "Chaos module category rejected")
      assert(#machine.allowed_module_categories==3,"extra category leaked")
    else
      assert(machine.allowed_module_categories==nil,"unrestricted categories must stay unrestricted")
    end
    local recipe=assert(output["recipe:"..def.name],"recruitment recipe lost")
    assert(recipe.results[1].name==def.name,"recruitment output identity mutated")
    assert(machine.crafting_categories[1]==def.category,"recipe category changed")
  end
end
exercise(false,true)
exercise(true,true)
exercise(false,false)
exercise(true,false)
print("[faction-factory-doctrine-slots] PASS 3x4 native slots, researched category admission, Quality gate, recipe preservation")
