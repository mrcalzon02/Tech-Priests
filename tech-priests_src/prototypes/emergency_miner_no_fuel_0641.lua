-- prototypes/emergency_miner_no_fuel_0641.lua
-- Tech Priests 0.1.641
--
-- The emergency micro-miner is a bootstrap pseudo-miner. It should not create a
-- second fuel logistics dependency before the station has even established local
-- smelting and plate fabrication. Its cost is time, not fuel.

local miner = data.raw["assembling-machine"] and data.raw["assembling-machine"]["tech-priests-emergency-miner"]
if miner then
  miner.energy_source = { type = "void" }
  miner.energy_usage = "1W"
  miner.emissions_per_minute = nil
  miner.crafting_speed = 1
  miner.module_slots = 0
  miner.allowed_effects = {}
  miner.burner = nil
end

local very_slow_mining_times_0641 = {
  ["tech-priests-emergency-mine-wood"] = 300,
  ["tech-priests-emergency-mine-stone"] = 300,
  ["tech-priests-emergency-mine-iron-ore"] = 480,
  ["tech-priests-emergency-mine-copper-ore"] = 480,
  ["tech-priests-emergency-mine-coal"] = 480,
  ["tech-priests-emergency-mine-uranium-ore"] = 1200,
}

for name, recipe in pairs(data.raw.recipe or {}) do
  if type(name) == "string" and string.sub(name, 1, #"tech-priests-emergency-mine-") == "tech-priests-emergency-mine-" then
    local target_time = very_slow_mining_times_0641[name] or 900
    if (tonumber(recipe.energy_required) or 0) < target_time then
      recipe.energy_required = target_time
    end
    recipe.allow_productivity = false
    recipe.allow_decomposition = false
  end
end
