-- Source regression: native Quality affects the scripted twin-cannon
-- piercing-line target search, while Factorio alone owns attack parameters.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local controller=require("scripts.twin_cannon_controller")
prototypes={entity={["tech-priests-bunker-twin-cannon"]={attack_parameters={range=36}}}}
local values={normal=36,uncommon=39.6,rare=43.2,epic=46.8,legendary=54}
local mult={normal=1,uncommon=1.1,rare=1.2,epic=1.3,legendary=1.5}
for grade,expected in pairs(values) do
  local got=controller.effective_attack_range({valid=true,quality={name=grade,range_multiplier=mult[grade]}})
  assert(math.abs(got-expected)<0.00001,grade.." effective radius got "..tostring(got))
end
assert(controller.effective_attack_range({valid=true,quality={name="overcap",range_multiplier=4}})==108)
assert(controller.effective_attack_range({valid=false,quality={range_multiplier=1.5}})==0)
assert(controller.effective_attack_range({valid=true,quality=nil})==36)
local name="tech-priests-bunker-twin-cannon"
prototypes.entity[name].attack_parameters.range=40
assert(controller.effective_attack_range({valid=true,quality={range_multiplier=1.5}})==60,
  "Mod-adjusted prototype range ignored")
print("[quality-turret-range] PASS native tiers, custom quality cap, invalid and adjusted prototype")
