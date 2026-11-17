-- Apply the same production balance to the integrated machines and the older
-- add-on prototypes when an existing save still loads them.
local power = {
  ["tp-mh7-review-purifier"] = "50kW",
  ["tp-mh7-review-electrolyzer"] = "200kW",
  ["tp-mh7-review-compressor"] = "375kW",
  ["tp-mh7-review-crucible"] = "2.5MW",
  ["tp-mh7-review-forge"] = "200kW",
  ["tp-mh7-review-fabricator"] = "150kW",
  ["tp-mh7-canister-assembler"] = "125kW",
}
local machines = data.raw["assembling-machine"]
for name, draw in pairs(power) do machines[name].energy_usage = draw end

-- Keep the fluid ID used by existing pipes, tanks, barrels and blueprints.
local gas = "tp-mh7-review-hydrogen-gas"
local liquid = "tp-mh7-review-compressed-hydrogen"
local gas_per_cycle = 500

local liquefy = data.raw.recipe["tp-mh7-review-compress"]
liquefy.ingredients = {{type = "fluid", name = gas, amount = gas_per_cycle}}
liquefy.results = {{type = "fluid", name = liquid, amount = 10}}
liquefy.main_product = liquid
liquefy.localised_name = {"recipe-name." .. liquefy.name}

local crucible = data.raw.recipe["tp-mh7-review-metallize"]
crucible.ingredients = {{type = "fluid", name = liquid, amount = 20}}

local compressor = machines["tp-mh7-review-compressor"]
for _, box in ipairs(compressor.fluid_boxes) do
  if box.filter == gas then box.volume = 2 * gas_per_cycle end
end

data.raw.fluid[liquid].localised_name = {"fluid-name." .. liquid}
local technology = data.raw.technology["tp-metallicized-hydrogen-production"]
technology.localised_description = {"technology-description." .. technology.name}
